import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class StudyGroupManager: ObservableObject {
    @Published var myGroups: [StudyGroup] = []
    private var db = Firestore.firestore()
    
    // 리스너 관리를 위한 변수
    private var listener: ListenerRegistration?
    
    // 나의 스터디 그룹 실시간 리스너
    func fetchMyGroups(uid: String) {
        // 기존 리스너 제거 (중복 방지)
        listener?.remove()
        
        listener = db.collection("study_groups")
            .whereField("members", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching groups: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                self.myGroups = documents.compactMap { StudyGroup(document: $0) }
            }
    }
    
    // 리스너 해제 (로그아웃 시 등)
    func stopListening() {
        listener?.remove()
        listener = nil
        myGroups = []
    }
    
    func createGroup(name: String, description: String, leaderID: String, completion: @escaping (Bool) -> Void) {
        // 미리 문서 레퍼런스를 생성하여 ID를 확보
        let ref = db.collection("study_groups").document()
        let newGroup = StudyGroup(id: ref.documentID, name: name, description: description, leaderID: leaderID, members: [leaderID])
        
        // Optimistic UI: 먼저 로컬 목록에 추가하여 즉시 반응
        self.myGroups.insert(newGroup, at: 0)
        
        ref.setData(newGroup.toDictionary()) { error in
            if let error = error {
                print("Error creating group: \(error)")
                // 실패 시 롤백
                if let index = self.myGroups.firstIndex(where: { $0.id == newGroup.id }) {
                    self.myGroups.remove(at: index)
                }
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func addMember(groupID: String, newMemberUID: String, completion: @escaping (Bool, String?) -> Void) {
        let groupRef = db.collection("study_groups").document(groupID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let groupDoc: DocumentSnapshot
            do {
                try groupDoc = transaction.getDocument(groupRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            guard let data = groupDoc.data(),
                  let maxMembers = data["maxMembers"] as? Int,
                  let members = data["members"] as? [String] else {
                return nil
            }
            
            if members.count >= maxMembers {
                let error = NSError(domain: "StudyGroupError", code: 400, userInfo: [NSLocalizedDescriptionKey: "스터디 정원이 초과되었습니다."])
                errorPointer?.pointee = error
                return nil
            }
            
            if members.contains(newMemberUID) {
                let error = NSError(domain: "StudyGroupError", code: 401, userInfo: [NSLocalizedDescriptionKey: "이미 가입된 멤버입니다."])
                errorPointer?.pointee = error
                return nil
            }
            
            // ✨ [Modified] 멤버 추가 시 updatedAt 갱신
            transaction.updateData([
                "members": FieldValue.arrayUnion([newMemberUID]),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: groupRef)
            return nil
            
        }) { (object, error) in
            if let error = error as NSError? {
                print("멤버 추가 실패: \(error)")
                completion(false, error.userInfo[NSLocalizedDescriptionKey] as? String ?? "오류가 발생했습니다.")
            } else {
                completion(true, nil)
            }
        }
    }
    
    func leaveGroup(groupID: String, uid: String, completion: @escaping (Bool) -> Void) {
        // ✨ [Modified] 나가기도 업데이트로 간주 (남은 멤버들에게 알림?)
        // 로직상 남은 멤버들에게 빨간점이 필요하다면 여기서도 updatedAt 갱신 필요.
        db.collection("study_groups").document(groupID).updateData([
            "members": FieldValue.arrayRemove([uid]),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            completion(error == nil)
        }
    }
    
    // ✨ [New] 방장 위임
    func delegateLeader(groupID: String, newLeaderUID: String, completion: @escaping (Bool) -> Void) {
        db.collection("study_groups").document(groupID).updateData([
            "leaderID": newLeaderUID,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error delegating leader: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // ✨ [New] 스터디 그룹 삭제 (방장 권한)
    func deleteGroup(groupID: String, completion: @escaping (Bool) -> Void) {
        // ✨ [Optimistic UI] 즉시 로컬 목록에서 제거
        if let index = self.myGroups.firstIndex(where: { $0.id == groupID }) {
            self.myGroups.remove(at: index)
        }
        
        db.collection("study_groups").document(groupID).delete { error in
            if let error = error {
                print("Error deleting group: \(error)")
                // 실패 시 복구 (Optional: 실패했다는 알림을 띄우고 다시 fetch하거나 놔둘 수 있음)
                // 여기선 다시 fetch 하는게 안전함
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // ✨ [New] 공지사항 추가 (일반) + 스케줄 연동
    func addNotice(groupID: String, content: String) {
        guard let user = Auth.auth().currentUser else { return }
        
        let batch = db.batch()
        let groupRef = db.collection("study_groups").document(groupID)
        
        // 1. NoticeItem 추가 (방장 직접 공지는 .announcement 타입 - 고정)
        let newNoticeItem = StudyGroup.NoticeItem(
            id: UUID().uuidString,
            type: .announcement,
            content: content,
            date: Date()
        )
        
        let noticeDict: [String: Any] = [
            "id": newNoticeItem.id,
            "type": newNoticeItem.type.rawValue,
            "content": newNoticeItem.content,
            "date": Timestamp(date: newNoticeItem.date)
        ]
        
        batch.updateData([
            "notices": FieldValue.arrayUnion([noticeDict]),
            "notice": content, // Legacy
            "noticeUpdatedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)
        
        // 2. GroupSchedule 추가 (History)
        let scheduleID = UUID().uuidString
        let scheduleRef = db.collection("study_groups").document(groupID).collection("schedules").document(scheduleID)
        
        let authorName = user.displayName ?? "운영자"
        
        let schedule = GroupSchedule(
            id: scheduleID,
            groupID: groupID,
            title: "공지사항",
            content: content,
            date: Date(),
            type: .notice, // 스케줄 타입은 .notice 유지
            authorID: user.uid,
            authorName: authorName
        )
        
        batch.setData(schedule.toDictionary(), forDocument: scheduleRef)
        
        batch.commit { error in
            if let error = error {
                print("Error adding notice & schedule: \(error)")
            }
        }
    }
    
    // ✨ [Deprecated] 기존 단순 문자열 공지 업데이트
    func updateNotice(groupID: String, notice: String) {
        addNotice(groupID: groupID, content: notice)
    }
    
    // ✨ [New] 공지사항 읽음 처리
    func updateReadStatus(groupID: String) {
        let key = "lastReadNotice_\(groupID)"
        UserDefaults.standard.set(Date(), forKey: key)
        objectWillChange.send() // UI 갱신 유도
    }
    
    // ✨ [New] 안 읽은 업데이트 확인 (공지사항, 멤버 변경 등)
    func hasUnreadUpdates(group: StudyGroup) -> Bool {
        // 1. 공지사항 체크
        let noticeKey = "lastReadNotice_\(group.id)"
        let lastReadNotice = UserDefaults.standard.object(forKey: noticeKey) as? Date ?? Date.distantPast
        
        // 최신 공지가 마지막 확인 시간보다 뒤에 있으면 true
        // notices는 내림차순 정렬되어 있으므로 first가 최신
        if let latestNotice = group.notices.first, latestNotice.date > lastReadNotice.addingTimeInterval(1) {
            return true
        }
        
        // 2. 그룹 업데이트 체크 (멤버 변경 등) - 일단 공지사항 위주로
        // 필요하다면 lastViewedGroupTime 같은걸 따로 저장해서 group.updatedAt과 비교 가능
        // 현재 요구사항은 "공지사항"이 메인이므로 공지 기준으로 처리
        return false
    }
    

    
    // ✨ [New] 시스템 알림 메시지 정리 (Legacy support)
    func cleanupSystemNotice(groupID: String, notice: String) {
        // 기존 문자열 기반 notice 필드에서 시스템 알림([알림]) 등을 제거하거나 정리하는 로직
        // 여기서는 간단히 구현 (실제로는 복잡할 수 있음)
        if notice.contains("[알림]") {
            // 필요하다면 정제 로직 추가
        }
    }
    
    // ✨ [New] 응원 읽음 처리
    func markCheersAsRead(groupID: String) {
        let key = "lastReadCheer_\(groupID)"
        UserDefaults.standard.set(Date(), forKey: key)
        objectWillChange.send()
    }
    
    // ✨ [New] hasUnreadNotice Alias for compatibility
    func hasUnreadNotice(group: StudyGroup) -> Bool {
        return hasUnreadUpdates(group: group)
    }
    
    // ✨ [New] markAsRead Alias for compatibility
    func markAsRead(groupID: String) {
        updateReadStatus(groupID: groupID)
    }

    // ✨ [New] 멤버 정보 관리 (GroupID -> [User])
    @Published var groupMembersData: [String: [User]] = [:]
    private var memberListeners: [String: ListenerRegistration] = [:]
    
    func fetchGroupMembers(groupID: String, memberUIDs: [String]) {
        guard !memberUIDs.isEmpty else { return }
        
        // 기존 리스너 제거 (중복 방지)
        memberListeners[groupID]?.remove()
        
        // 실시간 멤버 정보 리스닝
        // Firestore 'in' query supports up to 10 items.
        let listener = db.collection("users")
            .whereField(FieldPath.documentID(), in: memberUIDs)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Error fetching group members: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                
                let users = documents.compactMap { User(document: $0) }
                print("🔄 Group Members Updated for \(groupID): \(users.count) members")
                
                DispatchQueue.main.async {
                    self.groupMembersData[groupID] = users
                }
            }
        memberListeners[groupID] = listener
    }
    
    func fetchGroup(groupID: String, completion: @escaping (StudyGroup?) -> Void) {
        db.collection("study_groups").document(groupID).getDocument { snapshot, error in
            if let document = snapshot, document.exists {
                completion(StudyGroup(document: document))
            } else {
                completion(nil)
            }
        }
    }
    
    // ✨ [New] 회원 탈퇴 시 모든 그룹에서 멤버 정리
    func cleanupMemberForDeletion(uid: String, nickname: String, completion: @escaping () -> Void) {
        // (생략 없이 복구 - 길지만 필요함)
        db.collection("study_groups")
            .whereField("members", arrayContains: uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("탈퇴 정리 조회 실패: \(error)")
                    completion()
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("탈퇴 정리: 가입된 스터디 그룹 없음")
                    completion()
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                
                for doc in documents {
                    dispatchGroup.enter()
                    let groupID = doc.documentID
                    let data = doc.data()
                    let leaderID = data["leaderID"] as? String ?? ""
                    var members = data["members"] as? [String] ?? []
                    var notice = data["notice"] as? String ?? ""
                    
                    // 멤버 목록에서 제거
                    members.removeAll { $0 == uid }
                    
                    if members.isEmpty {
                        // 남은 멤버가 없으면 그룹 삭제
                        print("탈퇴 정리: 그룹(\(groupID)) 삭제 (멤버 없음)")
                        self.deleteGroup(groupID: groupID) { _ in
                            dispatchGroup.leave()
                        }
                    } else {
                        // 업데이트할 데이터 딕셔너리
                        var updateData: [String: Any] = [
                            "members": members
                        ]
                        
                        // 방장인 경우 위임 처리
                        if leaderID == uid {
                            if let newLeader = members.first {
                                updateData["leaderID"] = newLeader
                                let systemNotice = "\n[알림] 방장이 탈퇴하여 새로운 방장으로 변경되었습니다."
                                updateData["notice"] = notice + systemNotice
                                print("탈퇴 정리: 그룹(\(groupID)) 방장 위임 -> \(newLeader)")
                            }
                        } else {
                            let systemNotice = "\n[알림] '\(nickname)'님이 스터디를 떠났습니다."
                            updateData["notice"] = notice + systemNotice
                        }
                        
                        self.db.collection("study_groups").document(groupID).updateData(updateData) { error in
                            if let error = error {
                                print("탈퇴 정리 실패(그룹 업데이트): \(error)")
                            }
                            dispatchGroup.leave()
                        }
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    print("✅ 모든 스터디 그룹 멤버 정리 완료")
                    completion()
                }
            }
    }
    
    // ✨ [New] 노크하기 (Knock)
    func sendKnock(fromNickname: String, to targetUID: String, toNickname: String, completion: @escaping (Bool) -> Void) {
        let alertData: [String: Any] = [
            "type": "knock",
            "fromUID": Auth.auth().currentUser?.uid ?? "",
            "fromNickname": fromNickname,
            "toNickname": toNickname,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(targetUID).collection("alerts").addDocument(data: alertData) { error in
            completion(error == nil)
        }
    }
    
    // ✨ [New] 한줄 응원 (Cheer)
    @Published var cheers: [String: [Cheer]] = [:] // GroupID -> Cheers
    private var cheerListeners: [String: ListenerRegistration] = [:]
    
    func listenToCheers(groupID: String) {
        if cheerListeners[groupID] != nil { return }
        
        let listener = db.collection("study_groups").document(groupID)
            .collection("cheers")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                let cheersList = documents.compactMap { Cheer(document: $0) }
                DispatchQueue.main.async {
                    self.cheers[groupID] = cheersList
                }
            }
        cheerListeners[groupID] = listener
    }
    
    func addCheer(groupID: String, nickname: String, text: String, completion: @escaping (Bool) -> Void) {
        let uid = Auth.auth().currentUser?.uid ?? ""
        
        let cheerRef = db.collection("study_groups").document(groupID).collection("cheers").document()
        let cheer = Cheer(id: cheerRef.documentID, userID: uid, userNickname: nickname, text: text)
        
        var current = cheers[groupID] ?? []
        current.insert(cheer, at: 0)
        cheers[groupID] = current
        
        let batch = db.batch()
        let groupRef = db.collection("study_groups").document(groupID)
        
        batch.setData(cheer.toDictionary(), forDocument: cheerRef)
        
        batch.updateData([
            "latestCheerAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)
        
        batch.commit { error in
            if let error = error {
                print("Error adding cheer: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func removeCheerListener(groupID: String) {
        cheerListeners[groupID]?.remove()
        cheerListeners[groupID] = nil
    }
    
    // ✨ [New] 짝 스터디 매칭 로직
    enum PairSplitType {
        case twoTwoTwo
        case threeThree
        case standard
    }
    
    func generatePairs(members: [String], splitType: PairSplitType = .standard) -> [StudyGroup.PairTeam] {
        var shuffled = members.shuffled()
        let count = shuffled.count
        var result: [StudyGroup.PairTeam] = []
        
        func createTeam(_ ids: [String]) -> StudyGroup.PairTeam {
            return StudyGroup.PairTeam(memberIDs: ids)
        }
        
        switch count {
        case 6:
            if splitType == .threeThree {
                let group1 = Array(shuffled.prefix(3))
                let group2 = Array(shuffled.suffix(3))
                result = [createTeam(group1), createTeam(group2)]
            } else {
                let group1 = Array(shuffled[0..<2])
                let group2 = Array(shuffled[2..<4])
                let group3 = Array(shuffled[4..<6])
                result = [createTeam(group1), createTeam(group2), createTeam(group3)]
            }
        case 5:
            let group1 = Array(shuffled.prefix(2))
            let group2 = Array(shuffled.suffix(3))
            result = [createTeam(group1), createTeam(group2)]
        case 4:
            let group1 = Array(shuffled.prefix(2))
            let group2 = Array(shuffled.suffix(2))
            result = [createTeam(group1), createTeam(group2)]
        case 3:
            let group1 = Array(shuffled.prefix(1))
            let group2 = Array(shuffled.suffix(2))
            result = [createTeam(group1), createTeam(group2)]
        default:
            result = [createTeam(shuffled)]
        }
        
        return result
    }
    
    func updatePairs(groupID: String, currentNotice: String, pairs: [StudyGroup.PairTeam], completion: @escaping (Bool) -> Void) {
        let serializedPairs = pairs.map { ["memberIDs": $0.memberIDs] }
        
        // ✨ [Modified] 공지사항 아이템 생성 (짝 스터디 매칭)
        let content = "[알림] 오늘의 짝 스터디 매칭이 완료되었습니다! 짝을 확인해보세요."
        let newNoticeItem = StudyGroup.NoticeItem(id: UUID().uuidString, type: .pairing, content: content, date: Date())
        
        let noticeDict: [String: Any] = [
            "id": newNoticeItem.id,
            "type": newNoticeItem.type.rawValue,
            "content": newNoticeItem.content,
            "date": Timestamp(date: newNoticeItem.date)
        ]
        
        let batch = db.batch()
        let groupRef = db.collection("study_groups").document(groupID)
        
        batch.updateData([
            "pairs": serializedPairs,
            "lastPairingDate": FieldValue.serverTimestamp(),
            "notices": FieldValue.arrayUnion([noticeDict]),
            "notice": content,
            "noticeUpdatedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)
        
        // ✨ [New] GroupSchedule 추가 (짝 스터디)
        let scheduleID = UUID().uuidString
        let scheduleRef = db.collection("study_groups").document(groupID).collection("schedules").document(scheduleID)
        
        let schedule = GroupSchedule(
            id: scheduleID,
            groupID: groupID,
            title: "짝 스터디 매칭",
            content: "오늘의 짝 스터디가 매칭되었습니다. 확인해보세요!",
            date: Date(),
            type: .pairing,
            authorID: "SYSTEM",
            authorName: "시스템"
        )
        
        batch.setData(schedule.toDictionary(), forDocument: scheduleRef)
        
        batch.commit { error in
            if let error = error {
                print("Error updating pairs: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // ✨ [New] 공통 타이머 상태 업데이트
    func updateCommonTimer(groupID: String, state: StudyGroup.CommonTimerState, completion: @escaping (Bool) -> Void) {
        db.collection("study_groups").document(groupID).updateData([
            "commonTimer": state.toDictionary(),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating common timer: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // ✨ [New] 공통 타이머 참여/퇴장 및 감지 로직
    
    func joinCommonTimer(groupID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let groupRef = db.collection("study_groups").document(groupID)
        // activeParticipants 배열에 내 ID 추가
        // 중복 추가 방지는 arrayUnion이 알아서 처리함
        groupRef.updateData([
            "commonTimer.activeParticipants": FieldValue.arrayUnion([uid])
        ])
    }
    
    func leaveCommonTimer(groupID: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let groupRef = db.collection("study_groups").document(groupID)
        groupRef.updateData([
            "commonTimer.activeParticipants": FieldValue.arrayRemove([uid])
        ])
    }
    
    // 참여자 감지 리스너 (알림용)
    private var participantListener: ListenerRegistration?
    private var lastParticipants: Set<String> = []
    
    func monitorCommonTimerParticipants(groupID: String) {
        // 기존 리스너 제거
        participantListener?.remove()
        lastParticipants = [] // 초기화
        
        participantListener = db.collection("study_groups").document(groupID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let data = snapshot?.data(),
                      let timerData = data["commonTimer"] as? [String: Any],
                      let activeParticipants = timerData["activeParticipants"] as? [String] else { return }
                
                let currentSet = Set(activeParticipants)
                let myUID = Auth.auth().currentUser?.uid ?? ""
                
                // 처음 로드될 때는 알림 보내지 않음 (lastParticipants가 비었을 때)
                if !self.lastParticipants.isEmpty {
                    // 새로 들어온 사람 찾기 (Set 차집합)
                    let newMembers = currentSet.subtracting(self.lastParticipants)
                    
                    for memberID in newMembers {
                        // 내가 아닌 경우에만 알림
                        if memberID != myUID {
                            self.checkAndNotifyEntry(groupID: groupID, memberID: memberID, timerData: timerData)
                        }
                    }
                }
                
                self.lastParticipants = currentSet
            }
    }
    
    func stopMonitoringParticipants() {
        participantListener?.remove()
        participantListener = nil
        lastParticipants = []
    }
    
    func checkAndNotifyEntry(groupID: String, memberID: String, timerData: [String: Any]) {
        // 시간 조건 체크: 시작 10분 전 ~ 시작 시간 (공부 중 방해 금지)
        guard let startTime = (timerData["startTime"] as? Timestamp)?.dateValue() else { return }
        
        let now = Date()
        let tenMinutesBefore = startTime.addingTimeInterval(-600) // 10분 전
        
        // 범위: [10분 전 ~ 시작 시간]
        guard now >= tenMinutesBefore && now <= startTime else { return }
        
        // 닉네임 가져오기 (캐시된 groupMembersData 활용 시도)
        // 없다면 DB 조회해야 하는데, 일단 캐시나 기본값 사용
        var nickname = "스터디원"
        if let members = self.groupMembersData[groupID], let user = members.first(where: { $0.id == memberID }) {
            nickname = user.nickname
        }
        
        // 로컬 알림 발송 (즉시)
        NotificationManager.shared.scheduleNotification(
            for: ScheduleItem(title: "입장 알림", details: "", startDate: Date(), endDate: Date(), subject: "공통 타이머", isCompleted: false, hasReminder: false, ownerID: "", isPostponed: false, studyPurpose: StudyPurpose.study.rawValue), // Dummy Item
            triggerDate: Date().addingTimeInterval(1), // 1초 뒤 즉시 실행
            identifier: UUID().uuidString,
            body: "🚪 \(nickname)님이 공통 타이머에 입장했습니다! 얼른 함께해요 🔥"
        )
    }
    
    // ✨ [New] 중복 참여 방지 확인
    func hasActiveTimerInOtherGroups(excluding groupID: String) -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        return myGroups.contains { group in
            // 제외할 그룹(현재 그룹)이 아니고
            if group.id == groupID { return false }
            
            // 타이머가 활성화되어 있고
            guard let timer = group.commonTimer, timer.isActive else { return false }
            
            // 내가 참여자 명단에 있다면
            return timer.activeParticipants.contains(uid)
        }
    }
}

