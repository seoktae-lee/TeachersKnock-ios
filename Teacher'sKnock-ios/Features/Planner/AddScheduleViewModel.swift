import Foundation
import SwiftData
import SwiftUI
import Combine
import FirebaseFirestore

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
        RoutineItem(label: "낮잠", title: "충전 낮잠", category: "휴식", minutes: 30, icon: "bed.double.fill", isStudy: false),
        RoutineItem(label: "단어", title: "영단어 암기", category: "영어", minutes: 30, icon: "character.book.closed.fill", isStudy: true)
    ]
    
    // 생활/휴식 카테고리
    let lifeCategories = SubjectName.lifeSubjects
    
    // MARK: - 입력 데이터
    @Published var title: String = ""
    @Published var selectedSubject: String = "교육학" // 기본값
    @Published var isStudySubject: Bool = true
    
    // ✨ [추가] 공부 목적 선택용 프로퍼티 (기본값: 인강시청)
    @Published var selectedPurpose: StudyPurpose = .lectureWatching {
        didSet {
            // ✨ [수정] 말하기 목적 선택 시 공유 타이머 자동 해제
            if selectedPurpose == .speaking {
                isCommonTimer = false
            }
        }
    }
    
    // ✨ [New] 공통 타이머 설정
    @Published var isCommonTimer: Bool = false
    @Published var targetGroupID: String = "" // 선택된 스터디 그룹
    @Published var myStudyGroups: [StudyGroup] = [] // 선택 가능한 스터디 그룹 목록
    
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var hasReminder: Bool = false
    
    @Published var existingSchedules: [ScheduleItem] = []
    
    // ✨ [수정] 예상 학습 시간 표시 문자열 (음수/0분 처리 보완)
    var durationString: String {
        // ✨ 유효 종료 시간 사용
        let diff = effectiveEndDate.timeIntervalSince(startDate)
        let minutes = Int(diff / 60)
        
        if minutes <= 0 { return "0분" }
        
        if minutes < 60 { return "\(minutes)분" }
        else {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
    }
    
    // ✨ [추가] UI 표시용 날짜 포맷
    var formattedDateString: String {
        let f = DateFormatter()
        f.dateFormat = "M월 d일"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: startDate)
    }
    
    // ✨ [추가] DatePicker 제한용 범위 (해당 날짜의 00:00 ~ 23:59)
    var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? startOfDay
        return startOfDay...endOfDay
    }
    
    // ✨ [추가] 유효 종료 시간 계산 (종료 시간이 시작 시간보다 빠르면 내일로 간주)
    var effectiveEndDate: Date {
        if endDate < startDate {
            return Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }
        return endDate
    }
    
    // MARK: - 임시 객체 생성
    var draftSchedule: ScheduleItem {
        ScheduleItem(
            title: title.isEmpty ? selectedSubject : title,
            details: "",
            startDate: startDate,
            endDate: effectiveEndDate, // ✨ 수정된 종료 시간 사용
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
        // ✨ [수정] 수정 중인 나 자신(editingSchedule)은 제외하고 검사
        let activeSchedules = existingSchedules.filter {
            !$0.isPostponed && $0.id != editingSchedule?.id
        }
        
        for item in activeSchedules {
            let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
            // 겹침 판정: (내 시작 < 남의 끝) AND (내 끝 > 남의 시작)
            if startDate < itemEnd && endDate > item.startDate {
                return item.title
            }
        }
        return nil
    }
    
    // 수정 대상 (nil이면 새 일정 추가)
    var editingSchedule: ScheduleItem?
    
    init(userId: String, selectedDate: Date = Date(), scheduleToEdit: ScheduleItem? = nil) {
        self.userId = userId
        self.editingSchedule = scheduleToEdit
        
        let calendar = Calendar.current
        
        // 1. 수정 모드일 경우: 기존 데이터로 초기화
        if let item = scheduleToEdit {
            self.title = item.title
            self.selectedSubject = item.subject
            self.isStudySubject = SubjectName.isStudySubject(item.subject)
            self.startDate = item.startDate
            self.endDate = item.endDate ?? item.startDate.addingTimeInterval(3600)
            self.hasReminder = item.hasReminder
            
            // 공부 목적 데이터 복원
            if let purpose = StudyPurpose.flexibleMatch(item.studyPurpose) {
                self.selectedPurpose = purpose
            }
            
            // 공통 타이머 복원
            self.isCommonTimer = item.isCommonTimer
            self.targetGroupID = item.targetGroupID ?? ""
            
            return
        }
        
        // 2. 새 일정 추가 모드일 경우
        // 마지막으로 선택했던 과목 불러오기
        if let savedSubject = UserDefaults.standard.string(forKey: "LastSelectedSubject") {
            self.selectedSubject = savedSubject
        }
        
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
        // ✨ [수정] 토글(취소) 기능 구현
        // 이미 해당 루틴이 선택되어 있다면(제목이 같으면) 선택 취소
        if self.title == routine.title {
            print("↺ 루틴 선택 취소 (Undo)")
            
            // 1. 제목 초기화
            self.title = ""
            
            // 2. 시간 초기화 (기본 1시간)
            self.endDate = self.startDate.addingTimeInterval(3600)
            
            // 3. 카테고리 복구 (마지막 선택했던 과목 or 기본값)
            if let savedSubject = UserDefaults.standard.string(forKey: "LastSelectedSubject") {
                self.selectedSubject = savedSubject
                self.isStudySubject = SubjectName.isStudySubject(savedSubject)
            } else {
                self.selectedSubject = "교육학"
                self.isStudySubject = true
            }
            
            // 4. 목적은 기본값 유지 (특별히 복구할 필요성 낮음)
            // self.selectedPurpose = .lectureWatching
            
            return
        }
        
        // 기존 로직: 루틴 적용
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
    func saveSchedule(dismissAction: @escaping () -> Void) {
        guard let context = modelContext else { return }
        
        let finalEndDate = effectiveEndDate
        let finalTitle = title.isEmpty ? selectedSubject : title
        
        UserDefaults.standard.set(selectedSubject, forKey: "LastSelectedSubject")
        
        var shouldWaitForAsync = false
        
        if let existingItem = editingSchedule {
            // [수정 모드]
            
            // 1. 변경 전 상태 캡처
            let wasCommonTimer = existingItem.isCommonTimer
            let oldGroupID = existingItem.targetGroupID
            
            // 2. 로컬 업데이트
            existingItem.title = finalTitle
            existingItem.startDate = startDate
            existingItem.endDate = finalEndDate
            existingItem.subject = selectedSubject
            existingItem.hasReminder = hasReminder
            existingItem.studyPurpose = selectedPurpose.rawValue
            existingItem.isCommonTimer = isCommonTimer
            existingItem.targetGroupID = isCommonTimer ? targetGroupID : nil
            
            ScheduleManager.shared.saveSchedule(existingItem)
            
            // 3. 동기화 로직 분기
            if isCommonTimer {
                NotificationManager.shared.scheduleCommonTimerNotifications(for: existingItem)
                
                // (1) 일반 -> 공통 타이머 (생성)
                // (2) 공통 타이머 -> 공통 타이머 (수정)
                // (3) 그룹 변경 (삭제 후 생성? or 업데이트) -> 여기서는 단순 업데이트로 처리
                
                if let groupID = existingItem.targetGroupID,
                   let group = myStudyGroups.first(where: { $0.id == groupID }),
                   group.leaderID == userId {
                    
                    shouldWaitForAsync = true
                    
                    if !wasCommonTimer || oldGroupID != groupID {
                       // 새로 등록과 동일하게 처리
                       syncCreateGroupSchedule(item: existingItem, groupID: groupID) { dismissAction() }
                    } else {
                        // 단순 업데이트
                        syncUpdateGroupSchedule(item: existingItem, groupID: groupID) { dismissAction() }
                    }
                }
                
            } else {
                NotificationManager.shared.updateNotifications(for: existingItem)
                
                // (4) 공통 타이머 -> 일반 (삭제)
                if wasCommonTimer, let oldID = oldGroupID {
                    shouldWaitForAsync = true
                    // 방장 권한 확인 (메모리 상의 목록 이용) 혹은 그냥 시도(서버 룰) -> 여기선 안전하게 체크
                    // 하지만 oldID 그룹이 myStudyGroups에 없을 수도 있음.
                    // 그냥 삭제 시도
                    syncDeleteGroupSchedule(itemID: existingItem.id.uuidString, title: existingItem.title, groupID: oldID) { dismissAction() }
                }
            }
            
        } else {
            // [추가 모드] 새 객체 생성
            let newItem = ScheduleItem(
                title: finalTitle,
                details: "",
                startDate: startDate,
                endDate: finalEndDate,
                subject: selectedSubject,
                isCompleted: false,
                hasReminder: hasReminder,
                ownerID: userId,
                isPostponed: false,
                studyPurpose: selectedPurpose.rawValue,
                isCommonTimer: isCommonTimer,
                targetGroupID: isCommonTimer ? targetGroupID : nil
            )
            
            context.insert(newItem)
            ScheduleManager.shared.saveSchedule(newItem)
            
            if newItem.isCommonTimer {
                NotificationManager.shared.scheduleCommonTimerNotifications(for: newItem)
                 if let groupID = newItem.targetGroupID,
                   let group = myStudyGroups.first(where: { $0.id == groupID }),
                   group.leaderID == userId {
                     shouldWaitForAsync = true
                     syncCreateGroupSchedule(item: newItem, groupID: groupID) { dismissAction() }
                 }
            } else {
                NotificationManager.shared.updateNotifications(for: newItem)
            }
        }
        
        if !shouldWaitForAsync {
            dismissAction()
        }
    }
    
    // MARK: - Sync Helpers
    
    private func syncCreateGroupSchedule(item: ScheduleItem, groupID: String, completion: @escaping () -> Void) {
        let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
        
        let groupSchedule = GroupSchedule(
            id: item.id.uuidString,
            groupID: groupID,
            title: item.title,
            content: "공통 타이머 일정이 등록되었습니다.",
            date: item.startDate,
            type: .timer,
            authorID: userId,
            authorName: nickname,
            subject: item.subject,
            purpose: item.studyPurpose
        )
        
        GroupScheduleManager().addSchedule(schedule: groupSchedule) { success in
            if success { print("✅ [Sync] 공통 타이머 생성 완료") }
            DispatchQueue.main.async { completion() }
        }
    }
    
    private func syncUpdateGroupSchedule(item: ScheduleItem, groupID: String, completion: @escaping () -> Void) {
        let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
        
        let groupSchedule = GroupSchedule(
            id: item.id.uuidString,
            groupID: groupID,
            title: item.title,
            content: "공통 타이머 일정이 수정되었습니다.",
            date: item.startDate,
            type: .timer,
            authorID: userId,
            authorName: nickname,
            subject: item.subject,
            purpose: item.studyPurpose
        )
        
        GroupScheduleManager().updateSchedule(schedule: groupSchedule) { success in
            if success { print("✅ [Sync] 공통 타이머 수정 완료") }
            DispatchQueue.main.async { completion() }
        }
    }
    
    private func syncDeleteGroupSchedule(itemID: String, title: String, groupID: String, completion: @escaping () -> Void) {
        GroupScheduleManager().deleteSchedule(groupID: groupID, scheduleID: itemID, scheduleTitle: title, isCommonTimer: true) { success in
            if success { print("✅ [Sync] 공통 타이머 해제(삭제) 완료") }
            DispatchQueue.main.async { completion() }
        }
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
    
    // ✨ [New] 스터디 그룹 목록 가져오기
    func fetchMyStudyGroups() {
        Firestore.firestore().collection("study_groups")
            .whereField("members", arrayContains: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.myStudyGroups = documents.compactMap { StudyGroup(document: $0) }
                    
                    // 만약 이미 선택된 그룹이 없는데 목록이 있으면 첫번째 자동 선택
                    if self.targetGroupID.isEmpty, let first = self.myStudyGroups.first {
                        self.targetGroupID = first.id
                    }
                }
            }
    }
}
