import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.modelContext) var modelContext
    @State private var showSplash: Bool = true // 스플래시 표시 여부
    
    @EnvironmentObject var alertManager: AlertManager // ✨ [New]
    
    var body: some View {
        ZStack {
            if showSplash {
                // 1. 스플래시 화면
                SplashView()
                    .transition(.opacity)
            } else {
                // 2. 스플래시 종료 후: 로그인 상태에 따라 분기
                if authManager.isLoggedIn {
                    MainTabView()
                        .onAppear {
                            alertManager.startListening()
                        }
                } else {
                    LoginView()
                }
            }
            
            // ✨ [New] 글로벌 토스트 메시지
            if alertManager.showToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: alertManager.toastIcon)
                            .foregroundColor(.white)
                            .font(.title3)
                        
                        Text(alertManager.toastMessage)
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .shadow(radius: 5)
                    .padding(.top, 60) // 상단 여백 (Dynamic Island 고려)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100) // 최상단 보장
                // 터치 패스스루 필요시 설정 (여기선 그냥 둠)
            }
        }
        .onAppear {
            // ✨ [핵심] 중요: 매니저들 연결 (Dependency Injection)
            authManager.setup(settingsManager: settingsManager, modelContext: modelContext)
            
            // 2초 뒤에 스플래시를 끄고 메인 로직으로 진입
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSplash = false
                }
            }
        }
        .onChange(of: authManager.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                alertManager.startListening()
            } else {
                alertManager.stopListening()
            }
        }
    }
}
