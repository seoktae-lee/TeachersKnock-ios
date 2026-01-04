import Foundation
import SwiftUI
import SwiftData
import Combine
import ActivityKit
import FirebaseAuth

@MainActor
class TimerViewModel: ObservableObject {
    
    // MARK: - 설정 상수
    private let minimumStudyTime: Int = 5
    
    // MARK: - 화면과 공유하는 데이터
    @Published var isRunning: Bool = false
    @Published var displayTime: Int = 0
    @Published var selectedSubject: String = "교육학"
    @Published var selectedPurpose: StudyPurpose = .lectureWatching // 기본값
    @Published var linkedScheduleTitle: String? = nil // 플래너에서 넘어온 제목 (메모용)
    
    // MARK: - 내부 변수
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var timer: Timer?
    
    // ✨ Live Activity
    private var activity: Activity<StudyTimerAttributes>?
    
    // MARK: - 초기화
    init() {
        restoreTimerState()
    }
    
    // MARK: - 타이머 제어
    
    func startTimer() {
        guard !isRunning else { return }
        
        // 1. 이미 시작된 적 없다면 현재 시간 기록
        if startTime == nil {
            startTime = Date()
        } else {
            // 일시정지 후 재시작: startTime을 현재시간 - 누적시간으로 조정하여 연속성 유지 효과
            // (accumulatedTime을 초기화할 필요 없음)
            startTime = Date().addingTimeInterval(-accumulatedTime)
            accumulatedTime = 0 
        }
        
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        // ✨ Shielding(방해 금지) 시작
        ShieldingManager.shared.startShielding()
        
        // 상태 저장
        saveTimerState()
        
        // ✨ Live Activity 시작
        startActivity()
        
        // ✨ [New] 공부 시작 상태 동기화
        if let uid = Auth.auth().currentUser?.uid {
            FirestoreSyncManager.shared.updateUserStudyTime(uid: uid, isStudying: true)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplayTime()
                self?.checkMidnight()
            }
        }
    }
    
    // ✨ [New] 자정 감지 및 리셋 로직
    private func checkMidnight() {
        guard let start = startTime else { return }
        let now = Date()
        
        // 시작 날짜와 현재 날짜가 다르면 (자정이 지난 경우)
        if !Calendar.current.isDate(start, inSameDayAs: now) {
            print("🌙 자정이 지났습니다. 타이머를 리셋하고 어제 기록을 저장합니다.")
            
            // 1. 어제 날짜로 기록 저장 (자정까지의 시간)
            // startTime부터 어제 23:59:59까지의 시간 계산
            let calendar = Calendar.current
            // 오늘의 00:00:00
            let startOfToday = calendar.startOfDay(for: now)
            
            // 어제 공부한 시간 (= 자정 - 시작시간 + 기존 누적시간)
            let durationUntilMidnight = startOfToday.timeIntervalSince(start)
            let totalYesterdaySeconds = Int(durationUntilMidnight + accumulatedTime)
            
            if totalYesterdaySeconds >= minimumStudyTime {
                let yesterdayRecord = StudyRecord(
                    durationSeconds: totalYesterdaySeconds,
                    areaName: selectedSubject,
                    date: start, // 시작 날짜 기준
                    ownerID: Auth.auth().currentUser?.uid ?? "",
                    studyPurpose: selectedPurpose.rawValue,
                    memo: linkedScheduleTitle,
                    goal: nil // 목표 연결은 복구 시점이라 어려울 수 있음
                )
                
                // Firestore 저장
                FirestoreSyncManager.shared.saveRecord(yesterdayRecord)
                
                // 캐릭터 경험치 (어제 분량)
                CharacterManager.shared.addExpToEquippedCharacter()
            }
            
            // 2. 타이머 상태 리셋 (오늘 00:00:00 부터 시작하는 것으로 변경)
            self.startTime = startOfToday // 오늘 0시 0분 0초
            self.accumulatedTime = 0
            self.displayTime = Int(now.timeIntervalSince(startOfToday)) // 0시부터 현재까지 흐른 시간
            
            // 3. Firestore 상태 업데이트 (오늘 날짜로 갱신)
            if let uid = Auth.auth().currentUser?.uid {
                // 기존 currentStudyStartTime은 공부 시작 시간이므로, 
                // 자정이 지나면 "오늘 0시"로 갱신해줘야 다른 유저들에게도 오늘치 공부 시간만 보임
                FirestoreSyncManager.shared.updateUserStudyTime(uid: uid, isStudying: true) // 내부적으로 날짜 체크하여 갱신 로직이 돌겠지만, 명시적으로 리셋 필요할 수 있음
                
                // updateUserStudyTime은 'isStudying'만 건드리거나 단순 업데이트일 수 있음.
                // 여기서는 "자정 리셋"을 위해 명시적으로 currentStudyStartTime을 오늘 0시로 맞춰주는게 좋음.
                // 하지만 updateUserStudyTime 구현상 "isStudying: true" 보내면 start time을 'Now'로 갱신함? 
                // -> Step 25 구현 확인: isStudying=true면 timestamp(date: Date())로 설정함.
                // 즉, 여기서 호출하면 startTime이 '지금(00:00:01)'으로 바뀜. 의도와 부합.
            }
            
            // 값 저장
            saveTimerState()
        }
    }
    
    func stopTimer() {
        guard isRunning else { return }
        
        updateDisplayTime() // 정지 직전 시간 갱신
        
        if let start = startTime {
            accumulatedTime = Date().timeIntervalSince(start)
        }
        
        startTime = nil // 재시작 시 새로운 로직을 위해 nil 처리 (위 startTimer 로직 참조)
        isRunning = false
        
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        
        // ✨ Shielding(방해 금지) 해제
        ShieldingManager.shared.stopShielding()
        
        // 상태 저장 해제 (또는 일시정지 상태 저장)
        clearTimerState()
        
        // ✨ Live Activity 종료
        endActivity()
        
        // ✨ [New] 공부 종료 상태 동기화 (멈춤 상태)
        if let uid = Auth.auth().currentUser?.uid {
            FirestoreSyncManager.shared.updateUserStudyTime(uid: uid, isStudying: false)
        }
    }
    
    private func updateDisplayTime() {
        guard let start = startTime else { return }
        let current = Date().timeIntervalSince(start)
        let total = current + accumulatedTime
        self.displayTime = Int(total)
    }
    
    // ✨ [추가] 뷰에서 접근할 시간 문자열
    var timeString: String {
        formatTime(seconds: displayTime)
    }
    
    // MARK: - Persistence (백그라운드/앱 종료 대응)
    
    // MARK: - Persistence Keys
    private static let kIsRunning = "timer_isRunning"
    private static let kStartTime = "timer_startTime"
    private static let kAccumulated = "timer_accumulated"
    private static let kSubject = "timer_subject"
    private static let kPurpose = "timer_purpose"
    
    // ✨ [추가] 강제 종료 시 저장을 위한 임시 키
    private static let kPendingRecordDuration = "pending_record_duration"
    private static let kPendingRecordSubject = "pending_record_subject"
    private static let kPendingRecordPurpose = "pending_record_purpose"
    private static let kPendingRecordDate = "pending_record_date"
    private static let kPendingRecordMemo = "pending_record_memo"


    
    private func saveTimerState() {
        UserDefaults.standard.set(true, forKey: Self.kIsRunning)
        UserDefaults.standard.set(startTime, forKey: Self.kStartTime)
        UserDefaults.standard.set(accumulatedTime, forKey: Self.kAccumulated)
        UserDefaults.standard.set(selectedSubject, forKey: Self.kSubject)
        UserDefaults.standard.set(selectedPurpose.rawValue, forKey: Self.kPurpose)
    }
    
    private func clearTimerState() {
        UserDefaults.standard.set(false, forKey: Self.kIsRunning)
        UserDefaults.standard.removeObject(forKey: Self.kStartTime)
        UserDefaults.standard.set(accumulatedTime, forKey: Self.kAccumulated) // 일시정지 시간은 유지 가능
    }
    
    private func restoreTimerState() {
        let wasRunning = UserDefaults.standard.bool(forKey: Self.kIsRunning)
        let savedSubject = UserDefaults.standard.string(forKey: Self.kSubject)
        let savedPurpose = UserDefaults.standard.string(forKey: Self.kPurpose)
        
        if let subject = savedSubject {
            self.selectedSubject = subject
        }
        
        // ✨ [추가] 목적 복원 로직
        if let purposeStr = savedPurpose,
           let purpose = StudyPurpose.flexibleMatch(purposeStr) {
            self.selectedPurpose = purpose
        }
        
        if wasRunning {
            // ✨ [수정] 강제 종료 후 재실행이라면, wasRunning이 true여도 startTime이 없을 수 있음 (handleAppTermination에서 지웠으므로)
            // 하지만 handleAppTermination이 호출되지 않았다면(크래시 등), 여기서 복구 로직이 동작.
            // 만약 handleAppTermination이 정상 동작했다면 kIsRunning은 false였을 것임.
            // 즉, 여기 들어왔다는 건 "비정상 종료" 또는 "아직 처리 안 된 상태"임.
            
            if let savedStart = UserDefaults.standard.object(forKey: Self.kStartTime) as? Date {
                self.startTime = savedStart
                self.isRunning = true
                self.accumulatedTime = UserDefaults.standard.double(forKey: Self.kAccumulated)
                
                // 타이머 재가동
                ShieldingManager.shared.startShielding()
                UIApplication.shared.isIdleTimerDisabled = true
                
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.updateDisplayTime()
                    }
                }
                // 라이브 액티비티 복구
                if let existingActivity = Activity<StudyTimerAttributes>.activities.first {
                    self.activity = existingActivity
                    print("🔄 RESTORED LIVE ACTIVITY: \(existingActivity.id)")
                }
            }
        }
    }
    
    // MARK: - 데이터 저장
    
    func saveRecord(context: ModelContext, ownerID: String, primaryGoal: Goal?) {
            stopTimer()
            // 저장 로직 실행 시 accumulatedTime/displayTime 초기화
            let finalTime = displayTime
            guard finalTime >= minimumStudyTime else {
                resetTimer()
                return
            }
            
            let newRecord = StudyRecord(
                durationSeconds: finalTime,
                areaName: selectedSubject,
                date: Date(),
                ownerID: ownerID,
                studyPurpose: selectedPurpose.rawValue,
                memo: linkedScheduleTitle,
                goal: primaryGoal // ✨ [핵심] 현재 활성화된 목표를 기록에 연결
            )
            
            context.insert(newRecord)
            FirestoreSyncManager.shared.saveRecord(newRecord)
            
            // ✨ [추가] 캐릭터 경험치 증가 (오늘 첫 공부일 때만 적용됨)
            CharacterManager.shared.addExpToEquippedCharacter()
            
            resetTimer()
        }
    
    private func resetTimer() {
        accumulatedTime = 0
        displayTime = 0
        linkedScheduleTitle = nil
        clearTimerState()
        UserDefaults.standard.removeObject(forKey: Self.kAccumulated)
    }
    
    // ✨ [New] 강제 종료되어 저장되지 못한 기록이 있는지 확인하고 저장
    func checkAndSavePendingRecord(context: ModelContext, ownerID: String) {
        let duration = UserDefaults.standard.integer(forKey: Self.kPendingRecordDuration)
        
        if duration > 0 {
            print("💾 [TimerViewModel] 강제 종료된 세션 복구 중... (\(duration)초)")
            
            let subject = UserDefaults.standard.string(forKey: Self.kPendingRecordSubject) ?? "교육학"
            let purposeRaw = UserDefaults.standard.string(forKey: Self.kPendingRecordPurpose) ?? StudyPurpose.lectureWatching.rawValue
            let date = UserDefaults.standard.object(forKey: Self.kPendingRecordDate) as? Date ?? Date()
            let memo = UserDefaults.standard.string(forKey: Self.kPendingRecordMemo)
            
            // 기록 생성
            let newRecord = StudyRecord(
                durationSeconds: duration,
                areaName: subject,
                date: date,
                ownerID: ownerID,
                studyPurpose: purposeRaw,
                memo: memo,
                goal: nil // 목표 연결은 복구 시점이라 어려울 수 있음 (가장 가까운 목표를 찾거나 nil)
            )
            
            context.insert(newRecord)
            FirestoreSyncManager.shared.saveRecord(newRecord)
            CharacterManager.shared.addExpToEquippedCharacter()
            
            // 정리
            UserDefaults.standard.removeObject(forKey: Self.kPendingRecordDuration)
            UserDefaults.standard.removeObject(forKey: Self.kPendingRecordSubject)
            UserDefaults.standard.removeObject(forKey: Self.kPendingRecordPurpose)
            UserDefaults.standard.removeObject(forKey: Self.kPendingRecordDate)
            UserDefaults.standard.removeObject(forKey: Self.kPendingRecordMemo)
            
            print("✅ [TimerViewModel] 강제 종료 세션 복구 완료")
        }
    }
    
    // MARK: - 유틸리티 및 연동 로직
    
    // ✨ [수정된 부분] 공부 목적을 포함하여 일정을 적용합니다.
    func applySchedule(_ item: ScheduleItem) {
        // 1. 과목 연동
        self.selectedSubject = item.subject
        
        // 2. 제목 연동 (메모)
        self.linkedScheduleTitle = item.title
        
        // 3. 공부 목적 연동
        // ✨ [수정] 유연한 매칭 시스템 사용 (String -> Enum 변환 강화)
        if let purpose = StudyPurpose.flexibleMatch(item.studyPurpose) {
            self.selectedPurpose = purpose
            print("🔄 타이머 목적 변경됨: \(purpose.localizedName)")
        } else {
            // 값이 없거나 매칭되지 않을 경우 기본값 사용
            self.selectedPurpose = .lectureWatching
            print("⚠️ 공부 목적 연동 실패 (기본값 적용): \(item.studyPurpose)")
        }
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    

    func setupInitialSubject(favorites: [StudySubject]) {
        if linkedScheduleTitle == nil && selectedSubject == "교육학" { // 기본값 상태일 때만
             if let saved = UserDefaults.standard.string(forKey: Self.kSubject) {
                 selectedSubject = saved
             } else if let first = favorites.first {
                 selectedSubject = first.name
             }
        }
    }
    
    // MARK: - Live Activity Management
    
    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // 이미 실행 중인 활동이 있다면 종료
        if let currentActivity = activity {
            Task { await currentActivity.end(dismissalPolicy: .immediate) }
        }
        
        let attributes = StudyTimerAttributes(
            subject: selectedSubject,
            purpose: selectedPurpose.localizedName
        )
        
        // 타이머 시작 시간 계산 (현재 시간 - 누적 시간)
        // Live Activity의 타이머는 절대 시간을 기준으로 하므로,
        // 일시정지 후 재시작 시에도 마치 처음부터 시작한 것처럼 보이게 하거나,
        // 아니면 단순히 현재 startTime을 넘겨주면 됨.
        // 여기서는 TimerViewModel의 startTime 로직을 따름.
        let activityStartTime = startTime ?? Date()
        
        let contentState = StudyTimerAttributes.ContentState(startTime: activityStartTime)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            self.activity = activity
            print("LIVE ACTIVITY STARTED: \(activity.id)")
        } catch {
            print("ERROR STARTING LIVE ACTIVITY: \(error.localizedDescription)")
        }
    }
    
    private func endActivity() {
        // 현재 참조 중인 액티비티 외에도, 앱이 종료되어 참조를 잃은 좀비 액티비티가 있을 수 있으므로
        // 해당 타입의 모든 액티비티를 찾아서 종료합니다.
        Task {
            for activity in Activity<StudyTimerAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
                print("LIVE ACTIVITY ENDED: \(activity.id)")
            }
            self.activity = nil
        }
    }
    
    // ✨ 앱 종료(강제 종료) 시 호출되는 정적 메서드
    static func handleAppTermination() {
        // 1. 실행 중인지 확인
        let wasRunning = UserDefaults.standard.bool(forKey: Self.kIsRunning)
        
        if wasRunning {
            print("🛑 [TimerViewModel] 앱 종료 감지: 타이머 중지 처리 시작")
            
            // 2. 현재까지의 시간 계산하여 누적 시간에 저장
            if let startTime = UserDefaults.standard.object(forKey: Self.kStartTime) as? Date {
                let currentAccumulated = UserDefaults.standard.double(forKey: Self.kAccumulated)
                let elapsed = Date().timeIntervalSince(startTime)
                let finalAccumulated = currentAccumulated + elapsed
                
                // 3. 상태 업데이트 및 "Pending Record" 저장
                // 실행 중단 처리
                UserDefaults.standard.set(false, forKey: Self.kIsRunning)
                UserDefaults.standard.removeObject(forKey: Self.kStartTime)
                UserDefaults.standard.set(finalAccumulated, forKey: Self.kAccumulated)
                
                // ✨ 저장 데이터 생성 (다음 실행 시 DB 저장용)
                let finalDuration = Int(finalAccumulated)
                if finalDuration >= 5 { // 최소 시간 조건
                    UserDefaults.standard.set(finalDuration, forKey: Self.kPendingRecordDuration)
                    
                    let subject = UserDefaults.standard.string(forKey: Self.kSubject)
                    UserDefaults.standard.set(subject, forKey: Self.kPendingRecordSubject)
                    
                    let purpose = UserDefaults.standard.string(forKey: Self.kPurpose)
                    UserDefaults.standard.set(purpose, forKey: Self.kPendingRecordPurpose)
                    
                    UserDefaults.standard.set(Date(), forKey: Self.kPendingRecordDate)
                    
                    // 제목(메모)은 따로 저장 안 했었으나 필요하면 추가 가능. 일단 패스하거나 kSubject 사용
                }
                
                print("💾 [TimerViewModel] 앱 종료: \(finalDuration)초 저장 예약됨")
            }
            
            // 4. Live Activity 종료 요청 (RunLoop Spinning)
            // Semaphore는 Main Thread를 완전히 멈춰버려 비동기 작업(IPC 등)이 처리를 못하게 막을 수 있습니다.
            // 대신 RunLoop를 돌리며 대기해야 합니다.
            print("🛑 [TimerViewModel] Live Activity 종료 요청 시작 (RunLoop 방식)")
            
            var finished = false
            
            Task(priority: .high) {
                for activity in Activity<StudyTimerAttributes>.activities {
                    await activity.end(dismissalPolicy: .immediate)
                    print("🛑 [TimerViewModel] Live Activity 종료 보냄: \(activity.id)")
                }
                finished = true
            }
            
            // 최대 2.0초 동안 RunLoop를 돌리며 대기
            let timeout = Date().addingTimeInterval(2.0)
            while !finished && Date() < timeout {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
            }
            
            if finished {
                print("✅ [TimerViewModel] Live Activity 종료 요청 성공")
            } else {
                print("⚠️ [TimerViewModel] Live Activity 종료 대기 시간 초과")
            }
        }
    }
}

// ✨ [임시 추가] Xcode 프로젝트에 파일이 추가되지 않아 발생하는 오류를 방지하기 위해 여기에 정의합니다.
// 추후 Service/ShieldingManager.swift 파일이 프로젝트에 추가되면 이 코드는 삭제해주세요.
import FamilyControls
import ManagedSettings

@MainActor
class ShieldingManager: ObservableObject {
    static let shared = ShieldingManager()
    
    // Store for ManagedSettings
    private let store = ManagedSettingsStore()
    
    // Selected apps/categories to shield (block)
    @Published var discouragedSelection = FamilyActivitySelection()
    
    // Authorization status
    @Published var isAuthorized: Bool = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        Task {
            let status = AuthorizationCenter.shared.authorizationStatus
            self.isAuthorized = status == .approved
        }
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.isAuthorized = true
        } catch {
            print("Failed to authorize FamilyControls: \(error)")
            self.isAuthorized = false
        }
    }
    
    /// Starts shielding the selected apps.
    func startShielding() {
        // Clear existing shields first to be safe
        store.clearAllSettings()
        
        let applications = discouragedSelection.applicationTokens
        let categories = discouragedSelection.categoryTokens
        
        if applications.isEmpty && categories.isEmpty {
            print("No apps selected to shield.")
            return
        }
        
        print("Starting shielding for \(applications.count) apps and \(categories.count) categories.")
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(categories, except: Set())
        store.shield.applications = applications
    }
    
    /// Stops shielding all apps.
    func stopShielding() {
        print("Stopping all shielding.")
        store.clearAllSettings()
    }
}

