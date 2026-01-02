import Foundation
import FirebaseFirestore

struct StudyGroup: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var leaderID: String
    var members: [String] // List of member UIDs
    var maxMembers: Int
    var createdAt: Date
    
    // UI convenience
    var memberCount: Int { members.count }
    
    // Manual Init
    init(id: String = UUID().uuidString, name: String, description: String, leaderID: String, members: [String] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.leaderID = leaderID
        self.members = members.isEmpty ? [leaderID] : members // Leader is always a member
        self.maxMembers = 6 // Fixed constraint
        self.createdAt = Date()
    }
    
    // Init from Firestore
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let leaderID = data["leaderID"] as? String,
              let members = data["members"] as? [String]
        else { return nil }
        
        self.id = document.documentID
        self.name = name
        self.description = data["description"] as? String ?? ""
        self.leaderID = leaderID
        self.members = members
        self.maxMembers = data["maxMembers"] as? Int ?? 6
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
    
    // To Firestore Dictionary
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description,
            "leaderID": leaderID,
            "members": members,
            "maxMembers": maxMembers,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
