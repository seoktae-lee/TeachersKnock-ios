import Foundation
import SwiftData

// 플래너 및 특화 일정(ScheduleItem) 데이터를 저장하는 모델
@Model
final class ScheduleItem {
    // 1. 일정 이름 (예: 교육 실습 준비, 전공 시험)
    var title: String
    
    // 2. 일정 상세 내용
    var details: String
    
    // 3. 시작 및 종료 날짜
    var startDate: Date
    var endDate: Date? // 종료 시간은 선택 사항일 수 있으므로 Optional

    // 4. 완료 상태 (플래너에서 체크 박스 기능)
    var isCompleted: Bool
    
    // 5. 알림 설정 (푸시 알림 구현 시 활용)
    var hasReminder: Bool
    
    // ✨ 6. 주인 이름표 (누가 만든 일정인지 저장 - 데이터 분리 필수)
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
