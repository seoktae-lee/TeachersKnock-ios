import Foundation
import SwiftData
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

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
        case "bird": return "이그니스 스파크"
        case "plant": return "테라 리프"
        case "sea": return "아쿠아 드롭린"
        case "golem": return "스톤 골렘"
        case "cloud": return "클라우드 가디언" // ✨ [Update] Match shop name
        case "unicorn": return "브라이트닝 유니콘" // ✨ [New]
        case "wolf": return "크리스탈 울프" // ✨ [New]
        default: return "알 수 없음"
        }
    }
    
    // UI 표시용 이모지
    var emoji: String {
        switch type {
        case "bird": return "🥚"
        case "plant": return "🤎"
        case "sea": return "🧊"
        case "golem": return "🪨"
        case "cloud": return "☁️" // ✨ [New]
        case "unicorn": return "🦄" // ✨ [New]
        case "wolf": return "🐺" // ✨ [New]
        default: return "❓"
        }
    }
    // ✨ [추가] Firestore 저장을 위한 Dictionary 변환
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "name": name,
            "level": level,
            "exp": exp,
            "isUnlocked": isUnlocked
        ]
        if let lastStudyDate = lastStudyDate {
            dict["lastStudyDate"] = lastStudyDate.timeIntervalSince1970
        }
        return dict
    }
    
    // ✨ [수정] 기본 Memberwise Initializer 복원
    init(type: String, name: String, level: Int, exp: Int, isUnlocked: Bool, lastStudyDate: Date?) {
        self.type = type
        self.name = name
        self.level = level
        self.exp = exp
        self.isUnlocked = isUnlocked
        self.lastStudyDate = lastStudyDate
    }
    
    // ✨ [추가] Dictionary -> UserCharacter 복원
    init?(dictionary: [String: Any]) {
        guard let type = dictionary["type"] as? String,
              let name = dictionary["name"] as? String,
              let level = dictionary["level"] as? Int,
              let exp = dictionary["exp"] as? Int,
              let isUnlocked = dictionary["isUnlocked"] as? Bool else { return nil }
        
        self.type = type
        self.name = name
        self.level = level
        self.exp = exp
        self.isUnlocked = isUnlocked
        
        if let dateTs = dictionary["lastStudyDate"] as? Double {
            self.lastStudyDate = Date(timeIntervalSince1970: dateTs)
        } else {
            self.lastStudyDate = nil
        }
    }
}

class CharacterManager: ObservableObject {
    static let shared = CharacterManager()
    
    @Published var characters: [UserCharacter] = []
    @Published var equippedCharacterType: String = "bird"
    
    // ✨ [추가] 진화 애니메이션 제어용 상태
    @Published var showEvolutionAnimation = false
    
    private let baseStorageKey = "UserCharacters_v1"
    private let baseEquippedKey = "EquippedCharacterType_v1"
    
    // 현재 로그인된 유저 ID 추적
    private var currentUserID: String?
    
    private init() {
        // 자동 로드 제거: 로그아웃/로그인 시 명시적으로 호출
    }
    
    var equippedCharacter: UserCharacter? {
        characters.first(where: { $0.type == equippedCharacterType })
    }
    
    // ✨ [수정] 유저별 데이터 로드
    func loadData(for uid: String) {
        self.currentUserID = uid
        let userStorageKey = "\(baseStorageKey)_\(uid)"
        let userEquippedKey = "\(baseEquippedKey)_\(uid)"
        
        if let data = UserDefaults.standard.data(forKey: userStorageKey),
           let decoded = try? JSONDecoder().decode([UserCharacter].self, from: data) {
            self.characters = decoded
            
            // ✨ [Migration] 잘못된 이름 수정 (클라우드 정령 -> 클라우드 가디언)
            for index in self.characters.indices {
                if self.characters[index].type == "cloud" && self.characters[index].name == "클라우드 정령" {
                    self.characters[index].name = "클라우드 가디언"
                    print("🔧 '클라우드 정령' 이름 수정 완료")
                    self.saveCharacters()
                }
            }
            

            
            // ✨ [Cleanup] 테스트용 스톤 골렘 데이터 일괄 삭제 (사용자 요청에 의한 초기화)
            // 주의: 이 로직은 앱 실행 시 'golem' 타입 캐릭터를 삭제합니다. 구매 이력 초기화용.
            // 영구 삭제를 원치 않으면 추후 제거 필요. 현재는 "초기화" 요청에 따라 추가됨.
            // ✨ [Cleanup] 테스트용 구매 캐릭터 일괄 초기화 (사용자 요청)
            // 'golem', 'cloud', 'unicorn', 'wolf' 등 테스트를 위해 구매했던 캐릭터 제거
            let testPurchaseCleanupKey = "Cleanup_TestPurchases_Reset_v2"
            if !UserDefaults.standard.bool(forKey: testPurchaseCleanupKey) {
                // 제거할 타입 목록
                let typesToRemove = ["golem", "cloud", "unicorn", "wolf"]
                
                // 해당 타입의 캐릭터들을 리스트에서 제거
                characters.removeAll { typesToRemove.contains($0.type) }
                
                // 만약 장착 중인 캐릭터가 삭제되었다면 기본 캐릭터(bird)로 변경
                if typesToRemove.contains(equippedCharacterType) {
                    equippedCharacterType = "bird"
                }
                
                saveCharacters()
                print("🧹 테스트용 캐릭터(golem, cloud, unicorn, wolf) 구매 초기화 완료")
                
                UserDefaults.standard.set(true, forKey: testPurchaseCleanupKey)
            }
            
            // ✨ [Restoration] 사용자 요청 복구: Lv.2 / 다음 레벨까지 6일 남음
            // Lv.3 도달 필요 누적일: 15일
            // 목표: 15 - 6 = 9일 (현재 경험치)
            let restorationKey = "Restoration_User_Lv2_6DaysLeft"
            if !UserDefaults.standard.bool(forKey: restorationKey) {
                // 현재 장착중인 캐릭터(스타팅)를 대상으로 복구
                // 장착 타입이 'bird', 'plant', 'sea' 중 하나일 가능성이 높음
                // 안전하게 현재 리스트의 첫번째 혹은 스타팅 캐릭터를 찾아 적용
                if let index = characters.firstIndex(where: { ["bird", "plant", "sea"].contains($0.type) }) {
                    characters[index].exp = 9
                    characters[index].level = 1 // Lv.2는 index 1
                    saveCharacters()
                    print("✅ 사용자 요청 복구 완료: \(characters[index].type) -> Exp 9 (Lv.2, -6일)")
                }
                UserDefaults.standard.set(true, forKey: restorationKey)
            }
        } else {
            self.characters = []
        }
        
        if let savedType = UserDefaults.standard.string(forKey: userEquippedKey) {
            self.equippedCharacterType = savedType
        } else {
            self.equippedCharacterType = "bird"
        }
        
        // 서버 동기화
        fetchFromFirestore(uid: uid)
    }
    
    // ✨ [추가] 데이터 초기화 (로그아웃 시)
    func clearData() {
        self.currentUserID = nil
        self.characters = []
        self.equippedCharacterType = "bird"
    }
    
    func saveCharacters() {
        guard let uid = currentUserID ?? Auth.auth().currentUser?.uid else { return }
        
        // 1. 로컬 저장 (UserDefaults) - 유저별 키 사용
        let userStorageKey = "\(baseStorageKey)_\(uid)"
        let userEquippedKey = "\(baseEquippedKey)_\(uid)"
        
        if let encoded = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(encoded, forKey: userStorageKey)
        }
        UserDefaults.standard.set(equippedCharacterType, forKey: userEquippedKey)
        
        // 2. 서버 저장 (Firestore)
        saveToFirestore(uid: uid)
    }
    
    // ✨ [추가] Firestore에 데이터 저장
    func saveToFirestore(uid: String) {
        let characterData = characters.map { $0.asDictionary }
        let data: [String: Any] = [
            "characters": characterData,
            "equippedType": equippedCharacterType,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        Firestore.firestore().collection("users").document(uid).collection("characters").document("data")
            .setData(data) { error in
                if let error = error {
                    print("❌ 캐릭터 서버 저장 실패: \(error.localizedDescription)")
                } else {
                    print("✅ 캐릭터 서버 저장 완료")
                }
            }
    }
    
    // ✨ [추가] Firestore에서 데이터 불러오기 (로그인 직후 호출)
    func fetchFromFirestore(uid: String) {
        Firestore.firestore().collection("users").document(uid).collection("characters").document("data")
            .getDocument { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }
                
                // 캐릭터 리스트 복원
                if let charDataArray = data["characters"] as? [[String: Any]] {
                    let fetchedCharacters = charDataArray.compactMap { UserCharacter(dictionary: $0) }
                    
                    // ✨ 로컬 데이터와 병합 (서버 데이터가 있으면 덮어씌움)
                    if !fetchedCharacters.isEmpty {
                        DispatchQueue.main.async {
                            self.characters = fetchedCharacters
                            

                            print("✅ 서버에서 캐릭터 복원 완료 (총 \(self.characters.count)개)")
                            
                            // 장착 중인 캐릭터 복원
                            if let savedType = data["equippedType"] as? String {
                                self.equippedCharacterType = savedType
                            }
                            
                            // 로컬에도 최신화 저장
                            self.saveCharacters()
                        }
                    }
                }
            }
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
        
        // 전설 (Legend): Lv.8 (Index 7)
        if ["whale", "phoenix"].contains(type) {
            maxLevelIndex = 7
        }
        // 희귀 (Rare): Lv.6 (Index 5)
        else if ["tree", "robot", "golem", "cloud", "unicorn", "wolf"].contains(type) { // ✨ golem, cloud, unicorn, wolf 추가
            maxLevelIndex = 5
        }
        // 스타팅/일반 (Starter): Lv.4 (Index 3)
        else {
            maxLevelIndex = 3
        }
        
        // 최종 레벨 결정
        levelIndex = min(levelIndex, maxLevelIndex)
        characters[index].level = levelIndex
        
        if levelIndex > oldLevel {
            // 메인 스레드에서 UI 업데이트 보장
            DispatchQueue.main.async {
                self.showEvolutionAnimation = true
            }
        }
    }
    
    // ✨ [Debug] 함수 제거됨 (Cleanup)
    
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
        if ["whale", "phoenix"].contains(type) { return "전설" }
        if ["tree", "robot", "golem", "cloud", "unicorn", "wolf"].contains(type) { return "희귀" } // ✨ golem, cloud, unicorn, wolf 추가
        return "일반"
    }
    
    // ✨ [추가] 캐릭터 등급 색상 반환 헬퍼
    func getRarityColor(type: String) -> Color {
        if ["whale", "phoenix"].contains(type) { return .orange } // 전설
        if ["golem"].contains(type) { return .brown }
        if ["cloud"].contains(type) { return .cyan } // ✨ [New] 구름은 하늘색
        if ["unicorn"].contains(type) { return Color(red: 1.0, green: 0.85, blue: 0.4) } // ✨ [Fix] 유니콘 색상 채도 증가 (진한 노란/금색 계열)
        if ["wolf"].contains(type) { return Color(red: 0.4, green: 0.7, blue: 1.0) } // ✨ [New] 울프는 아이스 블루
        if ["tree", "robot"].contains(type) { return .blue }   // 희귀
        return .gray // 일반
    }

    
    // ✨ [DEBUG] 레벨업 (테스트용: 다음 레벨 조건 충족시키기)
    func debugLevelUp() {
        guard let index = characters.firstIndex(where: { $0.type == equippedCharacterType }) else { return }
        let currentLevelVal = characters[index].level
        
        // Max Level Check
        let type = characters[index].type
        let maxLevelIndex: Int
        if ["whale", "phoenix"].contains(type) { maxLevelIndex = 7 }
        else if ["tree", "robot", "golem", "cloud", "unicorn", "wolf"].contains(type) { maxLevelIndex = 5 }
        else { maxLevelIndex = 3 }
        
        if currentLevelVal >= maxLevelIndex {
            print("⚠️ 이미 최대 레벨입니다.")
            return
        }
        
        if let currentLvEnum = CharacterLevel(rawValue: currentLevelVal) {
            let nextExp = currentLvEnum.daysRequiredForNextLevel
            characters[index].exp = nextExp
            print("⚡️ DEBUG: \(type) Level Up triggered! Exp -> \(nextExp)")
            
            updateLevel(for: index)
            saveCharacters()
        }
    }
    
    // ✨ [DEBUG] 레벨 초기화 (테스트용)
    func debugResetLevel() {
        guard let index = characters.firstIndex(where: { $0.type == equippedCharacterType }) else { return }
        characters[index].level = 0
        characters[index].exp = 0
        saveCharacters()
        print("🔄 DEBUG: \(characters[index].type) Reset to Level 1 (0)")
    }
}
