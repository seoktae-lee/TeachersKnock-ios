import SwiftData
import Foundation

@Model
final class ScheduleItem: Identifiable {
    var id: UUID
    var title: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var subject: String
    var isCompleted: Bool
    var hasReminder: Bool
    var ownerID: String
    var isPostponed: Bool
    // ✨ [추가] 공부 목적 저장 필드
    var studyPurpose: String
    
    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        startDate: Date,
        endDate: Date? = nil,
        subject: String = "교육학",
        isCompleted: Bool = false,
        hasReminder: Bool = false,
        ownerID: String,
        isPostponed: Bool = false,
        // ✨ [추가] 기본값은 '인강시청' 등으로 설정
        studyPurpose: String = StudyPurpose.lectureWatching.rawValue
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.subject = subject
        self.isCompleted = isCompleted
        self.hasReminder = hasReminder
        self.ownerID = ownerID
        self.isPostponed = isPostponed
        self.studyPurpose = studyPurpose
    }
    
    var asDictionary: [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "details": details,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate?.timeIntervalSince1970 ?? startDate.timeIntervalSince1970,
            "subject": subject,
            "isCompleted": isCompleted,
            "hasReminder": hasReminder,
            "ownerID": ownerID,
            "isPostponed": isPostponed,
            "studyPurpose": studyPurpose // ✨ 딕셔너리 변환에도 추가
        ]
    }
}
