import SwiftUI
import SwiftData
import FirebaseCore
import UIKit
import UserNotifications

import Sentry

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
        // ✨ [New] 결제 시스템 초기화
        PurchaseManager.shared.configure()
    }
    
    static func configureAppearance() {
        print("🎨 [App] configureAppearance 호출됨 (Custom NanumSquareRound)")
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // ✨ Custom Font Helper
        func customFont(name: String, size: CGFloat) -> UIFont {
            guard let font = UIFont(name: name, size: size) else {
                print("⚠️ [App] 폰트 로드 실패: \(name), 시스템 폰트로 대체")
                return UIFont.systemFont(ofSize: size, weight: .bold)
            }
            return font
        }
        
        // 폰트 이름 정의 (실제 PostScript 이름과 일치해야 함. 보통 파일명과 유사)
        // NanumSquareRoundB -> NanumSquareRoundB
        // NanumSquareRoundR -> NanumSquareRoundR
        let boldFontName = "NanumSquareRoundB"
        let regularFontName = "NanumSquareRoundR"
        let extraBoldFontName = "NanumSquareRoundEB"
        
        // Large Title (큰 제목) - 34pt Bold
        let largeFont = customFont(name: extraBoldFontName, size: 34)
        appearance.largeTitleTextAttributes = [.font: largeFont]
        
        // Inline Title (작은 제목)
        let standardFont = customFont(name: boldFontName, size: 18) // 가독성을 위해 18pt
        appearance.titleTextAttributes = [.font: standardFont]
        
        // Back Button
        let backAppearance = UIBarButtonItemAppearance()
        let backFont = customFont(name: regularFontName, size: 17)
        backAppearance.normal.titleTextAttributes = [.font: backFont]
        appearance.backButtonAppearance = backAppearance
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // ✨ 탭바 아이템 폰트
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        let tabBarFont = customFont(name: boldFontName, size: 11)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.font: tabBarFont]
        itemAppearance.selected.titleTextAttributes = [.font: tabBarFont]
        
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
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
        
        // ✨ Sentry 초기화 (여기로 이동)
        SentrySDK.start { options in
            options.dsn = "https://ad5943542bf74d6c404ddbc5cf50a8a8@o4510734444003328.ingest.us.sentry.io/4510734447214592"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.enableAppHangTracking = true // 앱 멈춤 감지 추가
        }
        
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
