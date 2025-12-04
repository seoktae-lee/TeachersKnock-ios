import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    // 뷰모델을 @StateObject로 소유하여 로직 처리
    @StateObject private var viewModel = DailyTimelineViewModel()
    
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height > 0 ? geometry.size.height : 600
            let hourHeight = totalHeight / CGFloat(viewModel.endHour - viewModel.startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드 (시간 표시)
                drawGrid(totalWidth: totalWidth, hourHeight: hourHeight)
                
                // 2. 일정 블록 배치
                // 뷰모델의 순수 함수 로직을 사용하여 계산
                let layoutMap = viewModel.calculateLayout(for: schedules)
                
                ForEach(schedules) { item in
                    let color = SubjectName.color(for: item.title)
                    let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
                    
                    // 왼쪽 여백 35pt 제외하고 등분
                    let blockWidth = (totalWidth - 35) / CGFloat(totalCols)
                    let xOffset = 35 + (blockWidth * CGFloat(index))
                    let centerY = viewModel.calculateCenterY(for: item, hourHeight: hourHeight)
                    
                    scheduleBlock(for: item, color: color, hourHeight: hourHeight, width: blockWidth)
                        .position(x: xOffset + blockWidth/2, y: centerY)
                        .onTapGesture { onItemTap?(item) }
                }
                
                // 3. 드래그 중인 임시 일정 (Draft)
                if let draft = draftSchedule {
                    let blockWidth = totalWidth - 35
                    let centerY = viewModel.calculateCenterY(for: draft, hourHeight: hourHeight)
                    
                    scheduleBlock(for: draft, color: .orange, hourHeight: hourHeight, width: blockWidth)
                        .position(x: 35 + blockWidth/2, y: centerY)
                        .opacity(0.85)
                        .zIndex(100)
                }
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Subviews
    
    private func drawGrid(totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.startHour..<viewModel.endHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    let isMajor = hour % 6 == 0
                    let showLabel = hour % 2 == 0
                    
                    Text(showLabel ? "\(hour)" : "")
                        .font(.system(size: isMajor ? 11 : 10, weight: isMajor ? .bold : .medium))
                        .foregroundColor(isMajor ? .black.opacity(0.7) : .gray.opacity(0.6))
                        .frame(width: 25, alignment: .trailing)
                        .padding(.trailing, 5)
                        .offset(y: -6)
                    
                    VStack {
                        Divider()
                            .background(isMajor ? Color.gray.opacity(0.3) : .clear)
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let isCompleted = item.isCompleted
        let isPostponed = item.isPostponed
        
        // 스타일 계산 로직을 VM에 위임
        let style = viewModel.getBlockStyle(isCompleted: isCompleted, isPostponed: isPostponed)
        let visualHeight = viewModel.getVisualHeight(for: item, hourHeight: hourHeight)
        
        return ZStack {
            // 배경색
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(style.opacity))
                .saturation(style.saturation)
                .overlay(
                    HStack(spacing: 0) {
                        // 왼쪽 포인트 라인
                        Rectangle()
                            .fill(color)
                            .saturation(style.saturation)
                            .frame(width: 3)
                        
                        // 텍스트 내용
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title.isEmpty ? "(새 일정)" : item.title)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .strikethrough(isCompleted || isPostponed)
                                .foregroundColor(.primary.opacity((isCompleted || isPostponed) ? 0.5 : 0.9))
                            
                            if visualHeight > 35 {
                                Text("\(item.startDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity((isCompleted || isPostponed) ? 0.5 : 1.0))
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.vertical, 1)
                        
                        Spacer()
                    }
                )
                // 테두리
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(style.strokeOpacity), lineWidth: 1)
                        .saturation(style.saturation)
                )
            
            // 상태 아이콘 (체크/미룸)
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3).foregroundColor(color)
                    .background(Circle().fill(.white).padding(1))
                    .shadow(radius: 1)
            } else if isPostponed {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title3).foregroundColor(.gray)
                    .padding(4)
                    .background(Circle().fill(.white.opacity(0.8)))
                    .shadow(radius: 1)
            }
        }
        .padding(.horizontal, 1)
        .frame(width: width, height: visualHeight)
        .contentShape(Rectangle())
    }
}
