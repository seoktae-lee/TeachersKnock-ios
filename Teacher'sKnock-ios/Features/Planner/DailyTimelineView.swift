import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    // ✨ 1. Context를 가져오기 위한 올바른 선언
    @Environment(\.modelContext) var modelContext
    
    // 뷰모델 선언
    @StateObject private var viewModel: DailyTimelineViewModel
    
    // 이 뷰가 나타내는 날짜와 유저
    let date: Date
    let userId: String
    
    // 생성자
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        _viewModel = StateObject(wrappedValue: DailyTimelineViewModel(date: date, userId: userId))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height > 0 ? geometry.size.height : 600
            // 24시간 기준 (0시~24시)
            let hourHeight = totalHeight / 24
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드 (시간선)
                drawGrid(totalWidth: totalWidth, hourHeight: hourHeight)
                
                // 2. 일정 블록 그리기
                ForEach(viewModel.schedules) { item in
                    scheduleBlock(item: item, hourHeight: hourHeight, totalWidth: totalWidth)
                }
                
                // 3. ✨ [3단계] 현재 시간선 (오늘 날짜일 때만 표시)
                if Calendar.current.isDateInToday(date) {
                    currentTimeLine(totalWidth: totalWidth, hourHeight: hourHeight)
                }
            }
        }
        .onAppear {
            // ✨ 2. 올바르게 선언된 modelContext를 주입
            viewModel.setContext(modelContext)
        }
    }
    
    // MARK: - Helper Views
    
    // 배경 시간선 그리기
    func drawGrid(totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        ForEach(0..<25, id: \.self) { hour in
            VStack(spacing: 0) {
                HStack {
                    Text("\(hour):00")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                }
                Spacer()
            }
            .frame(height: hourHeight)
            .offset(y: CGFloat(hour) * hourHeight)
        }
    }
    
    // 일정 블록 그리기
    func scheduleBlock(item: ScheduleItem, hourHeight: CGFloat, totalWidth: CGFloat) -> some View {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: item.startDate)
        let startMinute = calendar.component(.minute, from: item.startDate)
        
        // 시작 위치 계산
        let topOffset = (CGFloat(startHour) * hourHeight) + (CGFloat(startMinute) * (hourHeight / 60))
        
        // 높이 계산 (소요시간)
        let duration = (item.endDate ?? item.startDate).timeIntervalSince(item.startDate)
        let height = (CGFloat(duration) / 3600) * hourHeight
        
        // 색상 (SubjectName 공통 로직)
        let color = SubjectName.color(for: item.subject)
        
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .lineLimit(1)
            }
            .padding(4)
        }
        .frame(width: totalWidth - 60, height: max(height, 20))
        .offset(x: 50, y: topOffset)
        .onTapGesture {
            // 상세 보기 로직
        }
    }
    
    // ✨ [3단계 구현] 현재 시간선 그리기 함수
    func currentTimeLine(totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        // TimelineView를 사용하면 초 단위로 움직이지만, 여기선 정적 뷰로 Date() 호출
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // 현재 시간의 Y축 위치 계산
        let offset = (CGFloat(hour) * hourHeight) + (CGFloat(minute) * (hourHeight / 60))
        
        return HStack(spacing: 0) {
            // 1. 왼쪽 빨간 점
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: 36) // "00:00" 텍스트 옆
            
            // 2. 가로지르는 빨간 실선
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
                .offset(x: 36)
        }
        .offset(y: offset) // 계산된 시간 위치로 이동
        .shadow(color: .red.opacity(0.3), radius: 2)
    }
}
