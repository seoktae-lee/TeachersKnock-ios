import Foundation
import SwiftData

// 플래너 일정(ScheduleItem) 데이터를 저장하는 모델
@Model
final class ScheduleItem {
    // 1. 일정 이름
    var title: String
    
    // 2. 일정 상세 내용
    var details: String
    
    // 3. 시작 및 종료 날짜
    var startDate: Date
    var endDate: Date? // 종료 시간은 없을 수도 있음

    // 4. 완료 여부 (체크박스)
    var isCompleted: Bool
    
    // 5. 알림 설정 여부
    var hasReminder: Bool

    init(title: String, details: String = "", startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, hasReminder: Bool = false) {
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
    }
}
