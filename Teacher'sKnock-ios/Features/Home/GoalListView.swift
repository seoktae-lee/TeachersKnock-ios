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
                Text(currentLevel.emoji(for: goal.characterType)).font(.system(size: 32))
                if goal.isPrimaryGoal {
                    Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.orange).padding(4).background(Circle().fill(Color.white)).offset(x: 22, y: -22).shadow(radius: 2)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(.headline).foregroundColor(.primary).lineLimit(1)
                HStack(spacing: 6) {
                    Text("LV.\(currentLevel.rawValue + 1)").font(.caption2).fontWeight(.bold).padding(.horizontal, 6).padding(.vertical, 2).background(themeColor.opacity(0.2)).foregroundColor(themeColor).cornerRadius(4)
                    Text("\(uniqueDays)일째 열공 중").font(.caption2).foregroundColor(.secondary)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(targetOffice) 임용 1차 시험까지").font(.subheadline).bold().foregroundColor(.white.opacity(0.9))
                Text("D-\(dDay)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "graduationcap.fill").font(.system(size: 50)).foregroundColor(.white.opacity(0.3))
        }
        .padding(24).background(LinearGradient(gradient: Gradient(colors: [.blue, Color(red: 0.29, green: 0.54, blue: 0.86)]), startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(20).padding(.horizontal)
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
