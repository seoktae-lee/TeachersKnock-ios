import SwiftData
import Foundation

@Model
final class DailyNote: Identifiable {
    var id: UUID
    var date: Date          // 날짜
    var emotion: String     // 이모지 (예: "🥰", "🔥", "💦", "☁️", "😐")
    var content: String     // 한줄 메모
    var ownerID: String     // 유저 ID
    
    init(
        id: UUID = UUID(),
        date: Date,
        emotion: String = "😐",
        content: String = "",
        ownerID: String
    ) {
        self.id = id
        self.date = date
        self.emotion = emotion
        self.content = content
        self.ownerID = ownerID
    }
    
    // 서버 전송용 (Firestore)
    var asDictionary: [String: Any] {
        return [
            "id": id.uuidString,
            "date": date.timeIntervalSince1970,
            "emotion": emotion,
            "content": content,
            "ownerID": ownerID
        ]
    }
}
