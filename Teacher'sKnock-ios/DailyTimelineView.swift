import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    
    // 아이템 클릭 시 실행될 클로저
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    // ✨ [수정 1] 시작 시간을 0시로 변경 (새벽 공부 지원)
    private let startHour = 0
    private let endHour = 24
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let safeHeight = totalHeight > 0 ? totalHeight : 600
            
            // ✨ [수정 2] 시간당 높이 계산 (전체 높이 / 24시간)
            let hourHeight = safeHeight / CGFloat(endHour - startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HStack(spacing: 0) {
                            // ✨ [수정 3] 0시, 6시, 12시, 18시 등 주요 시간대는 조금 더 진하게 표시
                            // 일반 시간은 2시간 간격으로 표시
                            let isMajorTime = hour % 6 == 0
                            let showLabel = hour % 2 == 0 // 2시간 간격 표시
                            
                            Text(showLabel ? "\(hour)" : "")
                                .font(.system(size: isMajorTime ? 11 : 10, weight: isMajorTime ? .bold : .medium))
                                .foregroundColor(isMajorTime ? .black.opacity(0.7) : .gray.opacity(0.6))
                                .frame(width: 25, alignment: .trailing)
                                .padding(.trailing, 5)
                                .offset(y: -6)
                            
                            VStack {
                                // 주요 시간대는 실선, 나머지는 연한 선
                                Divider()
                                    .background(isMajorTime ? Color.gray.opacity(0.3) : Color.clear)
                            }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                
                // 2. 일정 블록 그리기
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
                        .onTapGesture {
                            onItemTap?(item)
                        }
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
        
        // 24시간으로 좁아졌으므로 최소 높이 보장 로직이 더 중요해짐
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30) // 최소 높이 30pt
        
        return topOffset + (visualHeight / 2)
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        let actualHeight = CGFloat(duration / 3600.0) * hourHeight
        
        // ✨ [수정 4] 24시간 뷰에서는 칸이 좁으므로 최소 높이를 살짝 조정
        let visualHeight = max(actualHeight, 30)
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: item.startDate)
        
        // 범위 밖 체크 (이제 0~24니까 거의 걸릴 일 없음)
        if startHour < self.startHour || startHour >= self.endHour { return AnyView(EmptyView()) }
        
        let isCompleted = item.isCompleted
        let isPostponed = item.isPostponed
        
        let opacity = isPostponed ? 0.15 : (isCompleted ? 0.2 : 0.45)
        let saturation = (isCompleted || isPostponed) ? 0.0 : 1.0
        let strokeOpacity = isPostponed ? 0.2 : (isCompleted ? 0.3 : 0.8)
        
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
                                    .font(.system(size: 10, weight: .bold)) // ✨ 폰트 사이즈 11->10 미세 조정
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .strikethrough(isCompleted || isPostponed)
                                    .foregroundColor(.primary.opacity((isCompleted || isPostponed) ? 0.5 : 0.9))
                                
                                // 칸이 충분할 때만 시간 표시
                                if visualHeight > 35 {
                                    Text("\(item.startDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 8)) // ✨ 시간 폰트 9->8
                                        .foregroundColor(.secondary.opacity((isCompleted || isPostponed) ? 0.5 : 1.0))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 4).padding(.vertical, 1)
                            Spacer()
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(strokeOpacity), lineWidth: 1).saturation(saturation))
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3) // 아이콘 크기 약간 축소
                        .foregroundColor(color)
                        .background(Circle().fill(.white).padding(1))
                        .shadow(radius: 1)
                } else if isPostponed {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Circle().fill(.white.opacity(0.8)))
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
            for item in column {
                layoutMap[item.id] = (colIndex, columns.count)
            }
        }
        return layoutMap
    }
}
