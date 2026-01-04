import Foundation
import FirebaseFirestore

struct StudyInvitation: Identifiable, Codable {
    var id: String
    var groupID: String
    var groupName: String      // UI 표시용
    var inviterID: String
    var inviterName: String    // UI 표시용
    var receiverID: String     // 초대 받는 사람 (User ID)
    var status: String         // "pending", "accepted", "rejected"
    var createdAt: Date
    
    // Init form Firestore
    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let data = data else { return nil }
        
        self.id = document.documentID
        self.groupID = data["groupID"] as? String ?? ""
        self.groupName = data["groupName"] as? String ?? ""
        self.inviterID = data["inviterID"] as? String ?? ""
        self.inviterName = data["inviterName"] as? String ?? ""
        self.receiverID = data["receiverID"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    // Manual Init
    init(id: String = UUID().uuidString, groupID: String, groupName: String, inviterID: String, inviterName: String, receiverID: String, status: String = "pending") {
        self.id = id
        self.groupID = groupID
        self.groupName = groupName
        self.inviterID = inviterID
        self.inviterName = inviterName
        self.receiverID = receiverID
        self.status = status
        self.createdAt = Date()
    }
    
    // To Dictionary
    func toDictionary() -> [String: Any] {
        return [
            "groupID": groupID,
            "groupName": groupName,
            "inviterID": inviterID,
            "inviterName": inviterName,
            "receiverID": receiverID,
            "status": status,
            "createdAt": createdAt
        ]
    }
}
