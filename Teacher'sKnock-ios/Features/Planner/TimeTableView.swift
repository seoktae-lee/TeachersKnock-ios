import SwiftUI
import SwiftData
import Combine

struct TimeTableView: View {
    @Query private var schedules: [ScheduleItem]
    let date: Date
    let userId: String
    
    // 시간 설정 (오전 6시 ~ 익일 새벽 2시)
    private let startHour = 6
    private let endHour = 26 // 24 + 2
    let hourHeight: CGFloat // 외부에서 주입 가능하도록 변경
    
    init(date: Date, userId: String, hourHeight: CGFloat = 60) {
        self.date = date
        self.userId = userId
        self.hourHeight = hourHeight
        
        // 날짜 필터링
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // 1. 시간 그리드 (배경)
                    VStack(spacing: 0) {
                        ForEach(startHour...endHour, id: \.self) { hour in
                            HStack(alignment: .top) {
                                Text(formatHour(hour))
                                    .font(.caption2)
                                    .frame(width: 40, alignment: .trailing)
                                    .offset(y: -6) // 텍스트를 선에 맞춤
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }
                    .padding(.top, 20) // 상단 여백
                    
                    // 2. 스케줄 블록 배치
                    // ZStack 내부에서 위치 계산
                    ForEach(schedules) { item in
                        ScheduleBlock(item: item, startHour: startHour, hourHeight: hourHeight)
                            .padding(.leading, 50) // 시간 텍스트 공간 확보
                            .padding(.trailing, 10)
                    }
                    
                    // 3. 현재 시간 표시선 (오늘인 경우만)
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeLine(startHour: startHour, hourHeight: hourHeight)
                            .padding(.leading, 50)
                    }
                }
                .padding(.bottom, 50)
            }
            .onAppear {
                // 초기 스크롤 위치: 현재 시간 or 오전 9시
                // 간단히 오전 8시 정도로 이동
                proxy.scrollTo(8, anchor: .top)
            }
        }
    }
    
    // 25시 -> 1시 표기 변환
    func formatHour(_ hour: Int) -> String {
        let h = hour >= 24 ? hour - 24 : hour
        return String(format: "%02d:00", h)
    }
}

// 개별 스케줄 블록
struct ScheduleBlock: View {
    let item: ScheduleItem
    let startHour: Int
    let hourHeight: CGFloat
    
    @Environment(\.modelContext) var context
    
    var subjectColor: Color { Color.blue } // TODO: 과목 컬러 연동
    
    var body: some View {
        // 위치 및 높이 계산
        let (yOffset, height) = calculatePosition()
        
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Text("\(formatTime(item.startDate)) - \(formatTime(item.endDate ?? item.startDate))")
                .font(.caption2)
                .opacity(0.8)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(height - 2, 20)) // 최소 높이 보장
        .background(subjectColor.opacity(0.2))
        .border(subjectColor.opacity(0.5), width: 1)
        .cornerRadius(4)
        .offset(y: yOffset + 20) // 그리드 상단 padding(20) 고려
        // 클릭 시 상세/수정 메뉴
        .contextMenu {
            // EnhancedScheduleRow와 동일한 메뉴 구성
            Button(action: {
                withAnimation {
                    item.isCompleted.toggle()
                    try? context.save()
                }
            }) {
                Label(item.isCompleted ? "완료 취소" : "완료하기", systemImage: "checkmark")
            }
            
            Divider()
            
            Menu("미루기") {
                Button("1시간 뒤로") { postpone(1) }
                Button("내일 이 시간으로") { postponeToTomorrow() }
            }
            
            Button(role: .destructive, action: { context.delete(item) }) {
                Label("삭제", systemImage: "trash")
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    func calculatePosition() -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        
        // 시작 시간 (분 단위)
        let startComp = calendar.dateComponents([.hour, .minute], from: item.startDate)
        let startH = startComp.hour ?? 0
        let startM = startComp.minute ?? 0
        
        // 종료 시간
        let endComp = calendar.dateComponents([.hour, .minute], from: item.endDate ?? item.startDate.addingTimeInterval(3600))
        var endH = endComp.hour ?? 0
        let endM = endComp.minute ?? 0
        
        // 자정 넘어가는 경우 처리 (24, 25...)
        if endH < startH { endH += 24 }
        let adjustedStartH = (startH < startHour) ? startH + 24 : startH // 단순화: startHour보다 작으면 다음날 새벽으로 간주 (여기선 로직 단순화 필요)
        
        // 기준점(startHour)으로부터의 분 차이
        // 주의: Planner 뷰 구조상 하루 단위라, 새벽 2시까지만 커버. 그 외 시간은 짤릴 수 있음.
        
        let startTotalMinutes = (adjustedStartH - startHour) * 60 + startM
        let yOffset = CGFloat(startTotalMinutes) / 60.0 * hourHeight
        
        // 기간 (분 차이)
        let endTotalMinutes = (endH - startHour) * 60 + endM
        let durationMinutes = endTotalMinutes - startTotalMinutes
        let height = CGFloat(durationMinutes) / 60.0 * hourHeight
        
        return (yOffset, height)
    }
    
    // 미루기 로직
    func postpone(_ hours: Int) {
        item.startDate = item.startDate.addingTimeInterval(TimeInterval(hours * 3600))
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(TimeInterval(hours * 3600))
        }
        try? context.save()
    }
    
    func postponeToTomorrow() {
        item.startDate = item.startDate.addingTimeInterval(86400)
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(86400)
        }
        try? context.save()
    }
}

// 현재 시간 표시선
struct CurrentTimeLine: View {
    let startHour: Int
    let hourHeight: CGFloat
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            HStack {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Rectangle().fill(Color.red).frame(height: 1)
            }
            .offset(y: calculateOffset() + 20) // 그리드 padding
            .onReceive(timer) { input in
                currentTime = input
            }
        }
    }
    
    func calculateOffset() -> CGFloat {
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: currentTime)
        let m = calendar.component(.minute, from: currentTime)
        
        // 6시 이전이면(새벽) 아직 표시 안하거나, 다음날 새벽으로 처리해야 함.
        // 여기선 단순하게 처리
        let adjustedH = (h < startHour) ? h + 24 : h
        
        let minutes = (adjustedH - startHour) * 60 + m
        return CGFloat(minutes) / 60.0 * hourHeight
    }
}
