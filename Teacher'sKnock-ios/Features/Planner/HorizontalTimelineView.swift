import SwiftUI
import SwiftData

struct HorizontalTimelineView: View {
    let date: Date
    let userId: String
    @Query private var schedules: [ScheduleItem]
    
    // 시간 설정 (06:00 ~ 02:00 익일) -> 총 20시간
    private let startHour = 6
    private let totalHours = 20
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        
        // 해당 날짜의 스케줄 쿼리
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            // 시간당 너비
            let hourWidth = totalWidth / CGFloat(totalHours)
            
            ZStack(alignment: .leading) {
                // 1. 배경 트랙 (그리드)
                HStack(spacing: 0) {
                    ForEach(0..<totalHours, id: \.self) { offset in
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill((offset + startHour) % 6 == 0 ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1))
                                .frame(width: 1)
                            
                            // 시간 라벨 (3시간 간격)
                            if (offset + startHour) % 3 == 0 {
                                Text("\(formatHour(offset + startHour))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(width: 30) // 라벨 공간
                                    .offset(x: 15) // 중앙 정렬 보정
                            }
                        }
                        .frame(width: hourWidth, alignment: .leading)
                    }
                }
                
                // 2. 스케줄 블록
                ForEach(schedules) { item in
                    let (xOffset, width) = calculatePosition(item: item, totalWidth: totalWidth)
                    
                    if width > 0 {
                        Rectangle()
                            .fill(Color.blue.opacity(0.5)) // TODO: 과목 컬러 연동
                            .frame(width: max(width, 2), height: 30) // 최소 너비 보장 & 높이 지정
                            .cornerRadius(4)
                            .offset(x: xOffset)
                            .overlay(
                                Text(item.title)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 2)
                                    .frame(width: max(width, 2), alignment: .leading)
                                    .offset(x: xOffset)
                            )
                    }
                }
                
                // 3. 현재 시간 표시선 (오늘일 경우)
                if Calendar.current.isDateInToday(date) {
                    let currentX = calculateCurrentTimeOffset(totalWidth: totalWidth)
                    if currentX >= 0 && currentX <= totalWidth {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2)
                            .offset(x: currentX)
                    }
                }
            }
        }
    }
    
    // 시간 포맷 (25 -> 01)
    private func formatHour(_ hour: Int) -> String {
        let h = hour >= 24 ? hour - 24 : hour
        return "\(h)"
    }
    
    // 위치 계산
    private func calculatePosition(item: ScheduleItem, totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        
        let startComp = calendar.dateComponents([.hour, .minute], from: item.startDate)
        let startH = startComp.hour ?? 0
        let startM = startComp.minute ?? 0
        
        // 06시 이전(새벽)은 다음날로 취급하여 24를 더해줌 (단, 00~02시까지만 표시 범위 내)
        // 여기서는 Planner 구조상 '하루' 기준이므로, 새벽 스케줄은 24+h 로 계산되어야 함.
        // 하지만 Date 객체 자체는 실제 날짜를 가지므로, 날짜 비교가 필요함.
        // 간단히: startHour(6)보다 작으면 +24
        
        let adjustedStartH = (startH < startHour) ? startH + 24 : startH
        
        // 범위 밖 체크 (시작이 26시(02시) 넘어가면 표시 안함)
        if adjustedStartH >= startHour + totalHours { return (0, 0) }
        
        // 시작점 (분 단위)
        let startMinutes = (adjustedStartH - startHour) * 60 + startM
        
        // 길이 계산
        let duration = item.endDate?.timeIntervalSince(item.startDate) ?? 3600
        let durationMinutes = Int(duration / 60)
        
        // 좌표 변환
        let totalMinutes = totalHours * 60
        let xOffset = (CGFloat(startMinutes) / CGFloat(totalMinutes)) * totalWidth
        let width = (CGFloat(durationMinutes) / CGFloat(totalMinutes)) * totalWidth
        
        return (xOffset, width)
    }
    
    private func calculateCurrentTimeOffset(totalWidth: CGFloat) -> CGFloat {
        let now = Date()
        let calendar = Calendar.current
        let h = calendar.component(.hour, from: now)
        let m = calendar.component(.minute, from: now)
        
        let adjustedH = (h < startHour) ? h + 24 : h
        let minutes = (adjustedH - startHour) * 60 + m
        
        let totalMinutes = totalHours * 60
        return (CGFloat(minutes) / CGFloat(totalMinutes)) * totalWidth
    }
}

#Preview {
    HorizontalTimelineView(date: Date(), userId: "test")
        .frame(height: 60)
        .padding()
}
