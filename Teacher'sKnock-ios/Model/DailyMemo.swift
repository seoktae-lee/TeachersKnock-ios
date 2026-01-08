import Foundation
import FirebaseFirestore

struct DailyMemo: Identifiable, Codable {
    var id: String // "yyyyMMdd"
    var content: String
    var location: String
    var members: String
    var updatedAt: Date
    
    // UI Helper
    var isEmpty: Bool {
        return content.isEmpty && location.isEmpty && members.isEmpty
    }
    
    init(id: String, content: String = "", location: String = "", members: String = "") {
        self.id = id
        self.content = content
        self.location = location
        self.members = members
        self.updatedAt = Date()
    }
    
    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let data = data else { return nil }
        
        self.id = document.documentID
        self.content = data["content"] as? String ?? ""
        self.location = data["location"] as? String ?? ""
        self.members = data["members"] as? String ?? ""
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "content": content,
            "location": location,
            "members": members,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
