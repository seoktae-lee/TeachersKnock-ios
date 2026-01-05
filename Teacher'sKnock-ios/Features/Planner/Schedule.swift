import Foundation
import SwiftData

@Model
class Schedule {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isStudySubject: Bool // true: 공부, false: 생활
    var category: String     // 구체적인 과목명이나 활동명
    var isDone: Bool
    
    // ✨ [New] 공통 타이머 연동
    var isCommonTimer: Bool
    var targetGroupID: String?

    init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isStudySubject: Bool, category: String, isDone: Bool = false, isCommonTimer: Bool = false, targetGroupID: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isStudySubject = isStudySubject
        self.category = category
        self.isDone = isDone
        self.isCommonTimer = isCommonTimer
        self.targetGroupID = targetGroupID
    }
}
