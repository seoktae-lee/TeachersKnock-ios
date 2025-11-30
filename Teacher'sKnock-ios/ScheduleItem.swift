import Foundation
import SwiftData

// 플래너 및 특화 일정(ScheduleItem) 데이터를 저장하는 모델
@Model
final class ScheduleItem {
    var title: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var hasReminder: Bool
    
    // ✨ 주인 이름표 (누가 만든 일정인지 저장)
    var ownerID: String

    init(title: String, details: String = "", startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, hasReminder: Bool = false, ownerID: String) {
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
        self.ownerID = ownerID
    }
}
