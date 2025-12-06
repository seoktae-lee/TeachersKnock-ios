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
    
    var settingsManager: SettingsManager?
    var modelContext: ModelContext?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        registerAuthStateListener()
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
}
