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
    
    // ✨ [New] 공지사항 업데이트
    func updateNotice(groupID: String, notice: String) {
        db.collection("study_groups").document(groupID).updateData([
            "notice": notice,
            "noticeUpdatedAt": FieldValue.serverTimestamp(), // ✨ [New] 공지사항 수정 시간 별도 기록
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // ✨ [New] 시스템 알림 자동 정리 (상세 진입 시)
    func cleanupSystemNotice(groupID: String, notice: String) {
        // [알림]으로 시작하는 문구 제거
        // 예: "기존 공지\n[알림] 누구 탈퇴" -> "기존 공지"
        // 정규식 등으로 [알림] 포함 라인을 제거
        
        if !notice.contains("[알림]") { return }
        
        let lines = notice.components(separatedBy: "\n")
        let cleanedLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).starts(with: "[알림]") }
        let newNotice = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if newNotice != notice {
            print("🧹 시스템 알림 정리 실행: \(groupID)")
            // 업데이트하되, updatedAt은 갱신하지 않음 (읽어서 지운거니 알림 또 띄울 필요 없음)
            // 다만 다른 멤버 입장에선? -> 공유되는 공지사항이므로
            // A가 읽어서 지우면 B도 지워짐. "일회성"이라는게 "누군가 확인하면 사라짐"인가, 아니면 "나한테만 안보임"인가?
            // User Request: "사용자가 스터디방에 들어가서 [알림]으로 확인했으면 이 알림은 없애는걸로 하자."
            // "공유된 스터디방"이므로, 공지사항 텍스트 자체가 수정되면 모두에게 사라짐.
            // 이게 의도된 동작("한 명이라도 확인하면 처리됨" 혹은 "확인 후 삭제는 공유됨")으로 보임.
            // 만약 개인별로 안보이게 하려면 로컬 필터링을 해야 하나, "공지사항"은 DB 필드임.
            // 요청 맥락상 "공지사항(Shared)에 텍스트가 추가됨" -> "확인 후 삭제" -> DB에서 삭제가 맞음.
            
            db.collection("study_groups").document(groupID).updateData([
                "notice": newNotice
                // updatedAt 갱신 X -> 조용히 삭제
            ])
        }
    }
    
    // ✨ [New] 읽음 처리 및 확인
    // ✨ [New] 읽음 처리 및 확인
    func markAsRead(groupID: String) {
        let key = "lastReadTime_\(groupID)"
        UserDefaults.standard.set(Date(), forKey: key)
        objectWillChange.send() // UI 갱신 유도
    }
    
    // ✨ [New] 공지사항 읽음 처리
    func markNoticeAsRead(groupID: String) {
        let key = "lastReadNotice_\(groupID)"
        UserDefaults.standard.set(Date(), forKey: key)
        objectWillChange.send()
    }
    
    // ✨ [New] 응원 읽음 처리
    func markCheersAsRead(groupID: String) {
        let key = "lastReadCheer_\(groupID)"
        UserDefaults.standard.set(Date(), forKey: key)
        objectWillChange.send()
    }
    
    func hasUnreadUpdates(group: StudyGroup) -> Bool {
        let key = "lastReadTime_\(group.id)"
        let lastRead = UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast
        
        // 정밀도 문제(Timestamp vs Date) 무시를 위해 1초 정도 여유
        return group.updatedAt > lastRead.addingTimeInterval(1)
    }
    
    // ✨ [New] 공지사항 안 읽음 확인
    func hasUnreadNotice(group: StudyGroup) -> Bool {
        guard let noticeUpdatedAt = group.noticeUpdatedAt else { return false }
        let key = "lastReadNotice_\(group.id)"
        let lastRead = UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast
        
        // 내 로컬 시간보다 noticeUpdatedAt이 더 미래(최신)이면 안 읽음
        // 단, 처음 생성시 nil이면 false.
        return noticeUpdatedAt > lastRead.addingTimeInterval(1)
    }
    

    
    // ✨ [New] 응원 안 읽음 확인
    func hasUnreadCheers(group: StudyGroup) -> Bool {
        guard let latestDate = group.latestCheerAt else { return false }
        let key = "lastReadCheer_\(group.id)"
        let lastRead = UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast
        
        return latestDate > lastRead.addingTimeInterval(1)
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
        // 1. 내가 포함된 모든 그룹 조회
        // 주의: 이 메서드는 임시 인스턴스에서 호출될 수 있으므로, [weak self]를 사용하면
        // 비동기 작업 도중 self가 해제되어 로직이 중단될 수 있습니다.
        // 따라서 강한 참조를 유지하거나, self 캡처를 신중히 해야 합니다.
        // 여기서는 Firestore 클로저가 self를 캡처하여 작업 완료 시까지 인스턴스를 유지하도록 합니다.
        
        db.collection("study_groups")
            .whereField("members", arrayContains: uid)
            .getDocuments { snapshot, error in
                // [weak self] 제거 -> self가 살아있음
                
                if let error = error {
                    print("탈퇴 정리 조회 실패: \(error)")
                    // 조회 실패하더라도 일단 진행(유저 삭제)을 위해 completion 호출
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
                            // 가입일 순 등 로직이 복잡하므로, 일단 members 배열의 첫 번째 사람에게 위임
                            if let newLeader = members.first {
                                updateData["leaderID"] = newLeader
                                let systemNotice = "\n[알림] 방장이 탈퇴하여 새로운 방장으로 변경되었습니다."
                                updateData["notice"] = notice + systemNotice
                                print("탈퇴 정리: 그룹(\(groupID)) 방장 위임 -> \(newLeader)")
                            }
                        } else {
                            // 일반 멤버인 경우 공지사항에 '탈퇴' 알림 추가 (선택사항)
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
        // 1시간 쿨타임 체크는 서버사이드 룰이나 클라이언트 로컬 체크로 가능하지만
        // 여기서는 클라이언트 로직으로 구현 (LocalStorage or simply firestore add)
        // User request: 1 hour cooldown.
        // 쿨타임 체크 로직은 UI레벨에서 UserDefaults로 관리하거나,
        // Firestore 'sent_knocks' 컬렉션을 통해 관리 가능.
        // 간단히 UI에서 체크하도록 하고 여기서는 전송 로직만 수행.
        
        let alertData: [String: Any] = [
            "type": "knock",
            "fromUID": Auth.auth().currentUser?.uid ?? "",
            "fromNickname": fromNickname,
            "toNickname": toNickname, // ✨ [New] 받는 사람 닉네임 추가 (알림 메시지용)
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
        if cheerListeners[groupID] != nil { return } // 이미 리스닝 중
        
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
        
        // Optimistic Update
        var current = cheers[groupID] ?? []
        current.insert(cheer, at: 0)
        cheers[groupID] = current
        
        let batch = db.batch()
        let groupRef = db.collection("study_groups").document(groupID)
        
        // Add Cheer
        batch.setData(cheer.toDictionary(), forDocument: cheerRef)
        
        // Update Group
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
}
