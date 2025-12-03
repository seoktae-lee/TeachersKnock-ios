import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    var settingsManager: SettingsManager?
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() { registerAuthStateListener() }
    
    func setup(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            if let user = user {
                // Firestore 확인 (회원가입 튕김 방지)
                self.checkUserExistsInFirestore(uid: user.uid) { exists in
                    if exists {
                        self.isLoggedIn = true
                        self.fetchUserNickname(uid: user.uid)
                        self.settingsManager?.fetchSettings(uid: user.uid)
                    } else {
                        // 계정은 있는데 데이터가 없으면 아직 회원가입 중인 상태
                        self.isLoggedIn = false
                    }
                }
            } else {
                self.isLoggedIn = false
                self.userNickname = "나"
                self.settingsManager?.reset()
            }
        }
    }
    
    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }
    
    private func checkUserExistsInFirestore(uid: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in
            completion(doc?.exists ?? false)
        }
    }
    
    private func fetchUserNickname(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            if let doc = doc, doc.exists {
                DispatchQueue.main.async {
                    self.userNickname = doc.data()?["nickname"] as? String ?? "나"
                }
            }
        }
    }
    
    // ✨ [핵심] 계정 완전 삭제 함수
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "로그인 정보 없음"]))
            return
        }
        let uid = user.uid
        
        // 1. Firestore(서버 데이터) 삭제
        Firestore.firestore().collection("users").document(uid).delete { error in
            if let error = error {
                print("❌ Firestore 삭제 실패: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // 2. Firebase Auth(계정 자체) 삭제
            user.delete { error in
                if let error = error {
                    print("❌ 계정 삭제 실패 (재로그인 필요 가능성): \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ 계정 삭제 성공 (Clean Delete)")
                    completion(true, nil)
                }
            }
        }
    }
}
