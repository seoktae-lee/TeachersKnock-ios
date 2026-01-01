import WidgetKit
import SwiftUI

// ✨ Main App과 데이터 구조 일치시키기
struct WidgetData: Codable {
    let goalTitle: String
    let dDay: Int
    let characterName: String
    let characterColor: String
    let characterType: String
    let uniqueDays: Int
    let level: Int
}

struct PrimaryGoalEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct PrimaryGoalWidgetProvider: TimelineProvider {
    // ⚠️ Main App의 WidgetDataHelper와 일치해야 함
    private let appGroupId = "group.com.seoktaedev.TeachersKnock-ios"
    private let dataKey = "primaryGoalWidgetData"
    
    func placeholder(in context: Context) -> PrimaryGoalEntry {
        PrimaryGoalEntry(date: Date(), data: sampleData)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrimaryGoalEntry) -> ()) {
        let data = loadData()
        let entry = PrimaryGoalEntry(date: Date(), data: data ?? sampleData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrimaryGoalEntry>) -> ()) {
        let data = loadData()
        let entry = PrimaryGoalEntry(date: Date(), data: data)
        
        // 30분마다 갱신 (D-Day 변경 등 감지)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> WidgetData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let data = userDefaults.data(forKey: dataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
    
    var sampleData: WidgetData {
        WidgetData(
            goalTitle: "초등 임용 합격하기",
            dDay: 100,
            characterName: "티노",
            characterColor: "Blue",
            characterType: "bird",
            uniqueDays: 15,
            level: 3 // Lv.4 (Index 3 -> Lv.4)
        )
    }
}
