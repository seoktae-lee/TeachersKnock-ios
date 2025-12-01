import Foundation
import SwiftData

// 시험 목표(Goal) 데이터를 저장하는 모델
@Model
final class Goal {
    var title: String
    var targetDate: Date
    var creationDate: Date
    var isPrimaryGoal: Bool
    var ownerID: String
    
    // ✨ 캐릭터 육성 여부 (켜면 true, 끄면 false)
    var hasCharacter: Bool
    
    // ✨ 목표 기간 (일수) - 난이도 조절용
    var totalDays: Int
    
    init(title: String, targetDate: Date, isPrimaryGoal: Bool = true, ownerID: String, hasCharacter: Bool = false) {
        self.title = title
        self.targetDate = targetDate
        self.creationDate = Date()
        self.isPrimaryGoal = isPrimaryGoal
        self.ownerID = ownerID
        self.hasCharacter = hasCharacter
        
        // 목표일까지 며칠 남았는지 계산 (최소 1일)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetDate)
        let diff = calendar.dateComponents([.day], from: today, to: target).day ?? 1
        self.totalDays = max(1, diff)
    }
}
