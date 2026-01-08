import Foundation
import FirebaseFirestore

struct StudyGroup: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var notice: String // ✨ [New] 공지사항
    var leaderID: String
    var members: [String] // List of member UIDs
    var maxMembers: Int
    var createdAt: Date
    var updatedAt: Date // ✨ [New] 마지막 수정 시간 (알림 배지용)
    var noticeUpdatedAt: Date? // ✨ [New] 공지사항 마지막 업데이트 시간 (알림 배지용)
    var latestCheerAt: Date? // ✨ [New] 마지막 응원 등록 시간 (알림 배지용)
    
    // ✨ [New] 짝 스터디 매칭 정보
    var lastPairingDate: Date? // 마지막 매칭 생성 날짜
    
    // Firestore 중첩 배열 한계로 인한 구조체 래핑
    struct PairTeam: Codable, Hashable {
        var memberIDs: [String]
    }
    var pairs: [PairTeam]? // 매칭된 짝 (User ID 배열을 담은 구조체의 배열)
    
    // ✨ [New] 공통 타이머 상태
    struct CommonTimerState: Codable, Hashable {
        var goal: String
        var startTime: Date
        var endTime: Date
        var subject: String
        var purpose: String
        var isActive: Bool
        
        // ✨ [New] 실시간 참여자 목록 (User IDs)
        var activeParticipants: [String] = []
        
        func toDictionary() -> [String: Any] {
            return [
                "goal": goal,
                "startTime": startTime,
                "endTime": endTime,
                "subject": subject,
                "purpose": purpose,
                "isActive": isActive,
                "activeParticipants": activeParticipants
            ]
        }
    }
    var commonTimer: CommonTimerState?
    
    // ✨ [New] 공지사항 아이템 구조체
    struct NoticeItem: Identifiable, Codable, Hashable {
        var id: String
        var type: NoticeType
        var content: String
        var date: Date
        
        enum NoticeType: String, Codable {
            case general // 일반 (시스템 알림 등)
            case timer // 공통 타이머
            case pairing // 짝 스터디
            case announcement // ✨ [New] 방장 공지 (고정)
        }
    }
    var notices: [NoticeItem] = [] // ✨ [New] 구조화된 공지사항 목록
    
    // UI convenience
    var memberCount: Int { members.count }
    
    // Manual Init
    init(id: String = UUID().uuidString, name: String, description: String, leaderID: String, members: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.notice = ""  // 초기값 없음
        self.notices = [] // ✨ [New]
        self.leaderID = leaderID
        self.members = members.isEmpty ? [leaderID] : members // Leader is always a member
        self.maxMembers = 6 // Fixed constraint
        self.createdAt = Date()
        self.updatedAt = Date() // 생성 시점
        self.noticeUpdatedAt = nil
        self.latestCheerAt = nil
        self.lastPairingDate = nil
        self.pairs = nil
        self.commonTimer = nil
    }
    
    // Init from Firestore
    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let data = data else { return nil }
        
        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.notice = data["notice"] as? String ?? ""
        self.leaderID = data["leaderID"] as? String ?? ""
        self.members = data["members"] as? [String] ?? []
        self.maxMembers = data["maxMembers"] as? Int ?? 6
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.noticeUpdatedAt = (data["noticeUpdatedAt"] as? Timestamp)?.dateValue()
        self.latestCheerAt = (data["latestCheerAt"] as? Timestamp)?.dateValue()
        self.lastPairingDate = (data["lastPairingDate"] as? Timestamp)?.dateValue()
        
        // ✨ [New] Deserialize notices
        if let noticesData = data["notices"] as? [[String: Any]] {
            self.notices = noticesData.compactMap { dict -> NoticeItem? in
                guard let id = dict["id"] as? String,
                      let typeRaw = dict["type"] as? String,
                      let type = NoticeItem.NoticeType(rawValue: typeRaw),
                      let content = dict["content"] as? String,
                      let date = (dict["date"] as? Timestamp)?.dateValue() else { return nil }
                return NoticeItem(id: id, type: type, content: content, date: date)
            }
            // 최신순 정렬 (혹시 몰라서)
            self.notices.sort { $0.date > $1.date }
        } else {
            self.notices = []
        }
        
        // Deserialize pairs
        if let pairsData = data["pairs"] as? [[String: Any]] {
            self.pairs = pairsData.compactMap { dict -> PairTeam? in
                if let ids = dict["memberIDs"] as? [String] {
                    return PairTeam(memberIDs: ids)
                }
                return nil
            }
        } else {
            self.pairs = nil
        }
        
        if let timerData = data["commonTimer"] as? [String: Any],
           let goal = timerData["goal"] as? String,
           let start = (timerData["startTime"] as? Timestamp)?.dateValue(),
           let end = (timerData["endTime"] as? Timestamp)?.dateValue(),
           let subject = timerData["subject"] as? String,
           let purpose = timerData["purpose"] as? String,
           let isActive = timerData["isActive"] as? Bool {
            let participants = timerData["activeParticipants"] as? [String] ?? []
            self.commonTimer = CommonTimerState(
                goal: goal,
                startTime: start,
                endTime: end,
                subject: subject,
                purpose: purpose,
                isActive: isActive,
                activeParticipants: participants
            )
        } else {
            self.commonTimer = nil
        }
    }
    
    // Convert to Dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "notice": notice,
            "notices": notices.map { [
                "id": $0.id,
                "type": $0.type.rawValue,
                "content": $0.content,
                "date": $0.date
            ] }, // ✨ [New]
            "leaderID": leaderID,
            "members": members,
            "maxMembers": maxMembers,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "noticeUpdatedAt": noticeUpdatedAt ?? FieldValue.serverTimestamp(), // nil이면 생성시점? or just ignore
            "latestCheerAt": latestCheerAt, /// nil okay
            "lastPairingDate": lastPairingDate,
            "pairs": pairs?.map { ["memberIDs": $0.memberIDs] } ?? FieldValue.delete(),
            "commonTimer": commonTimer.map { [
                "goal": $0.goal,
                "startTime": $0.startTime,
                "endTime": $0.endTime,
                "subject": $0.subject,
                "purpose": $0.purpose,
                "isActive": $0.isActive,
                "activeParticipants": $0.activeParticipants
            ] } ?? FieldValue.delete()
        ]
    }
}
