import SwiftUI
import FirebaseAuth
import Combine

class AuthManager: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    
    init() {
        // 앱이 처음 켜질 때만 딱 한 번 확인합니다.
        checkLoginStatus()
    }
    
    private func checkLoginStatus() {
        // 이미 로그인된 유저가 있고 + 이메일 인증까지 완료된 경우에만 통과
        if let user = Auth.auth().currentUser, user.isEmailVerified {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }
    
    // 🚨 중요: 실시간 감시자(addStateDidChangeListener)를 제거했습니다.
    // 이제 회원가입 도중에 임시 계정이 생겨도 메인 화면으로 넘어가지 않습니다.
}
