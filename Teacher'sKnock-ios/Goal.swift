import Foundation
import SwiftData

// 시험 목표(Goal) 데이터를 저장하는 모델
@Model
final class Goal {
    // 1. D-day 목표 이름 (예: 2026학년도 초등 임용)
    var title: String
    
    // 2. 시험 목표 날짜 (D-day 기준 날짜)
    var targetDate: Date
    
    // 3. 목표 생성 시간
    var creationDate: Date
    
    // 4. 목표 중요도/상태
    var isPrimaryGoal: Bool
    
    init(title: String, targetDate: Date, isPrimaryGoal: Bool = true) {
        self.title = title
        self.targetDate = targetDate
        self.creationDate = Date()
        self.isPrimaryGoal = isPrimaryGoal
    }
}
