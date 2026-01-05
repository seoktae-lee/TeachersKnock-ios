import SwiftUI
import SwiftData
import FirebaseAuth
import FamilyControls

// ✨ [New] 오디오 비주얼라이저 뷰
struct AudioVisualizerView: View {
    var audioLevel: Float
    
    // 5개의 바를 사용
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .frame(width: 8, height: height(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: 50)
    }
    
    private func height(for index: Int) -> CGFloat {
        // -160 ~ 0 dB -> 0 ~ 1 normalized
        // 보통 -60dB 이상이면 소리 감지
        // Linear scale로 변환
        let minDb: Float = -50
        let level = max(audioLevel, minDb)
        let normalized = CGFloat((level - minDb) / (0 - minDb)) // 0.0 ~ 1.0
        
        // 인덱스별로 약간 다르게 반응하게 하여 파형 느낌 주기
        let randomFactor = CGFloat.random(in: 0.8...1.2) // 약간의 랜덤성
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 30 // Compact height for new layout
        
        // 중앙(index 2)이 가장 크게 움직이고 양옆이 작게
        let positionFactor: CGFloat
        switch index {
        case 0, 4: positionFactor = 0.5
        case 1, 3: positionFactor = 0.8
        default: positionFactor = 1.0
        }
        
        return baseHeight + (maxHeight - baseHeight) * normalized * positionFactor
    }
}

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var navManager: StudyNavigationManager
    @StateObject private var viewModel = TimerViewModel()
    
    // ✨ Shielding 및 Onboarding 상태
    @StateObject private var shieldingManager = ShieldingManager.shared
    @State private var showShieldingPicker = false
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // ✨ 목표 데이터를 가져와 저장 시 연결하기 위함
    @Query(sort: \Goal.targetDate) private var goals: [Goal]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 0. 네비게이션 타이틀과의 겹침 방지 여백 (겹침 문제 해결을 위해 다시 확대)
                Spacer().frame(height: 140)
                
                // 1. 상단 컨트롤 영역 (토글 & 허용 앱)
                HStack(alignment: .center) {
                    // 말하기 모드 토글
                    if !viewModel.isRunning {
                        Toggle(isOn: Binding(
                             get: { viewModel.isSpeakingMode },
                             set: { _ in viewModel.toggleSpeakingMode() }
                        )) {
                            HStack(spacing: 4) {
                                if viewModel.isSpeakingMode {
                                    Text("말하기")
                                        .foregroundColor(.green)
                                        .fontWeight(.bold)
                                } else {
                                    Text("집중")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.subheadline)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        .fixedSize()
                        
                        // 토글 라벨을 직접 옆에 배치하여 레이아웃 제어
                        if viewModel.isSpeakingMode {
                            Text("말하기 모드 ON")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        } else {
                            Text("집중 모드")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                         // 실행 중 상태 표시
                        Label(viewModel.isSpeakingMode ? "말하기 모드" : "집중 모드", systemImage: viewModel.isSpeakingMode ? "mic.fill" : "moon.fill")
                             .font(.caption)
                             .padding(6)
                             .background(viewModel.isSpeakingMode ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                             .foregroundColor(viewModel.isSpeakingMode ? .green : brandColor)
                             .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // 허용 앱 버튼 (Main View로 이동)
                    Button(action: {
                        showShieldingPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                            Text("허용 앱")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(brandColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 3)
                    }
                }
                .padding(.horizontal, 20)
                // .padding(.top, 20) // 상단 여백(Spacer)이 충분하므로 중복 패딩 제거

                // 2. 과목 및 목적 선택 영역
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("공부 과목").font(.caption2).foregroundColor(.gray).padding(.leading, 4)
                        
                        Menu {
                            ForEach(settingsManager.favoriteSubjects) { subject in
                                Button(action: {
                                    viewModel.selectedSubject = subject.name
                                }) {
                                    HStack {
                                        Text(subject.name)
                                        if viewModel.selectedSubject == subject.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            Divider()
                            NavigationLink(destination: SubjectManagementView()) {
                                Label("과목 추가/관리", systemImage: "plus.circle")
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedSubject)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .foregroundColor(SubjectName.color(for: viewModel.selectedSubject))
                                Spacer()
                                Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("공부 목적").font(.caption2).foregroundColor(.gray).padding(.leading, 4)
                        Menu {
                            ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                Button(purpose.localizedName) { viewModel.updateStudyPurpose(purpose) }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.selectedPurpose.localizedName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white).cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .disabled(viewModel.isRunning)
                .opacity(viewModel.isRunning ? 0.6 : 1.0)
                
                // 3. 타이머 시간 표시 영역과의 간격 줄이기 (고정값)
                Spacer().frame(height: 10)
                
                // 3. 타이머 시간 표시 (고정 높이)
                VStack(spacing: 0) {
                    if viewModel.isSpeakingMode {
                        // 말하기 모드: 타이머 + 비주얼라이저 (Compact)
                        Text(viewModel.formatTime(seconds: viewModel.speakingTime))
                            .font(.system(size: 54, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        
                        // 비주얼라이저 (공간 확보)
                        if viewModel.isRunning {
                            AudioVisualizerView(audioLevel: viewModel.audioLevel)
                                .frame(height: 36) // Compact height
                                .padding(.horizontal, 40)
                                .padding(.top, 4)
                        } else {
                            // 실행 중 아닐 때는 대기 텍스트나 빈 공간
                             Text("말하기 감지 대기")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                                .frame(height: 36)
                                .padding(.top, 4)
                        }
                    } else {
                        // 🤫 집중 모드: 타이머 중앙 정렬
                        Text(viewModel.timeString)
                            .font(.system(size: 54, weight: .medium, design: .monospaced))
                            .foregroundColor(viewModel.isRunning ? brandColor : .primary)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .padding(.bottom, 10) // 중앙 정렬 보정
                    }
                }
                .frame(height: 120) // ✨ [Fix] 고정 높이로 흔들림 방지
                .animation(.easeInOut(duration: 0.2), value: viewModel.isSpeakingMode)
                
                Spacer().frame(height: 5) // 시작 버튼을 위로 더 올리기 위해 30 -> 10 축소
                
                // 4. 컨트롤 버튼
                HStack(spacing: 30) {
                    if viewModel.isRunning {
                        Button(action: { viewModel.stopTimer() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "pause.circle.fill").resizable().frame(width: 72, height: 72)
                                Text("일시정지").font(.caption2)
                            }
                        }.foregroundColor(.orange)
                    } else {
                        Button(action: { viewModel.startTimer() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "play.circle.fill").resizable().frame(width: 72, height: 72)
                                Text(viewModel.displayTime > 0 ? "계속하기" : "시작").font(.caption2)
                            }
                        }.foregroundColor(brandColor)
                    }
                    
                    if !viewModel.isRunning && viewModel.displayTime > 0 {
                        Button(action: {
                            let primaryGoal = goals.first { $0.isPrimaryGoal } ?? goals.first
                            viewModel.saveRecord(context: modelContext, ownerID: currentUserId, primaryGoal: primaryGoal)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").resizable().frame(width: 72, height: 72)
                                Text("저장하기").font(.caption2)
                            }
                        }.foregroundColor(.green)
                    }
                }

                // .padding(.bottom, 20) 제거하여 중앙 정렬 유도
                
                Spacer().frame(height: 20) // 하단 고정 높이 20으로 설정하여 최근 기록을 위로 당김
                
                // 5. 최근 기록
                RecentRecordsView(userId: currentUserId).padding(.bottom, 5)
                
                // 6. 하단 여백 확보 (내용을 위로 밀어올림)
                Spacer()
            }
            .background(Color(.systemGray6))
            .navigationTitle("집중 타이머")
            // .toolbar { ... } 제거 (허용 앱 버튼 이동됨)
            .onAppear {
                if viewModel.selectedSubject.isEmpty {
                    viewModel.selectedSubject = settingsManager.favoriteSubjects.first?.name ?? "교직논술"
                }
                if let schedule = navManager.targetSchedule {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
                
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
                
                viewModel.checkAndSavePendingRecord(context: modelContext, ownerID: currentUserId)
            }
            .onChange(of: navManager.targetSchedule) { newSchedule in
                if let schedule = newSchedule {
                    viewModel.applySchedule(schedule)
                    navManager.clearTarget()
                }
            }
            .sheet(isPresented: $showShieldingPicker) {
                VStack {
                    Text("방해 금지 앱 설정")
                        .font(.headline)
                        .padding(.top)
                    Text("타이머 실행 중 제한할 앱을 선택하세요.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom)
                    
                    FamilyActivityPicker(selection: $shieldingManager.discouragedSelection)
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
                hasCompletedOnboarding = true
            }) {
                OnboardingView(isPresented: $showOnboarding)
            }
        }
    }
}

// ✨ [임시 추가] Xcode 프로젝트에 파일이 추가되지 않아 발생하는 오류를 방지하기 위해 여기에 정의합니다.
// 추후 Features/Onboarding/OnboardingView.swift 파일이 프로젝트에 추가되면 이 코드는 삭제해주세요.
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

// MARK: - RecentRecordsView (누락된 뷰 정의 추가)

struct RecentRecordsView: View {
    let userId: String
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        self.userId = userId
        // 해당 유저의 최근 기록 5개만 가져오기
        _records = Query(filter: #Predicate<StudyRecord> { $0.ownerID == userId }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 공부 기록").font(.headline)
                Spacer()
                NavigationLink(destination: StatisticsView(userId: userId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                        Text("통계")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            Group {
                if records.isEmpty {
                    VStack {
                        Text("최근 학습 기록이 없습니다.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(records.prefix(5)) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.areaName).font(.subheadline).bold()
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(formatDuration(record.durationSeconds)).font(.subheadline).bold()
                            }
                            // List row styling to match the previous look as much as possible within a List
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.white)
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteRecord)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden) // Remove default list background
                }
            }
            .frame(height: 280) // [Fix] 높이를 항상 고정하여 상단 UI가 움직이지 않도록 함
        }
    }
    
    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        return "\(hours)시간 \(minutes)분 \(seconds)초"
    }
    
    private func deleteRecord(at offsets: IndexSet) {
        // Since we are showing only the prefix(5) but the query fetches all (sorted),
        // we need to be careful. However, 'records' query returns them in order.
        // The ForEach is over `records.prefix(5)`.
        // The index in offsets corresponds to the index in the prefixed collection.
        
        for index in offsets {
            if index < records.count {
                let recordToDelete = records[index]
                modelContext.delete(recordToDelete)
            }
        }
    }
}
