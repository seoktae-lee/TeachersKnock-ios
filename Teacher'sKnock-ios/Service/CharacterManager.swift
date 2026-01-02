import Foundation
import SwiftData
import Combine
import SwiftUI

struct UserCharacter: Codable, Identifiable {
    var id: String { type }
    let type: String       // "bird", "plant", "sea"
    var name: String       // 사용자가 지어준 이름 (기본값 있음)
    var level: Int         // 1 ~ 10
    var exp: Int           // 누적 공부일 (Level 계산용)
    var isUnlocked: Bool
    var lastStudyDate: Date? // ✨ [추가] 마지막으로 경험치를 획득한 날짜 (하루 1회 제한)
    
    // UI 표시용 기본 이름
    var defaultName: String {
        switch type {
        case "bird": return "열정의 티노"
        case "plant": return "성실의 새싹"
        case "sea": return "지혜의 바다"
        default: return "알 수 없음"
        }
    }
    
    // UI 표시용 이모지
    var emoji: String {
        switch type {
        case "bird": return "🥚"
        case "plant": return "🤎"
        case "sea": return "🧊"
        default: return "❓"
        }
    }
}

class CharacterManager: ObservableObject {
    static let shared = CharacterManager()
    
    @Published var characters: [UserCharacter] = []
    @Published var equippedCharacterType: String = "bird"
    
    // ✨ [추가] 진화 애니메이션 제어용 상태
    @Published var showEvolutionAnimation = false
    
    private let storageKey = "UserCharacters_v1"
    private let equippedKey = "EquippedCharacterType_v1"
    
    init() {
        loadCharacters()
    }
    
    var equippedCharacter: UserCharacter? {
        characters.first(where: { $0.type == equippedCharacterType })
    }
    
    func loadCharacters() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UserCharacter].self, from: data) {
            self.characters = decoded
        }
        
        if let savedType = UserDefaults.standard.string(forKey: equippedKey) {
            self.equippedCharacterType = savedType
        } else {
            self.equippedCharacterType = "bird"
        }
    }
    
    func saveCharacters() {
        if let encoded = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        UserDefaults.standard.set(equippedCharacterType, forKey: equippedKey)
    }
    
    func equipCharacter(type: String) {
        guard characters.contains(where: { $0.type == type && $0.isUnlocked }) else { return }
        equippedCharacterType = type
        saveCharacters()
    }
    
    // ✨ [수정] 공부 기록 완료 시 호출: 경험치(일수) 증가 (하루 1회 제한)
    func addExpToEquippedCharacter() {
        guard let index = characters.firstIndex(where: { $0.type == equippedCharacterType }) else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // 이미 오늘 공부를 기록했다면 패스 (UserCharacter에 lastStudyDate 필드 필요)
        if let lastDate = characters[index].lastStudyDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            if lastDay == today {
                print("⚠️ 오늘 이미 경험치를 획득했습니다.")
                return
            }
        }
        
        // 경험치 증가
        characters[index].exp += 1
        characters[index].lastStudyDate = Date()
        print("✅ 캐릭터 경험치 +1 (현재: \(characters[index].exp))")
        
        updateLevel(for: index)
        saveCharacters()
    }
    
    // 레벨 업데이트 로직 (CharacterLevel의 기준 따름)
    private func updateLevel(for index: Int) {
        let oldLevel = characters[index].level
        let exp = characters[index].exp
        var levelIndex = CharacterLevel.getLevel(uniqueDays: exp).rawValue
        
        // ✨ [수정] 캐릭터 등급별 최대 레벨 제한 (Tier System)
        let type = characters[index].type
        let maxLevelIndex: Int
        
        // 신화 (Mythic): Lv.10 (Index 9)
        if ["unicorn", "dragon"].contains(type) {
            maxLevelIndex = 9
        }
        // 전설 (Legend): Lv.8 (Index 7)
        else if ["whale", "phoenix"].contains(type) {
            maxLevelIndex = 7
        }
        // 희귀 (Rare): Lv.6 (Index 5)
        else if ["tree", "robot"].contains(type) {
            maxLevelIndex = 5
        }
        // 스타팅/일반 (Starter): Lv.4 (Index 3)
        else {
            maxLevelIndex = 3
        }
        
        // 최종 레벨 결정
        levelIndex = min(levelIndex, maxLevelIndex)
        characters[index].level = levelIndex
        
        // ✨ [추가] 레벨업 시 진화 애니메이션 트리거
        if levelIndex > oldLevel {
            // 메인 스레드에서 UI 업데이트 보장
            DispatchQueue.main.async {
                self.showEvolutionAnimation = true
            }
        }
    }
    
    // 캐릭터 이름 변경
    func updateName(type: String, newName: String) {
        if let index = characters.firstIndex(where: { $0.type == type }) {
            characters[index].name = newName
            saveCharacters()
        }
    }
    
    // ✨ [추가] 최초 시작 캐릭터 해금
    func unlockStartingCharacter(type: String, name: String) {
        // 이미 해당 타입이 있는지 확인 (중복 방지)
        guard !characters.contains(where: { $0.type == type }) else { return }
        
        // 입력된 이름이 없으면 기본 이름 사용
        let finalName = name.isEmpty ? (UserCharacter(type: type, name: "", level: 0, exp: 0, isUnlocked: true, lastStudyDate: nil).defaultName) : name
        
        let newCharacter = UserCharacter(
            type: type,
            name: finalName,
            level: 0,
            exp: 0,
            isUnlocked: true,
            lastStudyDate: nil // 초기화
        )
        
        characters.append(newCharacter)
        equippedCharacterType = type
        saveCharacters()
    }
    
    // ✨ [추가] 캐릭터 등급 텍스트 반환 헬퍼
    func getRarityTitle(type: String) -> String {
        if ["unicorn", "dragon"].contains(type) { return "신화" }
        if ["whale", "phoenix"].contains(type) { return "전설" }
        if ["tree", "robot"].contains(type) { return "희귀" }
        return "일반"
    }
    
    // ✨ [추가] 캐릭터 등급 색상 반환 헬퍼
    func getRarityColor(type: String) -> Color {
        if ["unicorn", "dragon"].contains(type) { return .purple } // 신화
        if ["whale", "phoenix"].contains(type) { return .orange } // 전설
        if ["tree", "robot"].contains(type) { return .blue }   // 희귀
        return .gray // 일반
    }
}
