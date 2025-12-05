import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class TimerViewModel: ObservableObject {
    
    // MARK: - 설정 상수
    private let minimumStudyTime: Int = 5 // 테스트용 5초 (실사용 시 1초 등으로 변경 가능)
    
    // MARK: - 화면과 공유하는 데이터
    @Published var isRunning: Bool = false
    @Published var displayTime: Int = 0
    @Published var selectedSubject: String = "교육학" // 과목명은 String으로 관리
    @Published var selectedPurpose: StudyPurpose = .lectureWatching
    
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
    
    // MARK: - 데이터 저장
    
    func saveRecord(context: ModelContext, ownerID: String) {
        stopTimer()
        
        let finalTime = displayTime
        
        if finalTime < minimumStudyTime {
            print("⚠️ 학습 시간이 너무 짧아 저장하지 않았습니다.")
            resetTimer()
            return
        }
        
        let newRecord = StudyRecord(
            durationSeconds: finalTime,
            areaName: selectedSubject,
            date: Date(),
            ownerID: ownerID,
            studyPurpose: selectedPurpose.rawValue
        )
        
        context.insert(newRecord)
        
        do {
            try context.save()
            print("✅ 저장 완료: \(finalTime)초")
        } catch {
            print("❌ 저장 실패: \(error)")
        }
        
        FirestoreSyncManager.shared.saveRecord(newRecord)
        resetTimer()
    }
    
    private func resetTimer() {
        accumulatedTime = 0
        displayTime = 0
    }
    
    // MARK: - 유틸리티
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    // ✨ [수정됨] 파라미터 타입을 [StudySubject]로 변경하여 에러 해결!
    func setupInitialSubject(favorites: [StudySubject]) {
        // 즐겨찾기 목록이 비어있지 않고, 현재 선택된 과목이 목록에 없으면
        // 즐겨찾기 첫 번째 과목으로 자동 선택
        if let first = favorites.first,
           !favorites.contains(where: { $0.name == selectedSubject }) {
            selectedSubject = first.name
        }
    }
}
