import Foundation
import SwiftData

// 공부 기록을 저장하는 모델
@Model
final class StudyRecord {
    // 공부한 시간 (초 단위)
    var durationSeconds: Int
    
    // 공부한 과목/영역 이름 (예: 교육학)
    var areaName: String
    
    // 기록 날짜
    var date: Date
    
    init(durationSeconds: Int, areaName: String, date: Date = Date()) {
        self.durationSeconds = durationSeconds
        self.areaName = areaName
        self.date = date
    }
}
