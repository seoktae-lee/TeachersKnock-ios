import SwiftUI
import SwiftData
import Combine // ✨ [필수] 이게 있어야 타이머가 작동합니다!

struct StudyTimerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // 어떤 일정으로 공부하는지 받음
    let schedule: ScheduleItem
    
    // 타이머 상태
    @State private var elapsedSeconds: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 종료 알림
    @State private var showStopAlert = false
    
    var subjectColor: Color {
        SubjectName.color(for: schedule.subject)
    }
    
    var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    var body: some View {
        ZStack {
            // 배경색 (은은하게 과목 색상 깔기)
            subjectColor.opacity(0.1).ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 1. 상단 정보
                VStack(spacing: 10) {
                    Text(schedule.subject)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(subjectColor)
                        .cornerRadius(20)
                    
                    Text(schedule.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // 2. 타이머 (메인)
                Text(timeString)
                    .font(.system(size: 70, weight: .thin, design: .monospaced))
                    .foregroundColor(isRunning ? .primary : .gray)
                    .onReceive(timer) { _ in
                        if isRunning {
                            elapsedSeconds += 1
                        }
                    }
                
                Spacer()
                
                // 3. 컨트롤 버튼
                HStack(spacing: 40) {
                    // 종료 버튼
                    Button(action: {
                        isRunning = false
                        showStopAlert = true
                    }) {
                        VStack {
                            Image(systemName: "stop.fill")
                                .font(.title)
                            Text("종료")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                    }
                    
                    // 재생/일시정지 버튼
                    Button(action: {
                        isRunning.toggle()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 100)
                            .background(subjectColor)
                            .clipShape(Circle())
                            .shadow(color: subjectColor.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // 화면 켜지면 바로 시작
            isRunning = true
        }
        .alert("공부를 종료할까요?", isPresented: $showStopAlert) {
            Button("취소", role: .cancel) { isRunning = true } // 다시 시작
            Button("종료 및 저장", role: .destructive) {
                saveRecord()
            }
        } message: {
            Text("지금까지 공부한 시간(\(timeString))이 기록됩니다.")
        }
    }
    
    // 기록 저장 로직
    func saveRecord() {
        guard elapsedSeconds > 0 else {
            dismiss()
            return
        }
        
        // 1. StudyRecord 생성
        let newRecord = StudyRecord(
            durationSeconds: elapsedSeconds,
            areaName: schedule.subject,
            date: Date(),
            ownerID: schedule.ownerID,
            studyPurpose: schedule.title
        )
        
        // 2. 저장 (로컬 + 서버)
        modelContext.insert(newRecord)
        FirestoreSyncManager.shared.saveRecord(newRecord)
        
        dismiss()
    }
}
