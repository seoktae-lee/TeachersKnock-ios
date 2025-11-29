import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    // 앱 전체의 인증 상태를 관리할 객체
    @EnvironmentObject var authManager: AuthManager
    
    // 브랜드 색상
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        TabView {
            // 탭 1: 홈 (D-day 목표)
            GoalListView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }
            
            // 탭 2: 플래너 (일정 관리)
            PlannerView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("플래너")
                }
            
            // 탭 3: 타이머 (공부 시간 측정) - ✨ 새로 연결됨
            TimerView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("타이머")
                }
            
            // 탭 4: 설정 (로그아웃 기능 보존) - ✨ 새로 추가됨
            VStack(spacing: 20) {
                Text("설정")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("현재 로그인된 계정")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // 로그아웃 버튼
                Button(action: logout) {
                    Text("로그아웃")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("설정")
            }
        }
        .accentColor(brandColor) // 선택된 탭 아이콘 색상
    }
    
    // 로그아웃 함수
    func logout() {
        do {
            try Auth.auth().signOut()
            print("로그아웃 성공!")
            
            // 로그아웃 성공 시, AuthManager에게 상태 변경을 요청 -> 로그인 화면으로 전환됨
            authManager.isLoggedIn = false
            
        } catch let signOutError as NSError {
            print("로그아웃 실패: \(signOutError.localizedDescription)")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
