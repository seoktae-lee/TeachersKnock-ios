import Foundation
import SwiftData
import SwiftUI
import Combine

// ✨ 루틴 데이터 구조체
struct RoutineItem: Identifiable {
    let id = UUID()
    let label: String     // 버튼에 표시될 이름
    let title: String     // 실제 일정 제목
    let category: String  // 카테고리 (생활/공부)
    let minutes: Int      // 소요 시간
    let icon: String      // 아이콘
    let isStudy: Bool     // 공부 여부
}

class AddScheduleViewModel: ObservableObject {
    private var modelContext: ModelContext?
    let userId: String
    
    // ✨ [NEW] 자주 쓰는 루틴 목록 (수험생 맞춤)
    let routines: [RoutineItem] = [
        RoutineItem(label: "점심", title: "점심 식사", category: "식사", minutes: 60, icon: "fork.knife", isStudy: false),
        RoutineItem(label: "저녁", title: "저녁 식사", category: "식사", minutes: 60, icon: "moon.stars.fill", isStudy: false),
        RoutineItem(label: "헬스", title: "체력 단련", category: "운동", minutes: 60, icon: "figure.run", isStudy: false),
        RoutineItem(label: "낮잠", title: "파워 낮잠", category: "휴식", minutes: 30, icon: "bed.double.fill", isStudy: false),
        RoutineItem(label: "단어", title: "영단어 암기", category: "영어", minutes: 30, icon: "character.book.closed.fill", isStudy: true)
    ]
    
    // 생활/휴식 카테고리
    let lifeCategories = ["식사", "운동", "휴식", "이동", "약속", "기타"]
    
    // 입력 데이터
    @Published var title: String = ""
    @Published var selectedSubject: String = "교육학"
    @Published var isStudySubject: Bool = true
    
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var hasReminder: Bool = false
    
    @Published var existingSchedules: [ScheduleItem] = []
    
    // 시간 문자열 (예: 1시간 30분)
    var durationString: String {
        let diff = endDate.timeIntervalSince(startDate)
        let minutes = Int(diff / 60)
        if minutes < 60 { return "\(minutes)분" }
        else {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
    }
    
    var draftSchedule: ScheduleItem {
        ScheduleItem(
            title: title.isEmpty ? selectedSubject : title,
            details: "",
            startDate: startDate,
            endDate: endDate,
            subject: selectedSubject,
            isCompleted: false,
            hasReminder: hasReminder,
            ownerID: userId,
            isPostponed: false
        )
    }
    
    var overlappingScheduleTitle: String? {
        let activeSchedules = existingSchedules.filter { !$0.isPostponed }
        for item in activeSchedules {
            let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
            if startDate < itemEnd && endDate > item.startDate {
                return item.title
            }
        }
        return nil
    }
    
    init(userId: String, selectedDate: Date = Date()) {
        self.userId = userId
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        
        // 기본값: 현재 시간 or 오전 9시
        if calendar.isDateInToday(selectedDate) {
            let now = Date()
            let nowComps = calendar.dateComponents([.hour, .minute], from: now)
            components.hour = nowComps.hour
            components.minute = nowComps.minute
        } else {
            components.hour = 9
            components.minute = 0
        }
        
        // 15분/45분 기준 반올림 (30분 단위 정렬)
        let minute = components.minute ?? 0
        if minute < 15 { components.minute = 0 }
        else if minute < 45 { components.minute = 30 }
        else {
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
        }
        
        let start = calendar.date(from: components) ?? selectedDate
        self.startDate = start
        self.endDate = start.addingTimeInterval(3600)
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchExistingSchedules()
    }
    
    func fetchExistingSchedules() {
        guard let context = modelContext else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
            }
        )
        do { self.existingSchedules = try context.fetch(descriptor) }
        catch { print("기존 일정 로드 실패: \(error)") }
    }
    
    // ✨ [핵심 기능 1] 스마트 이어달리기
    // 오늘 등록된 일정 중 가장 늦게 끝나는 시간 뒤에 자동으로 붙임
    func autoSetStartTimeToLastSchedule() {
        let activeSchedules = existingSchedules.filter { !$0.isPostponed }
        
        // 종료 시간이 가장 늦은 일정 찾기
        if let lastSchedule = activeSchedules.max(by: { ($0.endDate ?? $0.startDate) < ($1.endDate ?? $1.startDate) }) {
            let lastEnd = lastSchedule.endDate ?? lastSchedule.startDate.addingTimeInterval(3600)
            
            // 그 시간이 현재 설정된 시간보다 미래라면 (과거로 돌아가지 않음)
            // 그리고 그 시간이 하루를 넘기지 않는다면
            if lastEnd > startDate {
                // 시작 시간을 마지막 일정 끝 시간으로 변경
                self.startDate = lastEnd
                // 종료 시간은 기존 간격(예: 1시간) 유지하며 이동
                let currentDuration = endDate.timeIntervalSince(startDate)
                // 만약 간격이 이상하면 기본 1시간
                let duration = currentDuration > 0 ? currentDuration : 3600
                self.endDate = lastEnd.addingTimeInterval(duration)
            }
        }
    }
    
    // ✨ [핵심 기능 2] 루틴 적용
    func applyRoutine(_ routine: RoutineItem) {
        self.title = routine.title
        self.selectedSubject = routine.category
        self.isStudySubject = routine.isStudy
        
        // 현재 시작 시간 기준으로 종료 시간 자동 계산
        self.endDate = self.startDate.addingTimeInterval(TimeInterval(routine.minutes * 60))
    }
    
    func saveSchedule(dismissAction: () -> Void) {
        guard let context = modelContext else { return }
        if endDate <= startDate { endDate = startDate.addingTimeInterval(1800) }
        
        let newItem = draftSchedule
        if newItem.title.isEmpty { newItem.title = selectedSubject }
        
        context.insert(newItem)
        FirestoreSyncManager.shared.saveSchedule(newItem)
        dismissAction()
    }
    
    func addDuration(_ minutes: Int) {
        let newEndDate = endDate.addingTimeInterval(TimeInterval(minutes * 60))
        if newEndDate > startDate { endDate = newEndDate }
    }
    
    func validateTime() {
        if endDate <= startDate { endDate = startDate.addingTimeInterval(3600) }
    }
    
    func selectCategory(_ name: String, isStudy: Bool) {
        self.selectedSubject = name
        self.isStudySubject = isStudy
    }
}
