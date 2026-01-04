import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String
    var nickname: String
    var teacherKnockID: String?
    var university: String?
    var targetOffice: String? // Enum mapping can be done in view or helper
    var friends: [String] // List of friend UIDs
    var isStudying: Bool // ✨ [New] 현재 공부 중인지 여부
    var createdAt: Date
    
    // UI Convenience
    var displayName: String { nickname }
    
    // Init from Firestore
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.nickname = data["nickname"] as? String ?? "알 수 없음"
        self.teacherKnockID = data["teacherKnockID"] as? String
        self.university = data["university"] as? String
        self.targetOffice = data["targetOffice"] as? String
        self.friends = data["friends"] as? [String] ?? []
        self.isStudying = data["isStudying"] as? Bool ?? false
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
    
    // Manual Init
    init(id: String, nickname: String, tkID: String?, university: String?, friends: [String] = [], isStudying: Bool = false) {
        self.id = id
        self.nickname = nickname
        self.teacherKnockID = tkID
        self.university = university
        self.friends = friends
        self.isStudying = isStudying
        self.createdAt = Date()
    }
}
