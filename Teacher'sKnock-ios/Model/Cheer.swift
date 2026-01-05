import Foundation
import FirebaseFirestore

struct Cheer: Identifiable, Codable {
    var id: String
    var userID: String
    var userNickname: String
    var text: String
    var createdAt: Date
    
    init(id: String = UUID().uuidString, userID: String, userNickname: String, text: String) {
        self.id = id
        self.userID = userID
        self.userNickname = userNickname
        self.text = text
        self.createdAt = Date()
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        self.id = document.documentID
        self.userID = data["userID"] as? String ?? ""
        self.userNickname = data["userNickname"] as? String ?? "알 수 없음"
        self.text = data["text"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userID": userID,
            "userNickname": userNickname,
            "text": text,
            "createdAt": createdAt
        ]
    }
}
