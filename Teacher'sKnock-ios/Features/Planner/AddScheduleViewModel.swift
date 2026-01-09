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
    @Published var selectedPurpose: StudyPurpose = .lectureWatching
    
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
        
        // ✨ [수정] 유효 종료 시간 계산 (자정 넘김 처리)
        let finalEndDate = effectiveEndDate
        
        let finalTitle = title.isEmpty ? selectedSubject : title
        
        // 저장할 때, 현재 선택된 과목을 기억해두기
        UserDefaults.standard.set(selectedSubject, forKey: "LastSelectedSubject")
        
        // 비동기 작업 완료를 추적하기 위한 플래그 (그룹 스케줄이 없으면 바로 닫힘)
        var shouldWaitForAsync = false
        
        if let existingItem = editingSchedule {
            // [수정 모드] 기존 객체 업데이트
            existingItem.title = finalTitle
            existingItem.startDate = startDate
            existingItem.endDate = finalEndDate
            existingItem.subject = selectedSubject
            existingItem.hasReminder = hasReminder
            existingItem.studyPurpose = selectedPurpose.rawValue
            existingItem.isCommonTimer = isCommonTimer
            existingItem.targetGroupID = isCommonTimer ? targetGroupID : nil
            
            ScheduleManager.shared.saveSchedule(existingItem)
            
            // ✨ [알림] 공통 타이머 여부에 따라 알림 분기 처리
            if existingItem.isCommonTimer {
                 NotificationManager.shared.scheduleCommonTimerNotifications(for: existingItem)
                
                // ✨ [New] 방장인 경우 공통 타이머 일정 업데이트 동기화
                if let groupID = existingItem.targetGroupID,
                   let group = myStudyGroups.first(where: { $0.id == groupID }),
                   group.leaderID == userId {
                    
                    shouldWaitForAsync = true // 비동기 대기
                    
                    let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
                    let groupSchedule = GroupSchedule(
                        id: existingItem.id.uuidString, // ✨ ID 동기화 (기존 ID 사용)
                        groupID: groupID,
                        title: existingItem.title,
                        content: "공통 타이머 일정이 수정되었습니다.",
                        date: existingItem.startDate,
                        type: .timer,
                        authorID: userId,
                        authorName: nickname,
                        subject: existingItem.subject,
                        purpose: existingItem.studyPurpose
                    )
                    
                    GroupScheduleManager().updateSchedule(schedule: groupSchedule) { _ in
                        print("✅ [방장] 공통 타이머 일정 수정 동기화 완료")
                        DispatchQueue.main.async { dismissAction() }
                    }
                } else {
                     NotificationManager.shared.updateNotifications(for: existingItem)
                }
            } else {
                 NotificationManager.shared.updateNotifications(for: existingItem)
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
            
            // ✨ [알림] 분기 처리
            if newItem.isCommonTimer {
                NotificationManager.shared.scheduleCommonTimerNotifications(for: newItem)
                
                // ✨ [New] 그룹 스케줄 자동 생성 (방장 전용)
                if let groupID = newItem.targetGroupID {
                    // 방장 권한 체크
                    if let group = myStudyGroups.first(where: { $0.id == groupID }), group.leaderID == userId {
                        
                        shouldWaitForAsync = true // 비동기 대기
                        
                        // 1. 공지사항 추가 (NoticeItem)
                        let noticeContent = "공통 타이머 일정이 등록되었습니다: \(newItem.title)"
                        let newNoticeItem = StudyGroup.NoticeItem(
                            id: UUID().uuidString,
                            type: .timer, // ✨ 타이머 타입
                            content: noticeContent,
                            date: Date()
                        )
                        
                        let noticeDict: [String: Any] = [
                            "id": newNoticeItem.id,
                            "type": newNoticeItem.type.rawValue,
                            "content": newNoticeItem.content,
                            "date": Timestamp(date: newNoticeItem.date)
                        ]
                        
                        // 2. 그룹 스케줄 추가 (GroupSchedule)
                        let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
                        let groupSchedule = GroupSchedule(
                            id: newItem.id.uuidString, // ✨ ID 동기화 (새 ID 사용)
                            groupID: groupID,
                            title: newItem.title,
                            content: "공통 타이머 일정이 등록되었습니다.",
                            date: newItem.startDate,
                            type: .timer,
                            authorID: userId,
                            authorName: nickname,
                            subject: newItem.subject,
                            purpose: newItem.studyPurpose
                        )
                        
                        // Firestore Batch 작업 (공지사항 + 스케줄 + Legacy Notice)
                        let batch = Firestore.firestore().batch()
                        let groupRef = Firestore.firestore().collection("study_groups").document(groupID)
                        let scheduleRef = Firestore.firestore().collection("study_groups").document(groupID).collection("schedules").document(groupSchedule.id)
                        
                        // 공지사항 업데이트
                        batch.updateData([
                            "notices": FieldValue.arrayUnion([noticeDict]),
                            "notice": noticeContent, // Legacy support
                            "noticeUpdatedAt": FieldValue.serverTimestamp(),
                            "updatedAt": FieldValue.serverTimestamp()
                        ], forDocument: groupRef)
                        
                        // 스케줄 추가
                        batch.setData(groupSchedule.toDictionary(), forDocument: scheduleRef)
                        
                        batch.commit { error in
                            if let error = error {
                                print("❌ 공통 타이머 등록 실패(공지+스케줄): \(error)")
                            } else {
                                print("✅ [방장] 공통 타이머 등록 완료 (공지+스케줄)")
                            }
                            DispatchQueue.main.async { dismissAction() }
                        }
                    } else {
                        print("⚠️ [멤버] 공통 타이머 일정은 개인용으로만 저장됩니다. (그룹 스케줄 미생성)")
                        // 비동기 작업 아님
                    }
                }
            } else {
                NotificationManager.shared.updateNotifications(for: newItem)
            }
        }
        
        // 비동기 작업이 없으면 바로 닫기
        if !shouldWaitForAsync {
            dismissAction()
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
