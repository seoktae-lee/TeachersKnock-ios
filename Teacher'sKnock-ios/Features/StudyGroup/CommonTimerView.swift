import SwiftUI
import Combine
import FirebaseAuth

struct CommonTimerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @ObservedObject var studyManager: StudyGroupManager
    let group: StudyGroup
    
    var state: StudyGroup.CommonTimerState? {
        group.commonTimer
    }
    
    @State private var currentTime = Date()
    @State private var remainingTime: TimeInterval = 0
    @State private var isFinished = false // ✨ [New] 중복 저장 방지
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header: Goal & Time Info
            if let state = state {
                VStack(spacing: 8) {
                    Text(state.goal)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("\(state.subject) | \(StudyPurpose(rawValue: state.purpose)?.localizedName ?? state.purpose)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(timeRangeString(start: state.startTime, end: state.endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Analog Clock
                ZStack {
                    AnalogClockView(currentTime: currentTime, startTime: state.startTime, endTime: state.endTime)
                        .frame(width: 300, height: 300)
                    
                    // Central Digital Time (Optional, maybe just remaining time at bottom)
                }
                .padding(.vertical, 20)
                
                // Remaining Time
                VStack(spacing: 5) {
                    Text(timerStatusText)
                        .font(.headline)
                        .foregroundColor(statusColor)
                    
                    Text(formatRemainingTime(remainingTime))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                }
                
                // Active Participants (Simple Count)
                // 추후 실시간 참여자 목록 확장 가능
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("\(group.memberCount)명 참여 중") // 실제로는 접속중인 멤버 수 로직 필요 (PresenceSystem)
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
                
                Spacer()
                
                // Exit Button
                Button(action: {
                    dismiss()
                }) {
                    Text("나가기")
                        .foregroundColor(.red)
                        .padding()
                }
            } else {
                Text("설정된 공통 타이머가 없습니다.")
                    .font(.headline)
                    .foregroundColor(.gray)
                Button("돌아가기") { dismiss() }
            }
        }
        .padding()
        .onReceive(timer) { _ in
            updateTimer()
        }
        .onAppear {
            updateTimer()
        }
    }
    
    var timerStatusText: String {
        guard let state = state else { return "" }
        if currentTime < state.startTime {
            return "시작까지"
        } else if currentTime < state.endTime {
            return "종료까지"
        } else {
            return "종료됨"
        }
    }
    
    var statusColor: Color {
        guard let state = state else { return .gray }
        if currentTime < state.startTime {
            return .orange
        } else if currentTime < state.endTime {
            return .blue
        } else {
            return .red
        }
    }
    
    func updateTimer() {
        currentTime = Date()
        guard let state = state else { return }
        
        if currentTime < state.startTime {
            remainingTime = state.startTime.timeIntervalSince(currentTime)
        } else if currentTime < state.endTime {
            remainingTime = state.endTime.timeIntervalSince(currentTime)
        } else {
            remainingTime = 0
            // 종료 로직 (1회만 실행되도록 플래그 처리)
            if !isFinished {
                isFinished = true
                
                let schedule = GroupSchedule(
                    groupID: group.id,
                    title: "공통 타이머 종료",
                    content: "'\(state.goal)' 목표 달성!",
                    date: Date(),
                    type: .timer,
                    authorID: "system", // 시스템 자동 생성
                    authorName: "스터디 알림"
                )
                GroupScheduleManager().addSchedule(schedule: schedule) { _ in }
            }
        }
    }
    
    func timeRangeString(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        return "\(f.string(from: start)) ~ \(f.string(from: end))"
    }
    
    func formatRemainingTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// Analog Clock Component
struct AnalogClockView: View {
    var currentTime: Date
    var startTime: Date
    var endTime: Date
    
    var body: some View {
        GeometryReader { geo in
            let radius = geo.size.width / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // Clock Face
                Circle()
                    .stroke(Color.primary, lineWidth: 4)
                
                // Markers
                ForEach(0..<12) { i in
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2, height: i % 3 == 0 ? 15 : 7)
                        .offset(y: -radius + 10)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                
                // Planned Session Sector (Pie Slice)
                // 12시간 기준 아날로그 시계에서 startTime ~ endTime 구간 표시
                // *주의: 12시간 넘어가면 복잡해짐. 일단 단순화하여 같은 반나절(AM/PM) 내라고 가정
                 ClockSector(start: startTime, end: endTime)
                     .fill(Color.blue.opacity(0.2))
                     .rotationEffect(.degrees(-90)) // 12시가 0도
                
                // Current Time Hands
                // Hour Hand
                ClockHand(length: radius * 0.5, thickness: 4, color: .primary)
                    .rotationEffect(angle(for: currentTime, component: .hour))
                
                // Minute Hand
                ClockHand(length: radius * 0.7, thickness: 3, color: .primary)
                    .rotationEffect(angle(for: currentTime, component: .minute))
                
                // Second Hand
                ClockHand(length: radius * 0.8, thickness: 1, color: .red)
                    .rotationEffect(angle(for: currentTime, component: .second))
                
                // Center
                Circle()
                    .fill(Color.primary)
                    .frame(width: 10, height: 10)
            }
        }
    }
    
    struct ClockHand: View {
        let length: CGFloat
        let thickness: CGFloat
        let color: Color
        
        var body: some View {
            RoundedRectangle(cornerRadius: thickness / 2)
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(y: -length / 2)
        }
    }
    
    struct ClockSector: Shape {
        var start: Date
        var end: Date
        
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            
            // Convert time to angles (0~360)
            // 12 hours = 360 degrees
            let startAngle = angle(for: start)
            let endAngle = angle(for: end)
            
            p.move(to: center)
            p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            p.closeSubpath()
            return p
        }
        
        func angle(for date: Date) -> Angle {
            let cal = Calendar.current
            let h = Double(cal.component(.hour, from: date) % 12)
            let m = Double(cal.component(.minute, from: date))
            // hour + minute fraction
            let degrees = (h + m / 60.0) * 30.0
            return Angle(degrees: degrees)
        }
    }
    
    func angle(for date: Date, component: Calendar.Component) -> Angle {
        let cal = Calendar.current
        switch component {
        case .hour:
            let h = Double(cal.component(.hour, from: date) % 12)
            let m = Double(cal.component(.minute, from: date))
            return .degrees((h + m / 60.0) * 30.0)
        case .minute:
            let m = Double(cal.component(.minute, from: date))
            let s = Double(cal.component(.second, from: date))
            return .degrees((m + s / 60.0) * 6.0)
        case .second:
            let s = Double(cal.component(.second, from: date))
            return .degrees(s * 6.0)
        default:
            return .zero
        }
    }
}
