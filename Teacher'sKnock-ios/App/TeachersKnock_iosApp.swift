import SwiftUI
import SwiftData
import FirebaseCore
import UIKit
import UserNotifications

@main
struct TeachersKnock_iosApp: App {
    // ✨ AppDelegate 연결
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 앱 생명주기 동안 살아있는 매니저들
    @StateObject private var authManager = AuthManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var alertManager = AlertManager() // ✨ [New]
    
    init() {
        FirebaseApp.configure()
        TeachersKnock_iosApp.configureAppearance()
    }
    
    static func configureAppearance() {
        print("🎨 [App] configureAppearance 호출됨 (Refined)")
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Helper to create rounded font
        // Helper to create rounded font
        func roundedFont(style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            // 1. 현재 Dynamic Type 설정에 맞는 사이즈 가져오기
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            let size = descriptor.pointSize
            
            // 2. 원하는 굵기의 시스템 폰트 생성
            let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
            
            // 3. Rounded Design 적용 (Descriptor 레벨에서 변환)
            if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
                print("✅ [App] \(style) Rounded Font 적용 성공 (Weight: \(weight))")
                return UIFont(descriptor: roundedDescriptor, size: 0)
            } else {
                print("❌ [App] \(style) Rounded Design 미지원, 기본 시스템 폰트 반환")
                return systemFont
            }
        }
        
        // Large Title (큰 제목)
        appearance.largeTitleTextAttributes = [.font: roundedFont(style: .largeTitle, weight: .bold)]
        
        // Inline Title (작은 제목)
        appearance.titleTextAttributes = [.font: roundedFont(style: .headline, weight: .semibold)]
        
        // Back Button
        let backAppearance = UIBarButtonItemAppearance()
        backAppearance.normal.titleTextAttributes = [.font: roundedFont(style: .body, weight: .medium)]
        appearance.backButtonAppearance = backAppearance
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                // 환경 객체 주입
                .environmentObject(authManager)
                .environmentObject(settingsManager)
                .environmentObject(alertManager) // ✨ [New]
                // ✨ [New] 앱 레벨에서 딥링크 처리 (Cold Start 대응 강화를 위해 위치 변경)
                .onOpenURL { url in
                    if url.scheme == "com.seoktaedev.TeachersKnock-ios" && url.host == "timer" {
                        print("🔗 [App] 타이머 딥링크 감지, 타이머 탭으로 이동")
                        // 싱글톤 매니저의 상태 업데이트
                        DispatchQueue.main.async {
                            print("🔗 [App] 타이머 탭 이동 플래그 설정")
                            StudyNavigationManager.shared.shouldNavigateToTimer = true
                            StudyNavigationManager.shared.tabSelection = 2
                        }
                    }
                }
                // ❌ 주의: 여기서 authManager.setup(...)을 호출하면 안 됩니다!
                // RootView.swift에서 처리하도록 변경했습니다.
        }
        // SwiftData 컨테이너 설정
        .modelContainer(for: [Goal.self, ScheduleItem.self, StudyRecord.self])
    }
}

// ✨ [이동] AppDelegate 오류 해결을 위해 메인 앱 파일 내부에 정의
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 앱 실행 시 델리게이트 설정
        UNUserNotificationCenter.current().delegate = self
        
        // ✨ [Move] Appearance 설정을 여기서 확실하게 호출
        TeachersKnock_iosApp.configureAppearance()
        
        return true
    }
    
    // Foreground에서도 알림 표시 (선택사항)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // ✨ 앱 종료 시 호출
    func applicationWillTerminate(_ application: UIApplication) {
        print("⚠️ [AppDelegate] applicationWillTerminate 호출됨")
        // 타이머 정리 로직 실행
        TimerViewModel.handleAppTermination()
    }
    
    // ✨ 알림 클릭(반응) 시 호출되는 메서드
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let scheduleID = userInfo["scheduleID"] as? String {
            print("🚀 알림 딥링크 감지: scheduleID = \(scheduleID)")
            
            // 메인 스레드에서 네비게이션 매니저에게 전달
            DispatchQueue.main.async {
                StudyNavigationManager.shared.pendingScheduleID = scheduleID
            }
        }
        
        completionHandler()
    }
}
