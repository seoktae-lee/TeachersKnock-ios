import Foundation
import SwiftUI
import SwiftData
import Combine

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
    
    // MARK: - 타이머 제어
    
    func startTimer() {
        guard !isRunning else { return }
        
        startTime = Date()
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplayTime()
            }
        }
    }
    
    func stopTimer() {
        guard isRunning else { return }
        
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        displayTime = Int(accumulatedTime)
        startTime = nil
        isRunning = false
        
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
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
    
    // MARK: - 데이터 저장
    
    func saveRecord(context: ModelContext, ownerID: String, primaryGoal: Goal?) {
            stopTimer()
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
            resetTimer()
        }
    
    private func resetTimer() {
        accumulatedTime = 0
        displayTime = 0
        linkedScheduleTitle = nil
        // 타이머 리셋 시 목적이나 과목을 초기화할지 여부는 선택 사항 (현재는 유지)
    }
    
    // MARK: - 유틸리티 및 연동 로직
    
    // ✨ [수정된 부분] 공부 목적을 포함하여 일정을 적용합니다.
    func applySchedule(_ item: ScheduleItem) {
        // 1. 과목 연동
        self.selectedSubject = item.subject
        
        // 2. 제목 연동 (메모)
        self.linkedScheduleTitle = item.title
        
        // 3. 공부 목적 연동 (이 부분이 누락되어 있었습니다!)
        // ScheduleItem에 저장된 문자열(rawValue)을 StudyPurpose 타입으로 변환하여 적용
        if let purpose = StudyPurpose(rawValue: item.studyPurpose) {
            self.selectedPurpose = purpose
            print("🔄 타이머 목적 변경됨: \(purpose.localizedName)")
        } else {
            // 값이 없거나 매칭되지 않을 경우 기본값 사용
            self.selectedPurpose = .lectureWatching
            print("⚠️ 공부 목적 연동 실패 (기본값 적용)")
        }
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func setupInitialSubject(favorites: [StudySubject]) {
        if linkedScheduleTitle == nil {
            if let first = favorites.first,
               !favorites.contains(where: { $0.name == selectedSubject }) {
                selectedSubject = first.name
            }
        }
    }
}
