import Foundation
import SwiftData

@Model
final class StudyRecord {
    var durationSeconds: Int
    var areaName: String
    var date: Date
    var ownerID: String
    var studyPurpose: String // 통계용 표준 카테고리 (인강시청, 자습 등)
    var memo: String?        // ✨ [추가] 상세 일정 제목 저장용

    init(durationSeconds: Int, areaName: String, date: Date = Date(), ownerID: String, studyPurpose: String, memo: String? = nil) {
        self.durationSeconds = durationSeconds
        self.areaName = areaName
        self.date = date
        self.ownerID = ownerID
        self.studyPurpose = studyPurpose
        self.memo = memo
    }
}
