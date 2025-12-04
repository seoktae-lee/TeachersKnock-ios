import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyTimelineViewModel: ObservableObject {
    
    // 타임라인 설정 상수
    let startHour = 0
    let endHour = 24
    
    // 배치 계산 결과 캐싱 (필요시)
    
    // MARK: - Layout Logic
    
    /// 일정이 겹치지 않도록 컬럼 위치를 계산하는 알고리즘
    func calculateLayout(for items: [ScheduleItem]) -> [PersistentIdentifier: (Int, Int)] {
        let sorted = items.sorted { $0.startDate < $1.startDate }
        var map: [PersistentIdentifier: (Int, Int)] = [:]
        var columns: [[ScheduleItem]] = []
        
        for item in sorted {
            var placed = false
            // 기존 컬럼 중에 들어갈 곳이 있는지 확인
            for (i, col) in columns.enumerated() {
                if let last = col.last {
                    let lastEnd = last.endDate ?? last.startDate.addingTimeInterval(3600)
                    // 현재 일정의 시작시간이 마지막 일정의 종료시간보다 뒤라면 배치 가능
                    if item.startDate >= lastEnd {
                        columns[i].append(item)
                        placed = true
                        break
                    }
                }
            }
            // 들어갈 곳이 없으면 새 컬럼 생성
            if !placed {
                columns.append([item])
            }
        }
        
        // 결과 맵핑 (id -> (현재컬럼인덱스, 총컬럼수))
        for (i, col) in columns.enumerated() {
            for item in col {
                map[item.id] = (i, columns.count)
            }
        }
        return map
    }
    
    /// 블록의 Y축 중심 좌표 계산
    func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let cal = Calendar.current
        let startHourVal = cal.component(.hour, from: item.startDate)
        let startMin = cal.component(.minute, from: item.startDate)
        
        // 종료 시간이 없으면 기본 1시간으로 간주
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        
        let topOffset = (CGFloat(startHourVal - self.startHour) * hourHeight) + (CGFloat(startMin) / 60.0 * hourHeight)
        // 최소 높이 30 보장
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        
        return topOffset + (visualHeight / 2)
    }
    
    // MARK: - Style Helper
    
    /// 일정 상태에 따른 투명도/채도 계산
    func getBlockStyle(isCompleted: Bool, isPostponed: Bool) -> (opacity: Double, saturation: Double, strokeOpacity: Double) {
        let opacity = isPostponed ? 0.15 : (isCompleted ? 0.2 : 0.45)
        let saturation = (isCompleted || isPostponed) ? 0.0 : 1.0
        let strokeOpacity = isPostponed ? 0.2 : (isCompleted ? 0.3 : 0.8)
        
        return (opacity, saturation, strokeOpacity)
    }
    
    /// 시간표 시각적 높이 계산
    func getVisualHeight(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        return max(CGFloat(duration / 3600.0) * hourHeight, 30)
    }
}
