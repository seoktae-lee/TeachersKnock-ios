import Foundation
import FirebaseFirestore

struct StudyGroup: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var notice: String // ✨ [New] 공지사항
    var leaderID: String
    var members: [String] // List of member UIDs
    var maxMembers: Int
    var createdAt: Date
    var updatedAt: Date // ✨ [New] 마지막 수정 시간 (알림 배지용)
    
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
            "updatedAt": updatedAt
        ]
    }
}
