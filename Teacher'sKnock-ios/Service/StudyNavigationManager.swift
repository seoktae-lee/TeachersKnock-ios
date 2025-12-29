import SwiftUI
import Combine

class StudyNavigationManager: ObservableObject {
    // 앱 전역에서 접근 가능한 싱글톤 인스턴스 (선택 사항이나, EnvironmentObject로 주입하므로 필수는 아님)
    static let shared = StudyNavigationManager()
    
    // 0: 홈, 1: 플래너, 2: 타이머, 3: 설정 (MainTabView 순서 기준)
    @Published var tabSelection: Int = 1
    
    // 타이머로 전달할 일정 데이터
    @Published var targetSchedule: ScheduleItem?
    
    // 이 함수를 호출하면 타이머 탭으로 이동하며 데이터를 세팅합니다.
    func triggerStudy(for schedule: ScheduleItem) {
        self.targetSchedule = schedule
        self.tabSelection = 2 // TimerView 탭 인덱스
    }
    
    // 타이머에서 데이터를 소비한 후 초기화할 때 사용
    func clearTarget() {
        self.targetSchedule = nil
    }
}
