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
    var pairs: [[String]]? // 매칭된 짝 (User ID 배열의 배열) e.g. [["uid1", "uid2"], ["uid3", "uid4"]]
    
    // ✨ [New] 공통 타이머 상태
    struct CommonTimerState: Codable, Hashable {
        var goal: String
        var startTime: Date
        var endTime: Date
        var subject: String
        var purpose: String
        var isActive: Bool
        
        func toDictionary() -> [String: Any] {
            return [
                "goal": goal,
                "startTime": startTime,
                "endTime": endTime,
                "subject": subject,
                "purpose": purpose,
                "isActive": isActive
            ]
        }
    }
    var commonTimer: CommonTimerState?
    
    // UI convenience
    var memberCount: Int { members.count }
    
    // Manual Init
    init(id: String = UUID().uuidString, name: String, description: String, leaderID: String, members: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.notice = ""  // 초기값 없음
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
        self.pairs = data["pairs"] as? [[String]]
        
        if let timerData = data["commonTimer"] as? [String: Any],
           let goal = timerData["goal"] as? String,
           let start = (timerData["startTime"] as? Timestamp)?.dateValue(),
           let end = (timerData["endTime"] as? Timestamp)?.dateValue(),
           let subject = timerData["subject"] as? String,
           let purpose = timerData["purpose"] as? String,
           let isActive = timerData["isActive"] as? Bool {
            self.commonTimer = CommonTimerState(goal: goal, startTime: start, endTime: end, subject: subject, purpose: purpose, isActive: isActive)
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
            "leaderID": leaderID,
            "members": members,
            "maxMembers": maxMembers,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "noticeUpdatedAt": noticeUpdatedAt ?? FieldValue.serverTimestamp(), // nil이면 생성시점? or just ignore
            "latestCheerAt": latestCheerAt, /// nil okay
            "lastPairingDate": lastPairingDate,
            "pairs": pairs,
            "commonTimer": commonTimer.map { [
                "goal": $0.goal,
                "startTime": $0.startTime,
                "endTime": $0.endTime,
                "subject": $0.subject,
                "purpose": $0.purpose,
                "isActive": $0.isActive
            ] } ?? FieldValue.delete()
        ]
    }
}
