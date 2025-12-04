import SwiftUI
import SwiftData
import Combine // ✨ 오타 수정됨 (Combinc -> Combine)

struct DailyTimelineView: View {
    // 뷰모델 연결
    @StateObject private var viewModel = DailyTimelineViewModel()
    
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height > 0 ? geometry.size.height : 600
            let hourHeight = totalHeight / CGFloat(viewModel.endHour - viewModel.startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드
                drawGrid(totalWidth: totalWidth, hourHeight: hourHeight)
                
                // 2. 기존 일정
                let layoutMap = viewModel.calculateLayout(for: schedules)
                ForEach(schedules) { item in
                    drawScheduleBlock(item: item, layoutMap: layoutMap, totalWidth: totalWidth, hourHeight: hourHeight)
                        .onTapGesture { onItemTap?(item) }
                }
                
                // 3. 임시 일정 (작성 중)
                if let draft = draftSchedule {
                    let blockWidth = totalWidth - 35
                    let centerY = viewModel.calculateCenterY(for: draft, hourHeight: hourHeight)
                    
                    scheduleBlock(for: draft, color: .orange, hourHeight: hourHeight, width: blockWidth)
                        .position(x: 35 + blockWidth/2, y: centerY)
                        .opacity(0.85)
                        .zIndex(100)
                }
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Subviews
    private func drawGrid(totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.startHour..<viewModel.endHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    let showLabel = hour % 2 == 0
                    Text(showLabel ? "\(hour)" : "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .frame(width: 25, alignment: .trailing)
                        .padding(.trailing, 5)
                        .offset(y: -6)
                    
                    VStack {
                        Divider()
                            .background(hour % 6 == 0 ? Color.gray.opacity(0.5) : Color.gray.opacity(0.2))
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }
    
    private func drawScheduleBlock(item: ScheduleItem, layoutMap: [PersistentIdentifier: (Int, Int)], totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        let color = SubjectName.color(for: item.title)
        let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
        
        let blockWidth = (totalWidth - 35) / CGFloat(totalCols)
        let xOffset = 35 + (blockWidth * CGFloat(index))
        let centerY = viewModel.calculateCenterY(for: item, hourHeight: hourHeight)
        
        return scheduleBlock(for: item, color: color, hourHeight: hourHeight, width: blockWidth)
            .position(x: xOffset + blockWidth/2, y: centerY)
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let style = viewModel.getBlockStyle(isCompleted: item.isCompleted, isPostponed: item.isPostponed)
        let visualHeight = viewModel.getVisualHeight(for: item, hourHeight: hourHeight)
        
        let startStr = timeFormatter.string(from: item.startDate)
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let endStr = timeFormatter.string(from: end)
        let timeRangeString = "(\(startStr)-\(endStr))"
        
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(style.opacity))
                .saturation(style.saturation)
                .overlay(
                    HStack(spacing: 0) {
                        Rectangle().fill(color).saturation(style.saturation).frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(item.title.isEmpty ? "(새 일정)" : item.title)
                                    .fontWeight(.bold)
                                if width > 60 {
                                    Text(timeRangeString).fontWeight(.regular).opacity(0.8)
                                }
                            }
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundColor(.primary.opacity(0.9))
                        }
                        .padding(.leading, 4).padding(.vertical, 2)
                        Spacer()
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(style.strokeOpacity), lineWidth: 1))
        }
        .padding(.horizontal, 1)
        .frame(width: width, height: visualHeight)
        .contentShape(Rectangle())
    }
}
