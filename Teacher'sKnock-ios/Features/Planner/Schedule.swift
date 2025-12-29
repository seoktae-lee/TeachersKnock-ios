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

    init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, isStudySubject: Bool, category: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isStudySubject = isStudySubject
        self.category = category
        self.isDone = isDone
    }
}
