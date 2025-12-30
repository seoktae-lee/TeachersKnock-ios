import SwiftUI
import FirebaseAuth
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // ✨ 1. 네비게이션 매니저 생성 (싱글톤 공유 인스턴스 사용)
    @StateObject private var navigationManager = StudyNavigationManager.shared
    @Environment(\.modelContext) private var modelContext // DB 접근용
    
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
        
        // ✨ 4. 딥링크 로직
        .onChange(of: navigationManager.pendingScheduleID) { newID in
            handleDeepLink(idString: newID)
        }
        .onAppear {
            // Cold Start 시 이미 값이 있으면 처리
            if let pendingID = navigationManager.pendingScheduleID {
                handleDeepLink(idString: pendingID)
            }
        }
    }
    
    private func handleDeepLink(idString: String?) {
        guard let idString = idString, let uuid = UUID(uuidString: idString) else { return }
        
        print("🔄 딥링크 처리 시작: \(idString)")
        
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            if let item = results.first {
                print("✅ 일정 찾음: \(item.title), 타이머로 이동")
                
                // 메인 스레드 보장
                DispatchQueue.main.async {
                    navigationManager.triggerStudy(for: item)
                    // 처리 후 초기화 (재진입 방지) - 약간의 딜레이를 두어 뷰 갱신 후 초기화
                    navigationManager.pendingScheduleID = nil
                }
            } else {
                print("⚠️ 일정을 찾을 수 없음")
                navigationManager.pendingScheduleID = nil
            }
        } catch {
            print("❌ 딥링크 검색 오류: \(error)")
            navigationManager.pendingScheduleID = nil
        }
    }
}
