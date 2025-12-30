import Foundation
import SwiftData

@Model
final class StudyRecord {
    var durationSeconds: Int
    var areaName: String
    var date: Date
    var ownerID: String
    var studyPurpose: String
    var memo: String?
    
    // ✨ [오류 해결] GoalListView에서 'record.goal'을 참조할 수 있도록 속성 추가
    var goal: Goal?

    init(durationSeconds: Int, areaName: String, date: Date = Date(), ownerID: String, studyPurpose: String, memo: String? = nil, goal: Goal? = nil) {
        self.durationSeconds = durationSeconds
        self.areaName = areaName
        self.date = date
        self.ownerID = ownerID
        self.studyPurpose = studyPurpose
        self.memo = memo
        self.goal = goal
    }
}
