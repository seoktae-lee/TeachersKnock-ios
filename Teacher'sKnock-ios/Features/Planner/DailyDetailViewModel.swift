import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyDetailViewModel: ObservableObject {
    private var modelContext: ModelContext?
    let userId: String
    let targetDate: Date
    
    // 뷰에서 감시할 데이터들
    @Published var schedules: [ScheduleItem] = []
    @Published var records: [StudyRecord] = []
    
    // 파이차트용 데이터 구조체
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        
        // ✨ [수정 완료] allCases 대신 새로운 color(for:) 함수를 바로 호출합니다.
        var color: Color {
            return SubjectName.color(for: subject)
        }
    }
    
    init(userId: String, targetDate: Date) {
        self.userId = userId
        self.targetDate = targetDate
    }
    
    // 뷰가 나타날 때(onAppear) 컨텍스트 주입받고 데이터 로드
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchData()
    }
    
    // 데이터 불러오기 (날짜 걸침 일정 포함)
    func fetchData() {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId &&
                item.startDate < endOfDay &&
                (item.endDate ?? item.startDate) > startOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
            }
        )
        
        do {
            self.schedules = try context.fetch(scheduleDescriptor)
            self.records = try context.fetch(recordDescriptor)
        } catch {
            print("데이터 로드 실패: \(error)")
        }
    }
    
    // 파이차트 데이터 계산
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    var totalActualSeconds: Int { pieData.reduce(0) { $0 + $1.seconds } }
    
    // 날짜 포맷팅
    var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (EEEE)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: targetDate)
    }
    
    // MARK: - 비즈니스 로직 (User Intents)
    
    // 1. 내일로 미루기 (복제)
    func duplicateToTomorrow(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        let oneDaySeconds: TimeInterval = 86400
        let newStart = item.startDate.addingTimeInterval(oneDaySeconds)
        let newEnd = item.endDate?.addingTimeInterval(oneDaySeconds)
        
        let newItem = ScheduleItem(
            title: item.title,
            details: item.details,
            startDate: newStart,
            endDate: newEnd,
            isCompleted: false,
            hasReminder: item.hasReminder,
            ownerID: item.ownerID,
            isPostponed: false
        )
        
        context.insert(newItem)
        FirestoreSyncManager.shared.saveSchedule(newItem)
        
        // 원본 상태 변경
        item.isPostponed = true
        item.isCompleted = false
        
        saveContext()
        fetchData()
    }
    
    // 2. 미루기 취소 (내일 일정 삭제 로직 추가)
    func cancelPostpone(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        // 1. 상태 복구
        item.isPostponed = false
        
        // 2. 내일로 복사되었던 일정 찾아서 삭제
        deletePostponedCopy(of: item, in: context)
        
        saveContext()
        fetchData()
    }
    
    // 내일 날짜에서 '같은 제목'을 가진 일정을 찾아 지우는 헬퍼 함수
    private func deletePostponedCopy(of item: ScheduleItem, in context: ModelContext) {
        let calendar = Calendar.current
        // 내일 날짜 계산
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: item.startDate)!
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)!
        
        let targetTitle = item.title
        let targetOwner = item.ownerID
        
        // 내일 날짜 범위 + 같은 제목 + 같은 사용자 + 미루지 않은 상태(복사본은 false니까)
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { target in
                target.title == targetTitle &&
                target.ownerID == targetOwner &&
                target.startDate >= startOfTomorrow &&
                target.startDate < endOfTomorrow
            }
        )
        
        do {
            let foundItems = try context.fetch(descriptor)
            // 찾은 것 중 하나 삭제 (가장 유력한 후보)
            if let copyToDelete = foundItems.first {
                context.delete(copyToDelete)
                print("🗑️ 미루기 취소: 내일 일정(\(copyToDelete.title))이 삭제되었습니다.")
            }
        } catch {
            print("⚠️ 복제본 삭제 실패: \(error)")
        }
    }
    
    func deleteSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        saveContext()
        fetchData()
    }
    
    func toggleComplete(_ item: ScheduleItem) {
        if !item.isPostponed {
            item.isCompleted.toggle()
            saveContext()
        }
    }
    
    private func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            print("저장 실패: \(error)")
        }
    }
}
