import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthManager: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    // ✨ 닉네임을 저장할 변수
    @Published var userNickname: String = "나" // 기본값
    
    init() {
        checkLoginStatus()
    }
    
    private func checkLoginStatus() {
        if let user = Auth.auth().currentUser, user.isEmailVerified {
            isLoggedIn = true
            // ✨ 로그인 확인되면 닉네임 가져오기
            fetchUserNickname(uid: user.uid)
        } else {
            isLoggedIn = false
            userNickname = "나"
        }
    }
    
    // ✨ Firestore에서 닉네임 가져오는 함수
    func fetchUserNickname(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                // Firestore에 저장된 'nickname' 필드 가져오기
                self.userNickname = data?["nickname"] as? String ?? "나"
            } else {
                print("유저 정보 없음")
            }
        }
    }
}
