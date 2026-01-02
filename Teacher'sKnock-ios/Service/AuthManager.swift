import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftData

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    // ✨ [추가됨] 여기에 대학교 이름을 바로 저장합니다!
    @Published var userUniversityName: String?
    // ✨ [New] 티처스노크 ID
    @Published var userTeacherKnockID: String?
    
    var settingsManager: SettingsManager?
    var modelContext: ModelContext?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        checkFreshInstall()
        registerAuthStateListener()
    }
    
    // ✨ [New] 앱 재설치 시 강제 로그아웃 처리
    private func checkFreshInstall() {
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        
        if !hasRunBefore {
            print("🚀 앱이 처음 실행되었습니다 (또는 재설치됨). 기존 세션을 정리합니다.")
            do {
                try Auth.auth().signOut()
                // ✨ 중요: UserDefaults는 앱 삭제 시 함께 날아가므로, 
                // 재설치 후 첫 실행임을 감지할 수 있습니다.
                UserDefaults.standard.set(true, forKey: "hasRunBefore")
            } catch {
                print("초기화 로그아웃 실패: \(error)")
            }
        } else {
            print("✅ 기존 앱 실행 기록이 확인되었습니다.")
        }
    }
    
    func setup(settingsManager: SettingsManager, modelContext: ModelContext) {
        self.settingsManager = settingsManager
        self.modelContext = modelContext
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.userUniversityName = nil // 로그아웃 시 초기화
            self.userTeacherKnockID = nil
            self.settingsManager?.reset()
        } catch {
            print("로그아웃 실패: \(error)")
        }
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            if let user = user {
                self.checkUserExistsInFirestore(uid: user.uid) { exists in
                    if exists {
                        self.isLoggedIn = true
                        // ✨ 로그인 즉시 정보 가져오기
                        self.fetchUserData(uid: user.uid)
                        
                        self.settingsManager?.loadSettings(for: user.uid)
                        if let context = self.modelContext {
                            self.checkAndRestoreData(uid: user.uid, context: context)
                        }
                    } else {
                        self.isLoggedIn = false
                    }
                }
            } else {
                self.isLoggedIn = false
                self.userNickname = "나"
                self.userUniversityName = nil
                self.userTeacherKnockID = nil
                self.settingsManager?.reset()
            }
        }
    }
    
    private func fetchUserData(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self, let doc = doc, doc.exists, let data = doc.data() else { return }
            
            DispatchQueue.main.async {
                self.userNickname = data["nickname"] as? String ?? "나"
                
                // ✨ [핵심] Firestore에서 가져온 대학교 이름을 바로 저장!
                if let univName = data["university"] as? String {
                    self.userUniversityName = univName
                    print("🎓 내 대학교 확인됨: \(univName)")
                }
                
                // ✨ 티처스노크 ID 가져오기
                if let tkID = data["teacherKnockID"] as? String {
                    self.userTeacherKnockID = tkID
                } else {
                    // ⚠️ 기존 가입자(ID 없음) -> ID 자동 생성 및 저장 (Backfill)
                    print("⚠️ 기존 유저: 티처스노크 ID 없음 -> 자동 생성 시도")
                    self.generateUniqueTeacherKnockID { newID in
                        // Firestore 업데이트
                        Firestore.firestore().collection("users").document(uid).updateData([
                            "teacherKnockID": newID
                        ]) { error in
                            if let error = error {
                                print("ID 자동 생성 저장 실패: \(error)")
                            } else {
                                print("✅ 기존 유저 ID 발급 완료: \(newID)")
                                DispatchQueue.main.async {
                                    self.userTeacherKnockID = newID
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ... (나머지 deleteAccount 등의 함수는 기존 코드 유지)
    
    deinit { if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) } }
    
    @MainActor private func checkAndRestoreData(uid: String, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            if try context.fetchCount(descriptor) == 0 {
                FirestoreSyncManager.shared.restoreData(context: context, uid: uid) {}
            }
        } catch { print("데이터 오류: \(error)") }
    }
    
    private func checkUserExistsInFirestore(uid: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in completion(doc?.exists ?? false) }
    }
    
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).delete { _ in
            user.delete { error in completion(error == nil, error) }
        }
    }
    
    // ✨ [New] 닉네임 중복 확인
    func checkNicknameDuplicate(nickname: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users")
            .whereField("nickname", isEqualTo: nickname)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("닉네임 중복 확인 실패: \(error)")
                    completion(false) // 에러 시 일단 중복 아님(또는 에러 처리)으로 처리하지 않고, 안전하게 진행 불가하게 할 수도 있지만 여기선 true/false만 반환
                    return
                }
                // 문서가 하나라도 있으면 중복
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(true)
                } else {
                    completion(false)
                }
            }
    }
    
    // ✨ [New] 티처스노크 ID (TK-ID) 생성 및 중복 확인
    func generateUniqueTeacherKnockID(completion: @escaping (String) -> Void) {
        let candidateID = generateRandomID()
        
        Firestore.firestore().collection("users")
            .whereField("teacherKnockID", isEqualTo: candidateID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("ID 중복 확인 실패: \(error). 재시도합니다.")
                    self.generateUniqueTeacherKnockID(completion: completion)
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    // 중복됨 -> 재귀 호출로 다시 생성
                    print("ID 충돌 발생 (\(candidateID)) -> 재생성")
                    self.generateUniqueTeacherKnockID(completion: completion)
                } else {
                    // 유니크함 -> 반환
                    print("✅ 새 티처스노크 ID 발급: \(candidateID)")
                    completion(candidateID)
                }
            }
    }
    
    private func generateRandomID() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        // 6자리 난수 생성 (예: TK92A1) - 앞 두글자는 TK로 고정하지 않고 전체 난수로 할지,
        // 사용자 요청은 "카카오톡 ID"처럼이므로 랜덤이 좋음. 다만 "TK" 접두어를 붙이면 브랜드 정체성에 좋음.
        // 유저 요청: "티처스노크 id를 각 계정별로 다 다르게 자동으로 생성" -> 일단 완전 랜덤 6자리 또는 TK+4자리.
        // 계획서에는 "영문 대문자 + 숫자 조합의 6~8자리 난수"라고 했으므로 6자리 랜덤으로 진행.
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}
