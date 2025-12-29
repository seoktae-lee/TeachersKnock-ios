import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyTimelineViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var schedules: [ScheduleItem] = []
    @Published var records: [StudyRecord] = []
    
    // 날짜 및 유저 정보
    let date: Date
    let userId: String
    private var modelContext: ModelContext?
    
    // MARK: - Computed Properties (통계)
    
    // 1. 총 계획 개수
    var totalPlannedCount: Int {
        schedules.count
    }
    
    // 2. 완료 개수 (미룬 일정 제외)
    var completedCount: Int {
        schedules.filter { $0.isCompleted && !$0.isPostponed }.count
    }
    
    // 3. 달성률 (0.0 ~ 1.0)
    var achievementRate: Double {
        totalPlannedCount == 0 ? 0 : Double(completedCount) / Double(totalPlannedCount)
    }
    
    // 4. 총 공부 시간 (초)
    var totalStudySeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 5. 공부 시간 포맷 (예: "3시간 15분")
    var studyTimeFormatted: String {
        let h = totalStudySeconds / 3600
        let m = (totalStudySeconds % 3600) / 60
        if h > 0 {
            return String(format: "%d시간 %d분", h, m)
        } else {
            return String(format: "%d분", m)
        }
    }
    
    // MARK: - Initializer
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
    }
    
    // Context 설정 및 데이터 로드
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchData()
    }
    
    // MARK: - Data Operations
    
    // 데이터 불러오기
    func fetchData() {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 일정 가져오기
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        
        // 공부 기록 가져오기
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
            }
        )
        
        do {
            self.schedules = try context.fetch(scheduleDescriptor)
            self.records = try context.fetch(recordDescriptor)
        } catch {
            print("❌ 데이터 로드 실패: \(error)")
        }
    }
    
    // 완료 상태 토글
    func toggleComplete(_ item: ScheduleItem) {
        item.isCompleted.toggle()
        ScheduleManager.shared.saveSchedule(item) // 서버 동기화
        // View 갱신을 위해 데이터 다시 로드할 필요는 없지만(SwiftData가 처리), 명시적으로 알림
        objectWillChange.send()
    }
    
    // 일정 삭제 (서버 + 로컬)
    func deleteSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        // 1. 서버 삭제
        ScheduleManager.shared.deleteSchedule(itemId: item.id.uuidString, userId: item.ownerID)
        
        // 2. 로컬 삭제
        context.delete(item)
        
        // 3. 리스트 갱신
        if let index = schedules.firstIndex(where: { $0.id == item.id }) {
            schedules.remove(at: index)
        }
    }
    
    // 내일로 미루기
    func postponeSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        // 1. 현재 일정 상태 변경
        item.isPostponed = true
        ScheduleManager.shared.saveSchedule(item)
        
        // 2. 내일 날짜 계산
        let calendar = Calendar.current
        if let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: item.startDate),
           let tomorrowEnd = item.endDate.map({ calendar.date(byAdding: .day, value: 1, to: $0)! }) {
            
            // 3. 새 일정 생성
            let newItem = ScheduleItem(
                title: item.title,
                details: item.details,
                startDate: tomorrowStart,
                endDate: tomorrowEnd,
                subject: item.subject,
                isCompleted: false, // 미룬 건 다시 해야 함
                hasReminder: item.hasReminder,
                ownerID: item.ownerID,
                isPostponed: false
            )
            
            context.insert(newItem)
            ScheduleManager.shared.saveSchedule(newItem) // 새 일정도 서버 저장
        }
        
        objectWillChange.send()
    }
    
    // 미루기 취소
    func cancelPostpone(_ item: ScheduleItem) {
        item.isPostponed = false
        ScheduleManager.shared.saveSchedule(item)
        objectWillChange.send()
    }
}
