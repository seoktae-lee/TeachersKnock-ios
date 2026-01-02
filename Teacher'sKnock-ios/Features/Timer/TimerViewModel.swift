import Foundation
import SwiftUI
import SwiftData
import Combine
import ActivityKit

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
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplayTime()
            }
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
    
    private let kIsRunning = "timer_isRunning"
    private let kStartTime = "timer_startTime"
    private let kAccumulated = "timer_accumulated"
    private let kSubject = "timer_subject"
    private let kPurpose = "timer_purpose" // ✨ [추가] 공부 목적 저장 키
    
    private func saveTimerState() {
        UserDefaults.standard.set(true, forKey: kIsRunning)
        UserDefaults.standard.set(startTime, forKey: kStartTime)
        UserDefaults.standard.set(accumulatedTime, forKey: kAccumulated)
        UserDefaults.standard.set(selectedSubject, forKey: kSubject)
        UserDefaults.standard.set(selectedPurpose.rawValue, forKey: kPurpose) // ✨ [추가] 목적 저장
    }
    
    private func clearTimerState() {
        UserDefaults.standard.set(false, forKey: kIsRunning)
        UserDefaults.standard.removeObject(forKey: kStartTime)
        UserDefaults.standard.set(accumulatedTime, forKey: kAccumulated) // 일시정지 시간은 유지 가능
    }
    
    private func restoreTimerState() {
        let wasRunning = UserDefaults.standard.bool(forKey: kIsRunning)
        let savedSubject = UserDefaults.standard.string(forKey: kSubject)
        let savedPurpose = UserDefaults.standard.string(forKey: kPurpose) // ✨ [추가] 목적 로드
        
        if let subject = savedSubject {
            self.selectedSubject = subject
        }
        
        // ✨ [추가] 목적 복원 로직
        if let purposeStr = savedPurpose,
           let purpose = StudyPurpose.flexibleMatch(purposeStr) {
            self.selectedPurpose = purpose
        }
        
        if wasRunning {
            if let savedStart = UserDefaults.standard.object(forKey: kStartTime) as? Date {
                self.startTime = savedStart
                self.isRunning = true
                self.accumulatedTime = UserDefaults.standard.double(forKey: kAccumulated)
                
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
        UserDefaults.standard.removeObject(forKey: kAccumulated)
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
             if let saved = UserDefaults.standard.string(forKey: kSubject) {
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

