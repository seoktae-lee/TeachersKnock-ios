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
        case "bird": return "IGNIS SPARK"
        case "plant": return "TERRA LEAF"
        case "sea": return "AQUA DROPLIN"
        case "golem": return "스톤 골렘" // ✨ [New]
        default: return "알 수 없음"
        }
    }
    
    // UI 표시용 이모지
    var emoji: String {
        switch type {
        case "bird": return "🥚"
        case "plant": return "🤎"
        case "sea": return "🧊"
        case "golem": return "🪨" // ✨ [New]
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
            
            // ✨ [Temporary Fix] 파트너 보관함에서 임시 신화 캐릭터(unicorn, dragon) 삭제 요청 처리
            // 이 코드는 해당 캐릭터들을 로컬 데이터에서 필터링하여 제거합니다.
            let removedCount = characters.filter { ["unicorn", "dragon"].contains($0.type) }.count
            if removedCount > 0 {
                self.characters.removeAll { ["unicorn", "dragon"].contains($0.type) }
                print("🧹 임시 신화 캐릭터 \(removedCount)개 삭제 완료")
                self.saveCharacters() // 변경사항 즉시 저장
            }
            
            // ✨ [Cleanup] 테스트용 스톤 골렘 데이터 일괄 삭제 (사용자 요청에 의한 초기화)
            // 주의: 이 로직은 앱 실행 시 'golem' 타입 캐릭터를 삭제합니다. 구매 이력 초기화용.
            // 영구 삭제를 원치 않으면 추후 제거 필요. 현재는 "초기화" 요청에 따라 추가됨.
            let golemCleanupKey = "Cleanup_StoneGolem_Reset_Request"
            if !UserDefaults.standard.bool(forKey: golemCleanupKey) {
                if let index = characters.firstIndex(where: { $0.type == "golem" }) {
                    characters.remove(at: index)
                    saveCharacters()
                    print("🧹 테스트용 스톤 골렘 삭제 및 초기화 완료")
                }
                UserDefaults.standard.set(true, forKey: golemCleanupKey)
                UserDefaults.standard.set(true, forKey: golemCleanupKey)
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
                            
                            // ✨ [Temporary Fix] 서버 데이터에서도 임시 신화 캐릭터(unicorn, dragon) 삭제
                            let removedCount = self.characters.filter { ["unicorn", "dragon"].contains($0.type) }.count
                            if removedCount > 0 {
                                self.characters.removeAll { ["unicorn", "dragon"].contains($0.type) }
                                print("🧹 (서버 동기화) 임시 신화 캐릭터 \(removedCount)개 삭제 및 정리")
                                self.saveCharacters()
                            }
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
        else if ["tree", "robot", "golem"].contains(type) { // ✨ golem 추가
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
        if ["tree", "robot", "golem"].contains(type) { return "희귀" } // ✨ golem 추가
        return "일반"
    }
    
    // ✨ [추가] 캐릭터 등급 색상 반환 헬퍼
    func getRarityColor(type: String) -> Color {
        if ["whale", "phoenix"].contains(type) { return .orange } // 전설
        if ["golem"].contains(type) { return .brown } // ✨ [New] 스톤 골렘은 갈색
        if ["tree", "robot"].contains(type) { return .blue }   // 희귀
        return .gray // 일반
    }
}
