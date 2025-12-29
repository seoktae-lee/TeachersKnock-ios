import Foundation
import SwiftData
import SwiftUI
import Combine

// 루틴 데이터 구조체
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
    
    // 자주 쓰는 루틴 목록
    let routines: [RoutineItem] = [
        RoutineItem(label: "점심", title: "점심 식사", category: "식사", minutes: 60, icon: "fork.knife", isStudy: false),
        RoutineItem(label: "저녁", title: "저녁 식사", category: "식사", minutes: 60, icon: "moon.stars.fill", isStudy: false),
        RoutineItem(label: "헬스", title: "체력 단련", category: "운동", minutes: 60, icon: "figure.run", isStudy: false),
        RoutineItem(label: "낮잠", title: "파워 낮잠", category: "휴식", minutes: 30, icon: "bed.double.fill", isStudy: false),
        RoutineItem(label: "단어", title: "영단어 암기", category: "영어", minutes: 30, icon: "character.book.closed.fill", isStudy: true)
    ]
    
    // 생활/휴식 카테고리
    let lifeCategories = ["식사", "운동", "휴식", "이동", "약속", "기타"]
    
    // MARK: - 입력 데이터
    @Published var title: String = ""
    @Published var selectedSubject: String = "교육학" // 기본값
    @Published var isStudySubject: Bool = true
    
    // ✨ [추가] 공부 목적 선택용 프로퍼티 (기본값: 인강시청)
    @Published var selectedPurpose: StudyPurpose = .lectureWatching
    
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var hasReminder: Bool = false
    
    @Published var existingSchedules: [ScheduleItem] = []
    
    // ✨ [수정] 예상 학습 시간 표시 문자열 (음수/0분 처리 보완)
    var durationString: String {
        let diff = endDate.timeIntervalSince(startDate)
        let minutes = Int(diff / 60)
        
        if minutes <= 0 { return "0분" }
        
        if minutes < 60 { return "\(minutes)분" }
        else {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
    }
    
    // MARK: - 임시 객체 생성
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
            isPostponed: false,
            // ✨ [추가] 선택된 공부 목적을 모델에 저장
            studyPurpose: selectedPurpose.rawValue
        )
    }
    
    // 중복 일정 확인 프로퍼티
    var overlappingScheduleTitle: String? {
        let activeSchedules = existingSchedules.filter { !$0.isPostponed }
        for item in activeSchedules {
            let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
            // 겹침 판정: (내 시작 < 남의 끝) AND (내 끝 > 남의 시작)
            if startDate < itemEnd && endDate > item.startDate {
                return item.title
            }
        }
        return nil
    }
    
    init(userId: String, selectedDate: Date = Date()) {
        self.userId = userId
        
        // 마지막으로 선택했던 과목 불러오기
        if let savedSubject = UserDefaults.standard.string(forKey: "LastSelectedSubject") {
            self.selectedSubject = savedSubject
        }
        
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
        
        // 30분 단위 정렬
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
    
    // 스마트 이어달리기 로직
    func autoSetStartTimeToLastSchedule() {
        fetchExistingSchedules()
        
        let activeSchedules = existingSchedules.filter { !$0.isPostponed }
        
        // 가장 늦게 끝나는 일정 뒤에 붙이기
        if let lastSchedule = activeSchedules.max(by: { ($0.endDate ?? $0.startDate) < ($1.endDate ?? $1.startDate) }) {
            let lastEnd = lastSchedule.endDate ?? lastSchedule.startDate.addingTimeInterval(3600)
            
            // 무조건 마지막 일정 뒤로 설정
            self.startDate = lastEnd
            self.endDate = lastEnd.addingTimeInterval(3600)
        }
    }
    
    // 루틴 적용
    func applyRoutine(_ routine: RoutineItem) {
        self.title = routine.title
        self.selectedSubject = routine.category
        self.isStudySubject = routine.isStudy
        self.endDate = self.startDate.addingTimeInterval(TimeInterval(routine.minutes * 60))
        
        // ✨ [추가] 특정 루틴(예: 영단어)인 경우 목적도 자동으로 변경
        if routine.label == "단어" {
            self.selectedPurpose = .conceptMemorization // 개념공부(암기)로 자동 설정
        }
    }
    
    // 카테고리 선택
    func selectCategory(_ name: String, isStudy: Bool) {
        self.selectedSubject = name
        self.isStudySubject = isStudy
    }
    
    // 저장 로직
    func saveSchedule(dismissAction: () -> Void) {
        guard let context = modelContext else { return }
        
        if endDate <= startDate {
            endDate = startDate.addingTimeInterval(1800)
        }
        
        let newItem = draftSchedule
        
        // 과목명 강제 주입
        newItem.subject = selectedSubject
        
        if newItem.title.isEmpty {
            newItem.title = selectedSubject
        }
        
        // 저장할 때, 현재 선택된 과목을 기억해두기
        UserDefaults.standard.set(selectedSubject, forKey: "LastSelectedSubject")
        
        // 1. 로컬 저장
        context.insert(newItem)
        
        // 2. 서버 저장
        ScheduleManager.shared.saveSchedule(newItem)
        
        dismissAction()
    }
    
    func addDuration(_ minutes: Int) {
        let newEndDate = endDate.addingTimeInterval(TimeInterval(minutes * 60))
        if newEndDate > startDate {
            endDate = newEndDate
        }
    }
    
    func validateTime() {
        if endDate <= startDate { endDate = startDate.addingTimeInterval(3600) }
    }
}
