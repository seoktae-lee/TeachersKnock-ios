import SwiftUI
import SwiftData // ✨ 이게 빠져서 오류가 났었습니다!

struct DailyTimelineView: View {
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    private let startHour = 6
    private let endHour = 24
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let safeHeight = totalHeight > 0 ? totalHeight : 600
            let hourHeight = safeHeight / CGFloat(endHour - startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(hour % 2 == 0 ? "\(hour)" : "")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(width: 25, alignment: .trailing)
                                .padding(.trailing, 5)
                                .offset(y: -6)
                            VStack { Divider() }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                
                // 2. 일정 블록
                let layoutMap = calculateLayout(for: schedules)
                
                ForEach(schedules) { item in
                    let subjectColor = SubjectName.color(for: item.title)
                    let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
                    
                    let availableWidth = totalWidth - 35
                    let blockWidth = availableWidth / CGFloat(totalCols)
                    let xOffset = 35 + (blockWidth * CGFloat(index))
                    
                    scheduleBlock(for: item, color: subjectColor, hourHeight: hourHeight, width: blockWidth)
                        .position(
                            x: xOffset + blockWidth / 2,
                            y: calculateCenterY(for: item, hourHeight: hourHeight)
                        )
                        .onTapGesture { onItemTap?(item) }
                }
                
                // 3. 미리보기
                if let draft = draftSchedule {
                    let availableWidth = totalWidth - 35
                    scheduleBlock(for: draft, color: Color.orange, hourHeight: hourHeight, width: availableWidth)
                        .position(
                            x: 35 + availableWidth / 2,
                            y: calculateCenterY(for: draft, hourHeight: hourHeight)
                        )
                        .opacity(0.85)
                        .shadow(radius: 4)
                        .zIndex(100)
                }
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    private func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: item.startDate)
        let startMinute = calendar.component(.minute, from: item.startDate)
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        
        let topOffset = (CGFloat(startHour - self.startHour) * hourHeight) + (CGFloat(startMinute) / 60.0 * hourHeight)
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 35)
        
        return topOffset + (visualHeight / 2)
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 35)
        
        let isCompleted = item.isCompleted
        let opacity = isCompleted ? 0.2 : 0.45
        let strokeOpacity = isCompleted ? 0.3 : 0.8
        let saturation = isCompleted ? 0.0 : 1.0
        
        return AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(opacity))
                    .saturation(saturation)
                    .overlay(
                        HStack(spacing: 0) {
                            Rectangle().fill(color).saturation(saturation).frame(width: 3)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.title.isEmpty ? "(새 일정)" : item.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .foregroundColor(.primary.opacity(isCompleted ? 0.5 : 0.9))
                                    .strikethrough(isCompleted)
                                if visualHeight > 40 {
                                    Text("\(item.startDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(isCompleted ? 0.5 : 1.0))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 4).padding(.vertical, 2)
                            Spacer()
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(strokeOpacity), lineWidth: 1).saturation(saturation))
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2).foregroundColor(color)
                        .background(Circle().fill(.white).padding(2))
                        .shadow(radius: 1)
                }
            }
            .padding(.horizontal, 1)
            .frame(width: width, height: visualHeight)
            .contentShape(Rectangle())
        )
    }
    
    private func calculateLayout(for items: [ScheduleItem]) -> [PersistentIdentifier: (Int, Int)] {
        let sortedItems = items.sorted { $0.startDate < $1.startDate }
        var layoutMap: [PersistentIdentifier: (Int, Int)] = [:]
        var columns: [[ScheduleItem]] = []
        
        for item in sortedItems {
            var placed = false
            for (colIndex, column) in columns.enumerated() {
                if let lastItem = column.last {
                    let lastEnd = lastItem.endDate ?? lastItem.startDate.addingTimeInterval(3600)
                    if item.startDate >= lastEnd {
                        columns[colIndex].append(item)
                        placed = true
                        break
                    }
                }
            }
            if !placed { columns.append([item]) }
        }
        for (colIndex, column) in columns.enumerated() {
            for item in column { layoutMap[item.id] = (colIndex, columns.count) }
        }
        return layoutMap
    }
}
