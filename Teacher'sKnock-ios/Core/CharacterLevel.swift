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
            let plantLine = ["🤎", "🌱", "🌿", "☘️", "🍀", "🎋", "🌲", "🌳", "🍎", "🌈"]
            return plantLine[min(self.rawValue, 9)]
        case "sea":
            let seaLine = ["🧊", "💧", "🐟", "🐬", "🐳", "🌊", "🐚", "🔱", "🧜‍♂️", "🌟"]
            return seaLine[min(self.rawValue, 9)]
        default:
            let birdLine = ["🥚", "🐣", "🐥", "🐤", "🕊️", "🦅", "🦉", "🦢", "🐓", "👑"]
            return birdLine[min(self.rawValue, 9)]
        }
    }
    
    var title: String {
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
}
