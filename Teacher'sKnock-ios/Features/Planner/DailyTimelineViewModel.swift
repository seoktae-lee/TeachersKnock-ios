import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyTimelineViewModel: ObservableObject {
    
    let startHour = 0
    let endHour = 24
    
    // MARK: - Layout Logic
    
    /// 일정이 1초라도 겹치지 않으면(딱 붙어 있어도) 확실하게 분리하여 화면을 꽉 채우게 하는 알고리즘
    func calculateLayout(for items: [ScheduleItem]) -> [PersistentIdentifier: (Int, Int)] {
        // 1. 일정 정렬
        let sorted = items.sorted { $0.startDate < $1.startDate }
        var map: [PersistentIdentifier: (Int, Int)] = [:]
        
        if sorted.isEmpty { return map }
        
        // 2. [핵심] 서로 실제로 겹치는 일정끼리만 덩어리(Cluster)로 묶기
        var clusters: [[ScheduleItem]] = []
        var currentCluster: [ScheduleItem] = [sorted[0]]
        
        // 현재 덩어리 내에서 가장 늦게 끝나는 시간 기록
        var maxEndTimeInCluster = sorted[0].endDate ?? sorted[0].startDate.addingTimeInterval(3600)
        
        for i in 1..<sorted.count {
            let item = sorted[i]
            let itemStart = item.startDate
            let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
            
            // 🚨 핵심 비교 로직 변경 🚨
            // "내 시작 시간"이 "이 그룹에서 가장 늦게 끝나는 시간"보다 '확실히 앞설 때'만 겹친다고 판단.
            // (즉, 앞 일정이 16:30에 끝나고 내가 16:30에 시작하면 '겹침 아님' -> '새 그룹'으로 분리)
            if itemStart < maxEndTimeInCluster {
                // 겹친다면 그룹에 추가
                currentCluster.append(item)
                if itemEnd > maxEndTimeInCluster {
                    maxEndTimeInCluster = itemEnd
                }
            } else {
                // 겹치지 않거나 딱 맞닿아 있다면 -> 이전 그룹 확정 짓고, 새 그룹 시작!
                clusters.append(currentCluster)
                currentCluster = [item]
                maxEndTimeInCluster = itemEnd
            }
        }
        // 마지막 그룹 추가
        clusters.append(currentCluster)
        
        // 3. 각 그룹(Cluster) 내부에서 컬럼 배치 (테트리스)
        for cluster in clusters {
            var columns: [[ScheduleItem]] = []
            
            for item in cluster {
                var placed = false
                let itemStart = item.startDate
                let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
                
                // 들어갈 수 있는 컬럼 찾기
                for (colIndex, col) in columns.enumerated() {
                    var fits = true
                    for existing in col {
                        let existingEnd = existing.endDate ?? existing.startDate.addingTimeInterval(3600)
                        
                        // 컬럼 내에서도 엄격한 겹침 확인
                        // (A시작 < B종료) AND (B시작 < A종료) 일 때만 겹침
                        if itemStart < existingEnd && existing.startDate < itemEnd {
                            fits = false
                            break
                        }
                    }
                    
                    if fits {
                        columns[colIndex].append(item)
                        placed = true
                        break
                    }
                }
                
                // 들어갈 곳 없으면 새 컬럼 생성
                if !placed {
                    columns.append([item])
                }
            }
            
            // 4. 맵핑 정보 저장
            // 이 그룹의 총 컬럼 수(totalCols)를 저장하여 너비 계산에 사용
            // * 중요: 혼자 있는 그룹은 columns.count가 1이 되어 100% 너비가 됨
            let totalColsInCluster = columns.count
            for (colIndex, col) in columns.enumerated() {
                for item in col {
                    map[item.id] = (colIndex, totalColsInCluster)
                }
            }
        }
        
        return map
    }
    
    func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let cal = Calendar.current
        let startHourVal = cal.component(.hour, from: item.startDate)
        let startMin = cal.component(.minute, from: item.startDate)
        
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        
        let topOffset = (CGFloat(startHourVal - self.startHour) * hourHeight) + (CGFloat(startMin) / 60.0 * hourHeight)
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        
        return topOffset + (visualHeight / 2)
    }
    
    // MARK: - Style Helper
    
    func getBlockStyle(isCompleted: Bool, isPostponed: Bool) -> (opacity: Double, saturation: Double, strokeOpacity: Double) {
        let opacity = isPostponed ? 0.15 : (isCompleted ? 0.2 : 0.45)
        let saturation = (isCompleted || isPostponed) ? 0.0 : 1.0
        let strokeOpacity = isPostponed ? 0.2 : (isCompleted ? 0.3 : 0.8)
        
        return (opacity, saturation, strokeOpacity)
    }
    
    func getVisualHeight(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        // 블록 간 시각적 구분을 위해 실제 높이에서 1픽셀 정도 여유를 줌 (선택사항)
        let height = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        return height > 2 ? height - 1 : height
    }
}
