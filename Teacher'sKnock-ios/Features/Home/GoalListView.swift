import SwiftUI
import SwiftData
import FirebaseAuth

struct GoalListView: View {
    @Query(sort: \Goal.targetDate) private var goals: [Goal]
    @Query private var todayRecords: [StudyRecord]
    @Query private var allRecords: [StudyRecord]
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject private var quoteManager = QuoteManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddGoalSheet = false
    @State private var selectedPhase: Int = 0
    @State private var showGSchool = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    // ✨ [해결] 계산 시점에서 발생할 수 있는 모든 유효성 검사를 수행합니다.
    private var primaryGoal: Goal? {
        if goals.isEmpty { return nil }
        // 1. 대표 목표가 있고 삭제되지 않았으면 반환
        if let primary = goals.first(where: { $0.isPrimaryGoal && !$0.isDeleted }) {
            return primary
        }
        // 2. 대표 목표가 없으면 첫 번째 유효한 목표 반환
        return goals.first(where: { !$0.isDeleted })
    }
    
    private var practicedSubjectNames: Set<String> {
        Set(todayRecords.map { $0.areaName })
    }
    
    private func getUniqueDays(for goal: Goal) -> Int {
        // goal 인스턴스가 살아있는지 확인
        guard !goal.isDeleted else { return 0 }
        
        let goalRecords = allRecords.filter { record in
            // record.goal 접근 시 크래시 방지: 관계가 nil이거나 삭제된 객체인지 확인
            guard let recordGoal = record.goal,
                  !recordGoal.isDeleted,
                  recordGoal.persistentModelID == goal.persistentModelID else { return false }
            return true
        }
        let days = goalRecords.map { Calendar.current.startOfDay(for: $0.date) }
        return Set(days).count
    }
    
    init(userId: String) {
        let filterId = userId
        let today = Calendar.current.startOfDay(for: Date())
        
        _goals = Query(filter: #Predicate<Goal> { $0.ownerID == filterId }, sort: \.targetDate)
        _todayRecords = Query(filter: #Predicate<StudyRecord> { $0.ownerID == filterId && $0.date >= today })
        _allRecords = Query(filter: #Predicate<StudyRecord> { $0.ownerID == filterId })
    }
    

    // MARK: - Goal Edit State
    @State private var isEditingGoal = false
    @State private var editingGoal: Goal? = nil
    @State private var newGoalTitle = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    DDayBannerView(targetOffice: settingsManager.targetOffice?.rawValue ?? "전국")
                    
                    // ✨ [해결] 목표가 추가되는 순간의 경합을 막기 위해 뷰 구성을 안전하게 감쌉니다.
                    Group {
                        if !goals.isEmpty, let goal = primaryGoal {
                            CharacterView(
                                uniqueDays: getUniqueDays(for: goal),
                                characterName: goal.characterName,
                                themeColorName: goal.characterColor,
                                characterType: goal.characterType,
                                goalTitle: goal.title
                            )
                            .id(goal.id) // 뷰의 고유 식별자 부여로 성급한 재사용 방지
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut, value: goals.count)
                    
                    HStack(spacing: 10) {
                        NavigationLink(destination: ReportListView(userId: currentUserId)) {
                            QuickMenuButton(title: "리포트", icon: "chart.bar.xaxis", color: .purple)
                        }
                        NavigationLink(destination: NoticeListView()) {
                            QuickMenuButton(title: "정보", icon: "megaphone.fill", color: .orange)
                        }
                        Button(action: { showGSchool = true }) {
                            QuickMenuButton(title: "G스쿨", icon: "play.rectangle.fill", color: .blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 과목 밸런스 섹션
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("오늘의 과목 밸런스").font(.headline)
                            Spacer()
                            Picker("단계", selection: $selectedPhase) {
                                Text("1차").tag(0); Text("2차").tag(1)
                            }
                            .pickerStyle(.segmented).frame(width: 110)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                let displaySubjects = (selectedPhase == 0) ? SubjectName.primarySubjects : SubjectName.secondarySubjects
                                ForEach(displaySubjects, id: \.self) { subject in
                                    SubjectStatusChip(
                                        name: subject,
                                        isDone: practicedSubjectNames.contains(subject),
                                        color: SubjectName.color(for: subject)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    CompactQuoteView(quote: quoteManager.currentQuote)
                        .padding(.horizontal)
                        .onAppear { quoteManager.updateQuoteIfNeeded() }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("나의 목표 리스트").font(.title3).bold()
                            Spacer()
                            Button(action: { showingAddGoalSheet = true }) {
                                Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(brandColor)
                            }
                        }
                        .padding(.horizontal)
                        
                        if goals.isEmpty {
                            EmptyGoalView().padding(.horizontal)
                        } else {
                            VStack(spacing: 14) {
                                // ✨ [해결] 인덱스 오류를 막기 위해 id를 명시적으로 사용하고 유효성 검사 추가
                                ForEach(goals) { goal in
                                    if !goal.isDeleted {
                                        GoalCardView(goal: goal, uniqueDays: getUniqueDays(for: goal))
                                            .onTapGesture {
                                                withAnimation(.spring()) { setPrimaryGoal(goal) }
                                            }
                                            .contextMenu {
                                                Button {
                                                    startEditing(goal)
                                                } label: {
                                                    Label("목표 이름 수정", systemImage: "pencil")
                                                }
                                                
                                                Button(role: .destructive) { deleteGoal(goal) } label: {
                                                    Label("목표 삭제", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(authManager.userNickname)님의 학습 센터")
            .sheet(isPresented: $showingAddGoalSheet) { AddGoalView() }
            .sheet(isPresented: $showGSchool) {
                if let url = URL(string: "https://m.g-school.co.kr") {
                    SafariView(url: url).ignoresSafeArea()
                }
            }
            .onAppear {
                syncGoals()
            }
            .alert("목표 이름 수정", isPresented: $isEditingGoal) {
                TextField("새로운 목표 이름을 입력하세요", text: $newGoalTitle)
                Button("취소", role: .cancel) {}
                Button("저장") {
                    saveGoalTitle()
                }
            } message: {
                Text("목표의 이름을 변경합니다.")
            }
        }
        // ✨ [추가] 앱이 백그라운드로 갈 때 위젯 데이터 갱신
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                updateWidget()
            }
        }
    }
    
    // MARK: - Methods
    
    private func syncGoals() {
        guard !currentUserId.isEmpty else { return }
        
        // 로컬 데이터가 없을 때만 서버에서 불러옵니다 (또는 필요에 따라 항상 동기화)
        // 여기서는 앱 재설치 후 복원을 위해 로컬이 비어있으면 시도합니다.
        if goals.isEmpty {
            Task {
                do {
                    let fetchedGoals = try await GoalManager.shared.fetchGoals(userId: currentUserId)
                    await MainActor.run {
                        for data in fetchedGoals {
                            // 중복 체크 (혹시 모르니)
                            if !goals.contains(where: { $0.id == data.id }) {
                                let newGoal = Goal(
                                    id: data.id,
                                    title: data.title,
                                    targetDate: data.targetDate,
                                    ownerID: data.ownerID,
                                    hasCharacter: data.hasCharacter,
                                    startDate: data.startDate,
                                    characterName: data.characterName,
                                    characterColor: data.characterColor,
                                    isPrimaryGoal: data.isPrimaryGoal,
                                    characterType: data.characterType
                                )
                                modelContext.insert(newGoal)
                            }
                        }
                    }
                } catch {
                    print("Goal sync failed: \(error)")
                }
            }
        }
    }
    
    private func startEditing(_ goal: Goal) {
        editingGoal = goal
        newGoalTitle = goal.title
        isEditingGoal = true
    }
    
    private func saveGoalTitle() {
        guard let goal = editingGoal, !newGoalTitle.isEmpty else { return }
        
        goal.title = newGoalTitle
        do {
            try modelContext.save()
            GoalManager.shared.updateGoalTitle(goalId: goal.id.uuidString, userId: currentUserId, newTitle: newGoalTitle)
        } catch {
            print("Error saving goal title: \(error)")
        }
        
        editingGoal = nil
        isEditingGoal = false
    }

    
    private func updateWidget() {
        if let goal = primaryGoal {
            let uniqueDays = getUniqueDays(for: goal)
            WidgetDataHelper.shared.updatePrimaryGoal(goal: goal, uniqueDays: uniqueDays)
        } else {
            WidgetDataHelper.shared.clearData()
        }
    }
    
    private func setPrimaryGoal(_ selectedGoal: Goal) {
        let context = modelContext
        // 현재 선택된 목표를 대표로 설정
        selectedGoal.isPrimaryGoal = true
        
        // 나머지 목표들의 isPrimaryGoal 해제
        for goal in goals {
            if goal.id != selectedGoal.id {
                goal.isPrimaryGoal = false
            }
        }
        
        do {
            try context.save()
            // ✨ [추가] 위젯 데이터 즉시 갱신
            updateWidget()
        } catch {
            print("Error saving primary goal: \(error)")
        }
    }

    private func deleteGoal(_ goal: Goal) {
        let goalId = goal.id.uuidString
        let userId = goal.ownerID
        
        modelContext.delete(goal)
        do {
            try modelContext.save()
            // ✨ [수정] 서버 동기화 추가
            GoalManager.shared.deleteGoal(goalId: goalId, userId: userId)
            // ✨ [추가] 위젯 데이터 갱신 (삭제 후 다음 대표 목표 찾기)
            updateWidget()
        } catch {
            print("Error deleting goal: \(error)")
        }
    }
}
// ... (하단 컴포넌트들: GoalCardView, DDayBannerView, QuickMenuButton 등은 기존과 동일)
// MARK: - 하위 컴포넌트들

struct GoalCardView: View {
    let goal: Goal
    let uniqueDays: Int
    
    var body: some View {
        let themeColor = GoalColorHelper.color(for: goal.characterColor)
        let dDay = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: goal.targetDate)).day ?? 0
        let currentLevel = CharacterLevel.getLevel(uniqueDays: uniqueDays)
        
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(themeColor.opacity(0.15)).frame(width: 60, height: 60)
                // ✨ [수정] 캐릭터 키우기 설정이 된 경우에만 캐릭터 표시
                if goal.hasCharacter {
                    Text(currentLevel.emoji(for: goal.characterType)).font(.system(size: 32))
                } else {
                    Image(systemName: "flag.checkered").font(.system(size: 24)).foregroundColor(themeColor)
                }
                
                if goal.isPrimaryGoal {
                    Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.orange).padding(4).background(Circle().fill(Color.white)).offset(x: 22, y: -22).shadow(radius: 2)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(.headline).foregroundColor(.primary).lineLimit(1)
                HStack(spacing: 6) {
                    // ✨ [수정] 캐릭터가 없으면 레벨 표시 숨김 또는 다른 문구 표시
                    if goal.hasCharacter {
                        Text("LV.\(currentLevel.rawValue + 1)").font(.caption2).fontWeight(.bold).padding(.horizontal, 6).padding(.vertical, 2).background(themeColor.opacity(0.2)).foregroundColor(themeColor).cornerRadius(4)
                        Text("\(uniqueDays)일째 열공 중").font(.caption2).foregroundColor(.secondary)
                    } else {
                        Text("\(uniqueDays)일째 도전 중").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dDay >= 0 ? "D-\(dDay)" : "완료").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(dDay <= 7 ? .red : .primary)
                Text(formatDate(goal.targetDate)).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 18).fill(Color.white).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(goal.isPrimaryGoal ? themeColor.opacity(0.3) : Color.clear, lineWidth: 2))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

struct DDayBannerView: View {
    let targetOffice: String
    private let examDate: Date = {
        var components = DateComponents(); components.year = 2026; components.month = 11; components.day = 14
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    var body: some View {
        let dDay = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: examDate)).day ?? 0
        ZStack {
            // 배경 그라데이션
            LinearGradient(gradient: Gradient(colors: [.blue, Color(red: 0.29, green: 0.54, blue: 0.86)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            
            // 은은한 배경 로고 (확대 및 우측 배치)
            HStack {
                Spacer()
                Image("TeachersKnockLogo")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180) // 로고 대폭 확대
                    .rotationEffect(.degrees(-20)) // ✨ [추가] 살짝 기울여 생동감 부여
                    .foregroundColor(.white.opacity(0.15)) // 은은하게 처리
                    .offset(x: 40, y: 30) // 우측 하단으로 치우치게 배치
            }
            
            // 전경 텍스트 내용
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(targetOffice) 임용 1차 시험까지").font(.subheadline).bold().foregroundColor(.white.opacity(0.9))
                    Text("D-\(dDay)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(.white)
                }
                Spacer()
            }
            .padding(24)
        }
        .frame(height: 120) // 높이 고정 (선택 사항, 내부 컨텐츠에 따라 조절 가능)
        .cornerRadius(20)
        .clipped() // 영역을 벗어나는 로고 잘라내기
        .padding(.horizontal)
    }
}

struct QuickMenuButton: View {
    let title: String; let icon: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
            Spacer()
        }
        .padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(15).shadow(color: .black.opacity(0.03), radius: 5)
    }
}

struct SubjectStatusChip: View {
    let name: String; let isDone: Bool; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(isDone ? color : Color.white).frame(width: 58, height: 58).shadow(color: .black.opacity(0.05), radius: 2)
                if isDone { Image(systemName: "checkmark").foregroundColor(.white).fontWeight(.bold) }
                else { Text(name.prefix(1)).foregroundColor(color.opacity(0.6)).font(.system(size: 18, weight: .bold)) }
            }
            Text(name).font(.system(size: 11, weight: isDone ? .bold : .medium)).foregroundColor(isDone ? .primary : .gray)
        }
    }
}

struct CompactQuoteView: View {
    let quote: Quote
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.opening").font(.system(size: 14)).foregroundColor(.blue.opacity(0.3))
            Text(quote.text).font(.system(size: 15, weight: .medium, design: .serif)).italic().multilineTextAlignment(.center)
            Text("- \(quote.author) -").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(24).frame(maxWidth: .infinity).background(Color.white).cornerRadius(20).shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

struct EmptyGoalView: View {
    var body: some View {
        Text("아직 설정된 목표가 없습니다.").font(.caption).padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(15)
    }
}
