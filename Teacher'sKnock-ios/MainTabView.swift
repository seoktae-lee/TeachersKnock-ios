import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    // 앱 전체의 인증 상태를 관리할 객체
    @EnvironmentObject var authManager: AuthManager
    
    // 브랜드 색상
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 현재 로그인한 유저의 ID를 가져오는 연산 프로퍼티
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        TabView {
            // 탭 1: 홈 (D-day 목표)
            GoalListView(userId: currentUserId)
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
            
            // 탭 3: 타이머 (공부 시간 측정)
            TimerView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("타이머")
                }
            
            // 탭 4: 설정 (회원탈퇴 기능이 포함된 SettingsView 연결)
            SettingsView() // ✨ 기존 코드를 지우고 이 한 줄로 교체했습니다.
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("설정")
                }
        }
        .accentColor(brandColor) // 선택된 탭 아이콘 색상
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
