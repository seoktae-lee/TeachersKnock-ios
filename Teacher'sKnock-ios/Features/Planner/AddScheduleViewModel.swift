import Foundation
import SwiftData
import SwiftUI
import Combine

class AddScheduleViewModel: ObservableObject {
    private var modelContext: ModelContext?
    let userId: String
    
    @Published var title: String = ""
    @Published var details: String = ""
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var hasReminder: Bool = false
    
    @Published var existingSchedules: [ScheduleItem] = []
    
    // 겹치는 일정 확인 (미뤄진 일정 제외)
    var overlappingScheduleTitle: String? {
        let activeSchedules = existingSchedules.filter { !$0.isPostponed }
        
        for item in activeSchedules {
            let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
            
            // 겹침 판정: (내시작 < 남종료) AND (내종료 > 남시작)
            if startDate < itemEnd && endDate > item.startDate {
                return item.title
            }
        }
        return nil
    }
    
    // 제목 없으면 nil 반환
    var draftSchedule: ScheduleItem? {
        if title.isEmpty { return nil }
        
        return ScheduleItem(
            title: title,
            details: details,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            hasReminder: hasReminder,
            ownerID: userId,
            isPostponed: false
        )
    }
    
    init(userId: String) {
        self.userId = userId
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        components.minute = minute < 30 ? 30 : 0
        if minute >= 30 { components.hour = (components.hour ?? 0) + 1 }
        
        let roundedStart = calendar.date(from: components) ?? now
        let oneHourLater = roundedStart.addingTimeInterval(3600)
        
        self.startDate = roundedStart
        self.endDate = oneHourLater
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchExistingSchedules()
    }
    
    func fetchExistingSchedules() {
        guard let context = modelContext else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        // 넉넉하게 앞뒤로 가져오기 위해 범위 조정 가능하지만, 현재는 하루 단위
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
            }
        )
        
        do {
            self.existingSchedules = try context.fetch(descriptor)
        } catch {
            print("기존 일정 로드 실패: \(error)")
        }
    }
    
    // ✨ [추가됨] 미리보기에서 일정 삭제
    func deleteSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        
        // 삭제 후 목록 갱신
        fetchExistingSchedules()
    }
    
    func saveSchedule(dismissAction: () -> Void) {
        guard let context = modelContext else { return }
        
        let newItem = ScheduleItem(
            title: title,
            details: details,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            hasReminder: hasReminder,
            ownerID: userId,
            isPostponed: false
        )
        
        context.insert(newItem)
        FirestoreSyncManager.shared.saveSchedule(newItem)
        dismissAction()
    }
}
