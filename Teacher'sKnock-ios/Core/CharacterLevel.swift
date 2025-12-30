import Foundation

enum CharacterLevel: Int, CaseIterable {
    case lv1 = 0, lv2, lv3, lv4, lv5, lv6, lv7, lv8, lv9, lv10
    
    // ✨ [수정] 현재 일수에 따른 레벨 계산
    static func getLevel(uniqueDays: Int) -> CharacterLevel {
        return .lv2 // ✨ [테스트] 강제 레벨 2 반환
        /*
        if uniqueDays < 3 { return .lv1 }
        
        // 기존 로그 기반 로직 유지
        let levelIndex = Int(log(Double(uniqueDays) / 2.0) / log(1.5))
        return CharacterLevel(rawValue: max(0, min(levelIndex, 9))) ?? .lv1
        */
    }
    
    // ✨ [추가] 다음 레벨로 가기 위해 필요한 총 일수 계산
    var daysRequiredForNextLevel: Int {
        if self == .lv10 { return 0 }
        // getLevel 로직의 역산: uniqueDays = 2 * (1.5^levelIndex)
        // 다음 레벨 인덱스는 rawValue + 1
        let nextIndex = Double(self.rawValue + 1)
        return Int(ceil(2.0 * pow(1.5, nextIndex)))
    }
    
    // ✨ [추가] 현재 레벨의 시작 일수 (진행률 계산용)
    var daysRequiredForCurrentLevel: Int {
        if self == .lv1 { return 0 }
        let currentIndex = Double(self.rawValue)
        return Int(ceil(2.0 * pow(1.5, currentIndex)))
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
