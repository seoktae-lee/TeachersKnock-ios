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
        print("AuthManager: 설정 및 데이터 연결 완료")
    }
    
    // 로그아웃
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.settingsManager?.reset()
            print("로그아웃 성공")
        } catch {
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }
    
    private func registerAuthStateListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            if let user = user {
                self.checkUserExistsInFirestore(uid: user.uid) { exists in
                    if exists {
                        self.isLoggedIn = true
                        // ✨ 닉네임 + 대학교 정보 가져오기
                        self.fetchUserData(uid: user.uid)
                        
                        self.settingsManager?.fetchSettings(uid: user.uid)
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
                self.settingsManager?.reset()
            }
        }
    }
    
    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }
    
    @MainActor
    private func checkAndRestoreData(uid: String, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            let count = try context.fetchCount(descriptor)
            if count == 0 {
                FirestoreSyncManager.shared.restoreData(context: context, uid: uid) {
                    print("AuthManager: 데이터 동기화 완료")
                }
            }
        } catch {
            print("데이터 확인 중 오류: \(error)")
        }
    }
    
    private func checkUserExistsInFirestore(uid: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in
            completion(doc?.exists ?? false)
        }
    }
    
    // ✨ [수정됨] 유저 정보(닉네임, 대학교) 가져오기
    private func fetchUserData(uid: String) {
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            
            if let doc = doc, doc.exists, let data = doc.data() {
                DispatchQueue.main.async {
                    // 1. 닉네임 설정
                    self.userNickname = data["nickname"] as? String ?? "나"
                    
                    // 2. ✨ 대학교 정보가 있으면 자동 세팅
                    // (Firestore 필드명이 'university'라고 가정)
                    if let univName = data["university"] as? String {
                        print("AuthManager: 유저 소속 대학교 확인됨 -> \(univName)")
                        self.settingsManager?.setUniversity(fromName: univName)
                    }
                }
            }
        }
    }
    
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        Firestore.firestore().collection("users").document(uid).delete { error in
            if let error = error { completion(false, error); return }
            user.delete { error in completion(error == nil, error) }
        }
    }
}
