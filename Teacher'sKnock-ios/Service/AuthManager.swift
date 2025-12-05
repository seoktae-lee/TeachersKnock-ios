import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftData

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userNickname: String = "나"
    
    var settingsManager: SettingsManager?
    var modelContext: ModelContext?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() { registerAuthStateListener() }
    
    func setup(settingsManager: SettingsManager, modelContext: ModelContext) {
        self.settingsManager = settingsManager
        self.modelContext = modelContext
    }
    
    // ✨ [추가됨] 로그아웃
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.settingsManager?.reset()
        } catch {
            print("로그아웃 오류: \(error.localizedDescription)")
        }
    }
    
    // 회원 탈퇴
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).delete { _ in
            user.delete { error in
                if let error = error {
                    print("탈퇴 실패: \(error)")
                } else {
                    self.isLoggedIn = false
                }
            }
        }
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user {
                self.isLoggedIn = true
                self.fetchUserNickname(uid: user.uid)
                self.settingsManager?.fetchSettings(uid: user.uid)
            } else {
                self.isLoggedIn = false
                self.settingsManager?.reset()
            }
        }
    }
    
    private func fetchUserNickname(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in
            if let doc = doc, doc.exists {
                self.userNickname = doc.data()?["nickname"] as? String ?? "나"
            }
        }
    }
    
    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }
}
