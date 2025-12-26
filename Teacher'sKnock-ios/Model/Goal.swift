import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var targetDate: Date
    var startDate: Date      // 목표 시작일 (기존 creationDate 대체)
    var ownerID: String
    var hasCharacter: Bool
    
    // ✨ [NEW] 캐릭터 별명 & 테마 색상 추가
    var characterName: String
    var characterColor: String
    
    // 총 목표 기간 (일수) 계산
    // 저장된 값이 아니라, 시작일과 목표일 사이의 날짜를 매번 정확히 계산합니다.
    var totalDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(components.day ?? 1, 1) // 최소 1일 보장
    }
    
    init(
        title: String,
        targetDate: Date,
        ownerID: String,
        hasCharacter: Bool,
        startDate: Date = Date(),       // 기본값: 현재 시간
        characterName: String = "티노", // 기본값: 티노
        characterColor: String = "Blue" // 기본값: 파랑
    ) {
        self.title = title
        self.targetDate = targetDate
        self.startDate = startDate
        self.ownerID = ownerID
        self.hasCharacter = hasCharacter
        self.characterName = characterName
        self.characterColor = characterColor
    }
}
