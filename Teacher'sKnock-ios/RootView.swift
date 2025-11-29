// RootView.swift 최종 수정 코드 (구조적 오류 수정)

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isSplashFinished = false
    
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if !isSplashFinished {
                // Splash 화면 (스플래시가 끝나기 전)
                SplashView(isSplashFinished: $isSplashFinished)
            } else if authManager.isLoggedIn {
                // 로그인 상태라면 -> 메인 화면
                MainTabView()
            } else {
                // 로그아웃 상태라면 -> 로그인 화면
                LoginView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
}
