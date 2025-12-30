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
    
    // ✨ [추가] 캐릭터의 스타팅 타입 (bird, plant, sea)
    var characterType: String
    
    // ✨ [NEW] 역방향 관계 설정 (StudyRecord 삭제 시 자동 처리됨)
    // Goal이 삭제되면 관련 기록은 유지할지 삭제할지 결정해야 하나,
    // 보통 기록은 소중하므로 .nullify가 안전할 수 있습니다. 
    // 하지만 "Goal에 속한 기록"의 개념이 강하다면 .cascade도 고려 가능합니다.
    // 여기서는 안전하게 .nullify(기본값) 혹은 명시적으로 관계만 정의합니다.
    @Relationship(deleteRule: .nullify, inverse: \StudyRecord.goal)
    var records: [StudyRecord]? = []
    
    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(components.day ?? 1, 1)
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date,
        ownerID: String,
        hasCharacter: Bool,
        startDate: Date = Date(),
        characterName: String = "티노",
        characterColor: String = "Blue",
        isPrimaryGoal: Bool = false,
        characterType: String = "bird" // ✨ 초기화 시 기본값 설정
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
        self.characterType = characterType // ✨ 할당
    }
    
    // ✨ 서버 저장용 데이터 변환 (characterType 필드 포함)
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
            "isPrimaryGoal": isPrimaryGoal,
            "characterType": characterType // ✨ 서버 동기화 시 데이터 추가
        ]
    }
}
