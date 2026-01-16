import SwiftUI
import SwiftData
import FirebaseAuth

struct GoalListView: View {
    @Query(sort: \Goal.targetDate) private var rawGoals: [Goal]
    private var goals: [Goal] {
        rawGoals.sorted {
            if $0.isPrimaryGoal != $1.isPrimaryGoal {
                return $0.isPrimaryGoal
            }
            return $0.targetDate < $1.targetDate
        }
    }
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
    @State private var showStorage = false 

    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    private var primaryGoal: Goal? {
        if goals.isEmpty { return nil }
        if let primary = goals.first(where: { $0.isPrimaryGoal && !$0.isDeleted }) {
            return primary
        }
        return goals.first(where: { !$0.isDeleted })
    }
    
    private var practicedSubjectNames: Set<String> {
        Set(todayRecords.map { $0.areaName })
    }
    
    private func getUniqueDays(for goal: Goal) -> Int {
        guard !goal.isDeleted else { return 0 }
        
        let goalRecords = allRecords.filter { record in
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
        
        _rawGoals = Query(filter: #Predicate<Goal> { $0.ownerID == filterId }, sort: \.targetDate)
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
                    characterSection
                    quickMenuSection
                    balanceSection
                    
                    CompactQuoteView(quote: quoteManager.currentQuote)
                        .padding(.horizontal)
                        .onAppear { quoteManager.updateQuoteIfNeeded() }
                    
                    goalListSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(authManager.userNickname)님의 학습 센터")
            .sheet(isPresented: $showStorage) {
                CharacterStorageView()
            }
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
                editGoalAlertActions
            } message: {
                Text("목표의 이름을 변경합니다.")
            }
            // ✨ [추가] 진화 애니메이션 전체 화면 오버레이
            .fullScreenCover(isPresented: $characterManager.showEvolutionAnimation) {
                evolutionOverlay
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                updateWidget()
            }
        }
        // ✨ [추가] 캐릭터 상태 변경 시 위젯 업데이트 (진화/레벨업 반영)
        // UserCharacter struct가 Equatable이어야 정확히 작동하므로 확인 필요하지만,
        // 배열 자체가 변경되면 호출됨.
        .onChange(of: characterManager.characters.map { $0.level }) { _ in
            updateWidget()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var characterSection: some View {
        if let primary = primaryGoal {
            let dDay = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: primary.targetDate)).day ?? 0
            
            MainCharacterView(
                showStorage: $showStorage,
                primaryGoalTitle: primary.title,
                dDay: dDay
            )
        } else {
            MainCharacterView(
                showStorage: $showStorage,
                primaryGoalTitle: "새 목표를 등록해주세요",
                dDay: 0
            )
        }
    }
    
    @ViewBuilder
    private var quickMenuSection: some View {
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
    }
    
    @ViewBuilder
    private var balanceSection: some View {
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
    }
    
    @ViewBuilder
    private var goalListSection: some View {
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
    }
    
    @ViewBuilder
    private var editGoalAlertActions: some View {
        TextField("새로운 목표 이름을 입력하세요", text: $newGoalTitle)
        Button("취소", role: .cancel) {}
        Button("저장") {
            saveGoalTitle()
        }
    }
    
    @ViewBuilder
    private var evolutionOverlay: some View {
        if let character = characterManager.equippedCharacter {
            EvolutionView(
                characterType: character.type,
                characterName: authManager.userNickname,
                themeColorName: primaryGoal?.characterColor ?? "Blue",
                oldLevel: CharacterLevel(rawValue: max(0, character.level - 1)) ?? .lv1,
                newLevel: CharacterLevel(rawValue: character.level) ?? .lv1,
                theme: EvolutionTheme.allCases.randomElement() ?? .fog,
                onCompletion: {
                    characterManager.showEvolutionAnimation = false
                }
            )
        }
    }
    
    // ✨ [추가] 캐릭터 매니저 연동
    @ObservedObject var characterManager = CharacterManager.shared
    
    // MARK: - Methods
    
    private func syncGoals() {
        guard !currentUserId.isEmpty else { return }
        
        if goals.isEmpty {
            Task {
                do {
                    let fetchedGoals = try await GoalManager.shared.fetchGoals(userId: currentUserId)
                    await MainActor.run {
                        for data in fetchedGoals {
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
            // ✨ [수정] 실제 캐릭터 레벨 반영 (위젯 동기화)
            var realLevel = CharacterLevel.getLevel(uniqueDays: uniqueDays).rawValue + 1
            if let character = characterManager.equippedCharacter {
                realLevel = character.level + 1
            }
            
            WidgetDataHelper.shared.updatePrimaryGoal(goal: goal, uniqueDays: uniqueDays, level: realLevel)
        } else {
            WidgetDataHelper.shared.clearData()
        }
    }
    
    private func setPrimaryGoal(_ selectedGoal: Goal) {
        let context = modelContext
        selectedGoal.isPrimaryGoal = true
        
        for goal in goals {
            if goal.id != selectedGoal.id {
                goal.isPrimaryGoal = false
            }
        }
        
        do {
            try context.save()
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
            GoalManager.shared.deleteGoal(goalId: goalId, userId: userId)
            updateWidget()
        } catch {
            print("Error deleting goal: \(error)")
        }
    }
}

// MARK: - 하위 컴포넌트들

struct GoalCardView: View {
    let goal: Goal
    let uniqueDays: Int
    
    var body: some View {
        let themeColor = GoalColorHelper.color(for: goal.characterColor)
        let dDay = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: goal.targetDate)).day ?? 0

        
        HStack(spacing: 16) {
            ZStack {
                // 캐릭터 대신 깃발이나 다른 아이콘 표시
                Circle().fill(themeColor.opacity(0.15)).frame(width: 60, height: 60)
                
                if goal.isPrimaryGoal {
                    // 대표 목표는 별 + 캐릭터 테마 아이콘
                    Image(systemName: "star.fill").font(.system(size: 24)).foregroundColor(.orange)
                } else {
                    // 일반 목표는 깃발
                    Image(systemName: "flag.checkered").font(.system(size: 24)).foregroundColor(themeColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(.headline).foregroundColor(.primary).lineLimit(1)
                
                if goal.isPrimaryGoal {
                    Text("대표 목표").font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(4)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dDay >= 0 ? "D-\(dDay)" : "완료").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(dDay <= 7 ? .red : .primary)
                Text(formatDate(goal.targetDate)).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 18).fill(Color.white).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(goal.isPrimaryGoal ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

struct QuickMenuButton: View {
    let title: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5)
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
