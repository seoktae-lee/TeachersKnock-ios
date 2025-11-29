import SwiftUI
import FirebaseAuth
import Combine // @Published를 위해 필요

// 앱의 인증 상태를 실시간으로 관리하고 모든 뷰에 공유하는 클래스
class AuthManager: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    private var handler: AuthStateDidChangeListenerHandle?
    
    init() {
        setupListener()
    }
    
    private func setupListener() {
        // Firebase Auth의 상태가 바뀔 때마다 이 클로저가 실행됩니다.
        handler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = (user != nil)
            print("AuthManager 상태 업데이트: isLoggedIn = \(self?.isLoggedIn ?? false)")
        }
    }
    
    deinit {
        if let handler = handler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
}
