import Foundation
import SwiftData

@Model
final class Goal {
    // ✨ [NEW] 고유 ID (서버 동기화용)
    var id: UUID
    
    var title: String
    var targetDate: Date
    var startDate: Date
    var ownerID: String
    var hasCharacter: Bool
    
    var characterName: String
    var characterColor: String
    var isPrimaryGoal: Bool
    
    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(components.day ?? 1, 1)
    }
    
    init(
        id: UUID = UUID(), // 기본값 생성
        title: String,
        targetDate: Date,
        ownerID: String,
        hasCharacter: Bool,
        startDate: Date = Date(),
        characterName: String = "티노",
        characterColor: String = "Blue",
        isPrimaryGoal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.startDate = startDate
        self.ownerID = ownerID
        self.hasCharacter = hasCharacter
        self.characterName = characterName
        self.characterColor = characterColor
        self.isPrimaryGoal = isPrimaryGoal
    }
    
    // ✨ 서버 저장용 데이터 변환 (Dictionary)
    var asDictionary: [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "targetDate": targetDate.timeIntervalSince1970,
            "startDate": startDate.timeIntervalSince1970,
            "ownerID": ownerID,
            "hasCharacter": hasCharacter,
            "characterName": characterName,
            "characterColor": characterColor,
            "isPrimaryGoal": isPrimaryGoal
        ]
    }
}
