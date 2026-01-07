import Foundation
import FirebaseFirestore

struct GroupSchedule: Identifiable, Codable, Hashable {
    var id: String
    var groupID: String
    var title: String
    var content: String
    var date: Date
    var type: ScheduleType
    var authorID: String
    var authorName: String // UI 표시용
    var createdAt: Date
    
    enum ScheduleType: String, Codable, CaseIterable {
        case notice = "공지"
        case pairing = "짝 스터디"
        case timer = "공통 타이머"
        case gathering = "모임"
        case etc = "기타"
        
        var icon: String {
            switch self {
            case .notice: return "megaphone.fill"
            case .pairing: return "person.2.fill"
            case .timer: return "timer"
            case .gathering: return "person.3.fill"
            case .etc: return "calendar"
            }
        }
    }
    
    init(id: String = UUID().uuidString, groupID: String, title: String, content: String, date: Date, type: ScheduleType, authorID: String, authorName: String) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.content = content
        self.date = date
        self.type = type
        self.authorID = authorID
        self.authorName = authorName
        self.createdAt = Date()
    }
    
    // Firestore Init
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let groupID = data["groupID"] as? String,
              let title = data["title"] as? String,
              let content = data["content"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let typeString = data["type"] as? String,
              let type = ScheduleType(rawValue: typeString),
              let authorID = data["authorID"] as? String,
              let authorName = data["authorName"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        self.id = document.documentID
        self.groupID = groupID
        self.title = title
        self.content = content
        self.date = dateTimestamp.dateValue()
        self.type = type
        self.authorID = authorID
        self.authorName = authorName
        self.createdAt = createdAtTimestamp.dateValue()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "groupID": groupID,
            "title": title,
            "content": content,
            "date": Timestamp(date: date),
            "type": type.rawValue,
            "authorID": authorID,
            "authorName": authorName,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
