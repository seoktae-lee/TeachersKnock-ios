import SwiftUI
import SwiftData

struct DailyTimelineView: View {
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    
    // 아이템 클릭 시 실행될 클로저
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    private let startHour = 6
    private let endHour = 24
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            // 높이가 0일 경우 대비 안전장치
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
                
                // 2. 일정 블록 그리기
                let layoutMap = calculateLayout(for: schedules)
                
                ForEach(schedules) { item in
                    let subjectColor = SubjectName.color(for: item.title)
                    let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
                    
                    let availableWidth = totalWidth - 35
                    let blockWidth = availableWidth / CGFloat(totalCols)
                    let xOffset = 35 + (blockWidth * CGFloat(index))
                    
                    // ✨ [수정] position 방식으로 변경하여 터치 영역 정확도 100% 보장
                    scheduleBlock(for: item, color: subjectColor, hourHeight: hourHeight, width: blockWidth)
                        .position(
                            x: xOffset + blockWidth / 2, // 중심점 X
                            y: calculateCenterY(for: item, hourHeight: hourHeight) // 중심점 Y
                        )
                        .onTapGesture {
                            onItemTap?(item)
                        }
                }
                
                // 3. 미리보기 (터치 불필요)
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
            // 배경을 투명하게라도 깔아서 터치 씹힘 방지
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    // 블록의 Y축 중심점을 계산하는 함수
    private func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: item.startDate)
        let startMinute = calendar.component(.minute, from: item.startDate)
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        
        let topOffset = (CGFloat(startHour - self.startHour) * hourHeight) + (CGFloat(startMinute) / 60.0 * hourHeight)
        let actualHeight = CGFloat(duration / 3600.0) * hourHeight
        let visualHeight = max(actualHeight, 35)
        
        // position은 중심을 기준으로 하므로, topOffset에서 높이의 절반만큼 더해줘야 함
        return topOffset + (visualHeight / 2)
    }
    
    // 블록 뷰 생성 (Offset 제거됨)
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        let actualHeight = CGFloat(duration / 3600.0) * hourHeight
        let visualHeight = max(actualHeight, 35)
        
        // 시간 범위 밖이면 숨김
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: item.startDate)
        if startHour < self.startHour || startHour >= self.endHour { return AnyView(EmptyView()) }
        
        return AnyView(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.4))
                .overlay(
                    HStack(spacing: 0) {
                        Rectangle().fill(color).frame(width: 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title.isEmpty ? "(새 일정)" : item.title)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .foregroundColor(.primary.opacity(0.9))
                            
                            if visualHeight > 40 {
                                Text("\(item.startDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.vertical, 2)
                        Spacer()
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.8), lineWidth: 1)
                )
                .padding(.horizontal, 1)
                // ✨ 프레임 크기를 여기서 확정
                .frame(width: width, height: visualHeight)
                // ✨ 중요: 터치 영역을 콘텐츠 전체로 확장
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
