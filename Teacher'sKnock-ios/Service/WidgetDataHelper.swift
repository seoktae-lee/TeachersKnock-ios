import Foundation
import WidgetKit
import SwiftUI

/// 위젯에 표시할 데이터를 담는 구조체 (Codable 필수)
struct WidgetData: Codable {
    let goalTitle: String
    let dDay: Int
    let characterName: String
    let characterColor: String
    let characterType: String
    let uniqueDays: Int
    let level: Int
}

class WidgetDataHelper {
    static let shared = WidgetDataHelper()
    
    // ⚠️ 주의: 이 ID는 Xcode의 Signing & Capabilities -> App Groups에 추가한 ID와 일치해야 합니다.
    private let appGroupId = "group.com.seoktaedev.TeachersKnock-ios"
    private let dataKey = "primaryGoalWidgetData"
    
    private init() {}
    
    /// 대표 목표 데이터를 App Group UserDefaults에 저장하고 위젯을 갱신합니다.
    func updatePrimaryGoal(goal: Goal, uniqueDays: Int, level: Int? = nil) {
        let calendar = Calendar.current
        
        // D-Day 계산
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: goal.targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        let dDay = components.day ?? 0
        
        // 레벨 결정: 구체적인 레벨이 전달되면 그걸 사용, 아니면 uniqueDays 기반 계산
        let finalLevel: Int
        if let explicitLevel = level {
            finalLevel = explicitLevel
        } else {
            finalLevel = CharacterLevel.getLevel(uniqueDays: uniqueDays).rawValue + 1
        }
        
        let data = WidgetData(
            goalTitle: goal.title,
            dDay: dDay,
            characterName: goal.characterName,
            characterColor: goal.characterColor,
            characterType: goal.characterType,
            uniqueDays: uniqueDays,
            level: finalLevel
        )
        
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            if let encoded = try? JSONEncoder().encode(data) {
                userDefaults.set(encoded, forKey: dataKey)
                print("✅ [WidgetDataHelper] Data Saved: \(goal.title), D-\(dDay)")
                
                // 위젯 갱신 요청
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                print("❌ [WidgetDataHelper] Encoding Error")
            }
        } else {
            print("⚠️ [WidgetDataHelper] App Group UserDefaults not found. Check Entitlements.")
        }
    }
    
    /// 데이터 삭제 (대표 목표가 없을 때)
    func clearData() {
        if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.removeObject(forKey: dataKey)
            WidgetCenter.shared.reloadAllTimelines()
            print("🧹 [WidgetDataHelper] Data Cleared")
        }
    }
    
    /// 위젯에서 데이터를 읽어오는 헬퍼 (위젯 코드에서 사용 가능하지만, 보통 위젯 파일에 따로 로직을 둡니다)
    func loadData() -> WidgetData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupId),
              let data = userDefaults.data(forKey: dataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
}
