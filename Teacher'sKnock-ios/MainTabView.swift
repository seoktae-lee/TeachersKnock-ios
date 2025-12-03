import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        TabView {
            // 탭 1: 홈
            GoalListView(userId: currentUserId)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }
            
            // 탭 2: 플래너 (✨ 수정됨: userId 전달 삭제)
            PlannerView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("플래너")
                }
            
            // 탭 3: 타이머
            TimerView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("타이머")
                }
            
            // 탭 4: 설정
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("설정")
                }
        }
        .accentColor(brandColor)
    }
}
