import Foundation

enum CharacterLevel: Int, CaseIterable {
    case lv1 = 0, lv2, lv3, lv4, lv5, lv6, lv7, lv8, lv9, lv10
    
    // ✨ [수정] 누적 학습 일수에 따른 레벨 계산 (계단식 성장)
    static func getLevel(uniqueDays: Int) -> CharacterLevel {
        // Lv.1(0) ~ Lv.10(180)
        switch uniqueDays {
        case 0..<5: return .lv1
        case 5..<15: return .lv2
        case 15..<30: return .lv3
        case 30..<45: return .lv4  // 스타팅 졸업
        case 45..<60: return .lv5
        case 60..<90: return .lv6  // 희귀 졸업
        case 90..<120: return .lv7
        case 120..<150: return .lv8 // 전설 졸업
        case 150..<180: return .lv9
        default: return .lv10       // 신화 졸업 (최종)
        }
    }
    
    // ✨ [추가] 다음 레벨 진화를 위한 목표 일수 (누적 기준)
    var daysRequiredForNextLevel: Int {
        switch self {
        case .lv1: return 5
        case .lv2: return 15
        case .lv3: return 30
        case .lv4: return 45
        case .lv5: return 60
        case .lv6: return 90
        case .lv7: return 120
        case .lv8: return 150
        case .lv9: return 180
        case .lv10: return 0 // Max
        }
    }
    
    // ✨ [추가] 현재 레벨의 시작 일수 (진행률 계산용)
    var daysRequiredForCurrentLevel: Int {
        switch self {
        case .lv1: return 0
        case .lv2: return 5
        case .lv3: return 15
        case .lv4: return 30
        case .lv5: return 45
        case .lv6: return 60
        case .lv7: return 90
        case .lv8: return 120
        case .lv9: return 150
        case .lv10: return 180
        }
    }
    
    func emoji(for type: String) -> String {
        switch type {
        case "plant":
            // ✨ [수정] 일반 등급(스타팅)은 Lv.4까지만 성장하므로 이모지 축소
            let plantLine = ["🍃", "🌱", "🌿", "☘️"]
            return plantLine[min(self.rawValue, plantLine.count - 1)]
        case "sea":
            let seaLine = ["🫧", "💧", "🐟", "🐬"]
            return seaLine[min(self.rawValue, seaLine.count - 1)]
        default:
            let birdLine = ["🥚", "🐣", "🐥", "🐤"]
            return birdLine[min(self.rawValue, birdLine.count - 1)]
        }
    }
    
    // ✨ [수정] 캐릭터 타입별 최종 진화 문구 반영
    func title(for type: String) -> String {
        // 1. 해당 캐릭터 타입의 최대 레벨(인덱스) 확인
        let maxLevelIndex: Int
        if ["unicorn", "dragon"].contains(type) {
            maxLevelIndex = 9 // Lv.10
        } else if ["whale", "phoenix"].contains(type) {
            maxLevelIndex = 7 // Lv.8
        } else if ["tree", "robot"].contains(type) {
            maxLevelIndex = 5 // Lv.6
        } else {
            maxLevelIndex = 3 // Lv.4 (Normal)
        }
        
    // 2. 현재 레벨이 최대 레벨 이상이면 최종 문구 반환
        if isMaxLevel(for: type) {
            return "최종 진화 완료"
        }
        
        // 3. 그 외는 레벨별 기본 문구
        switch self {
        case .lv1: return "공부의 시작"
        case .lv2: return "깨어난 호기심"
        case .lv3: return "작은 발걸음"
        case .lv4: return "성장의 즐거움"
        case .lv5: return "꾸준한 노력"
        case .lv6: return "빛나는 진심"
        case .lv7: return "단단한 내공"
        case .lv8: return "깊어지는 지혜"
        case .lv9: return "만개하는 실력"
        case .lv10: return "최종 진화 완료"
        }
    }
    
    // ✨ [추가] 해당 캐릭터 등급의 최대 레벨 달성 여부 확인
    func isMaxLevel(for type: String) -> Bool {
        let maxLevelIndex: Int
        if ["unicorn", "dragon"].contains(type) {
            maxLevelIndex = 9 // Lv.10
        } else if ["whale", "phoenix"].contains(type) {
            maxLevelIndex = 7 // Lv.8
        } else if ["tree", "robot"].contains(type) {
            maxLevelIndex = 5 // Lv.6
        } else {
            maxLevelIndex = 3 // Lv.4 (Normal)
        }
        return self.rawValue >= maxLevelIndex
    }
}
