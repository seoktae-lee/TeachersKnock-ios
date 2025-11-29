import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 타이머 상태 관리 변수들
    @State private var timeElapsed: Int = 0 // 경과 시간 (초)
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var selectedSubject = "교육학" // 기본 선택 과목
    
    // 교대생 맞춤 과목 리스트
    let subjects = ["교육학", "전공 A", "전공 B", "교직 논술", "한국사"]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                // 1. 과목 선택
                VStack {
                    Text("지금 공부할 과목")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("과목", selection: $selectedSubject) {
                        ForEach(subjects, id: \.self) { subject in
                            Text(subject).tag(subject)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(brandColor)
                    .padding(.horizontal)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.top, 50)
                
                // 2. 타이머 시간 표시 (00:00:00)
                Text(formatTime(seconds: timeElapsed))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding()
                
                // 3. 컨트롤 버튼 (시작/정지/저장)
                HStack(spacing: 30) {
                    if isRunning {
                        // 정지 버튼
                        Button(action: stopTimer) {
                            VStack {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 60))
                                Text("일시정지")
                            }
                        }
                        .foregroundColor(.orange)
                    } else {
                        // 시작 버튼
                        Button(action: startTimer) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                Text(timeElapsed > 0 ? "계속하기" : "시작")
                            }
                        }
                        .foregroundColor(brandColor)
                    }
                    
                    // 완료/저장 버튼 (시간이 1초라도 있을 때만 표시)
                    if timeElapsed > 0 && !isRunning {
                        Button(action: saveRecord) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                Text("완료 및 저장")
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // 4. 최근 공부 기록 (간단히 보여주기)
                RecentRecordsView()
            }
            .navigationTitle("집중 타이머")
        }
    }
    
    // 타이머 시작 로직
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeElapsed += 1
        }
    }
    
    // 타이머 정지 로직
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    // 기록 저장 및 리셋 로직
    func saveRecord() {
        let newRecord = StudyRecord(
            durationSeconds: timeElapsed,
            areaName: selectedSubject,
            date: Date()
        )
        modelContext.insert(newRecord)
        
        // 초기화
        timeElapsed = 0
        stopTimer()
        print("공부 기록 저장 완료: \(newRecord.areaName) - \(newRecord.durationSeconds)초")
    }
    
    // 초(Int)를 "HH:mm:ss" 문자열로 변환하는 함수
    func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// 간단히 최근 기록을 보여주는 하위 뷰
struct RecentRecordsView: View {
    // 최신순으로 3개만 가져오기
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("최근 학습 기록")
                .font(.headline)
                .padding(.horizontal)
            
            List {
                // 상위 5개만 보여줌
                ForEach(records.prefix(5)) { record in
                    HStack {
                        Text(record.areaName)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: 200) // 리스트 높이 제한
        }
    }
}

#Preview {
    TimerView()
}
