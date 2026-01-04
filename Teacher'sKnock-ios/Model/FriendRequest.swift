import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Codable {
    var id: String
    var senderID: String
    var senderName: String    // 보낸 사람 닉네임
    var receiverID: String    // 받는 사람 UID
    var status: String        // "pending", "accepted", "rejected"
    var createdAt: Date
    
    // Init from Firestore
    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let data = data else { return nil }
        
        self.id = document.documentID
        self.senderID = data["senderID"] as? String ?? ""
        self.senderName = data["senderName"] as? String ?? ""
        self.receiverID = data["receiverID"] as? String ?? ""
        self.status = data["status"] as? String ?? "pending"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    // Manual Init
    init(id: String = UUID().uuidString, senderID: String, senderName: String, receiverID: String, status: String = "pending") {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.receiverID = receiverID
        self.status = status
        self.createdAt = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "senderID": senderID,
            "senderName": senderName,
            "receiverID": receiverID,
            "status": status,
            "createdAt": createdAt
        ]
    }
}
