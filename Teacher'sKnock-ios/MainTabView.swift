import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    // 앱 전체의 인증 상태를 관리하는 객체
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
            // GoalListView는 아직 수정하지 않았으므로 userId를 전달합니다.
            GoalListView(userId: currentUserId)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }
            
            // 탭 2: 플래너 (수정됨 ✨)
            // 이제 PlannerView는 스스로 ID를 찾으므로 괄호 안을 비워야 합니다.
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
            
            // 탭 4: 통계 (학습 분석)
            StatisticsView(userId: currentUserId)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("통계")
                }
        }
        .accentColor(brandColor) // 탭 선택 색상 적용
    }
}
