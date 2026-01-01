import SwiftUI
import FamilyControls
import UserNotifications
import EventKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var curPage = 0
    
    // 권한 상태 관리
    @State private var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @State private var screenTimeAuthorized: Bool = false
    @State private var notificationAuthorized: Bool = false
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            Color("BrandColor").opacity(0.1).ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("건너뛰기") {
                        isPresented = false
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
                }
                
                TabView(selection: $curPage) {
                    // 페이지 1: 인트로
                    OnboardingPage(
                        imageName: "timer",
                        title: "집중할 시간입니다",
                        description: "타이머를 사용하여\n효율적인 공부 습관을 만들어보세요.",
                        showButton: true,
                        buttonTitle: "시작하기",
                        action: { withAnimation { curPage += 1 } }
                    )
                    .tag(0)
                    
                    // 페이지 2: 캘린더 권한
                    OnboardingPage(
                        imageName: "calendar",
                        title: "일정과 연동",
                        description: "캘린더의 공부 일정을 불러와\n바로 타이머를 실행할 수 있습니다.",
                        showButton: true,
                        buttonTitle: calendarButtonTitle,
                        isButtonEnabled: calendarAuthStatus == .notDetermined,
                        action: requestCalendarPermission
                    )
                    .tag(1)
                    
                    // 페이지 3: 스크린 타임 (방해 금지)
                    OnboardingPage(
                        imageName: "hand.raised.fill",
                        title: "방해 금지 설정",
                        description: "공부 중에는 알림을 차단하고\n다른 앱의 사용을 제한할 수 있습니다.",
                        showButton: true,
                        buttonTitle: screenTimeAuthorized ? "완료됨" : "권한 허용",
                        isButtonEnabled: !screenTimeAuthorized,
                        action: requestScreenTimePermission
                    )
                    .tag(2)
                    
                    // 페이지 4: 알림
                    OnboardingPage(
                        imageName: "bell.fill",
                        title: "알림 받기",
                        description: "타이머 종료 및 휴식 시간 알림을\n받을 수 있습니다.",
                        showButton: true,
                        buttonTitle: "시작하기",
                        action: requestNotificationPermissionAndFinish
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: curPage)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    // MARK: - 권한 요청 로직
    
    private var calendarButtonTitle: String {
        switch calendarAuthStatus {
        case .authorized, .fullAccess, .writeOnly: return "완료됨"
        case .denied, .restricted: return "설정에서 허용 필요"
        case .notDetermined: return "캘린더 접근 허용"
        @unknown default: return "캘린더 접근 허용"
        }
    }
    
    private func checkPermissions() {
        // 캘린더 체크
        self.calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
        
        // 스크린 타임 체크
        Task {
            if AuthorizationCenter.shared.authorizationStatus == .approved {
                screenTimeAuthorized = true
            }
        }
        
        // 알림 체크
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func requestCalendarPermission() {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.calendarAuthStatus = .fullAccess
                    withAnimation { curPage += 1 }
                } else {
                    // 거부 시 설정으로 유도하거나 다음으로 넘어감
                    self.calendarAuthStatus = .denied
                    withAnimation { curPage += 1 }
                }
            }
        }
    }
    
    private func requestScreenTimePermission() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                DispatchQueue.main.async {
                    self.screenTimeAuthorized = true
                    withAnimation { curPage += 1 }
                }
            } catch {
                print("Screen Time auth failed: \(error)")
                // 실패해도 넘어감
                DispatchQueue.main.async {
                    withAnimation { curPage += 1 }
                }
            }
        }
    }
    
    private func requestNotificationPermissionAndFinish() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isPresented = false
            }
        }
    }
}

struct OnboardingPage: View {
    let imageName: String
    let title: String
    let description: String
    let showButton: Bool
    let buttonTitle: String
    var isButtonEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                .padding()
                .background(Circle().fill(Color.white).shadow(radius: 5))
            
            VStack(spacing: 15) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            if showButton {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isButtonEnabled ? Color(red: 0.35, green: 0.65, blue: 0.95) : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(!isButtonEnabled)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}
