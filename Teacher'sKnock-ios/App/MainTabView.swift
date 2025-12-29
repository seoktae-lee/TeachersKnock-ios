import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // ✨ 1. 네비게이션 매니저 생성
    @StateObject private var navigationManager = StudyNavigationManager()
    
    var body: some View {
        // ✨ 2. selection 바인딩 연결
        TabView(selection: $navigationManager.tabSelection) {
            GoalListView(userId: Auth.auth().currentUser?.uid ?? "")
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(0) // 태그 명시
            
            PlannerView()
                .tabItem { Label("플래너", systemImage: "calendar") }
                .tag(1)
            
            TimerView()
                .tabItem { Label("타이머", systemImage: "timer") }
                .tag(2) // StudyNavigationManager의 triggerStudy에서 이 번호로 이동
            
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .accentColor(Color(red: 0.35, green: 0.65, blue: 0.95))
        // ✨ 3. 하위 뷰들이 접근할 수 있도록 환경 객체로 주입
        .environmentObject(navigationManager)
    }
}
