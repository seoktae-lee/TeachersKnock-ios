import SwiftData
import Foundation

@Model
final class ScheduleItem {
    var id: UUID
    var title: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var hasReminder: Bool
    var ownerID: String
    var isPostponed: Bool
    
    // ✨ [재추가] 과목 정보 (임용고시 필수)
    var subject: String

    init(title: String, details: String = "", startDate: Date, endDate: Date? = nil, subject: String = "교육학", isCompleted: Bool = false, hasReminder: Bool = false, ownerID: String, isPostponed: Bool = false) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.subject = subject // 초기화
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
        self.ownerID = ownerID
        self.isPostponed = isPostponed
    }
}
