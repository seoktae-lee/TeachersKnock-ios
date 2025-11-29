import Foundation
import SwiftData

// 시험 목표(Goal) 데이터를 저장하는 모델
@Model
final class Goal {
    // 1. D-day 목표 이름
    var title: String
    
    // 2. 시험 목표 날짜
    var targetDate: Date
    
    // 3. 목표 생성 시간
    var creationDate: Date
    
    // 4. 목표 중요도/상태
    var isPrimaryGoal: Bool
    
    // ✨ 5. 주인 이름표 (누가 만든 목표인지 저장)
    var ownerID: String
    
    init(title: String, targetDate: Date, isPrimaryGoal: Bool = true, ownerID: String) {
        self.title = title
        self.targetDate = targetDate
        self.creationDate = Date()
        self.isPrimaryGoal = isPrimaryGoal
        self.ownerID = ownerID // 저장 시 ID 기록
    }
}
