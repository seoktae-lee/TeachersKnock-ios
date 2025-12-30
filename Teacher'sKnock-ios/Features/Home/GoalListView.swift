import SwiftUI
import SwiftData
import FirebaseAuth

struct GoalListView: View {
    @Query(sort: \Goal.targetDate) private var goals: [Goal]
    @Query private var todayRecords: [StudyRecord]
    @Query private var allRecords: [StudyRecord]
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    // ✨ [추가] 닉네임을 가져오기 위한 AuthManager 연동
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject private var quoteManager = QuoteManager.shared
    @State private var showingAddGoalSheet = false
    @State private var selectedPhase: Int = 0
    
    // ✨ [추가] G스쿨 브라우저 시트 제어 변수
    @State private var showGSchool = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    private var primaryGoal: Goal? {
        goals.first { $0.isPrimaryGoal && $0.hasCharacter } ?? goals.first { $0.hasCharacter }
    }
    
    private var practicedSubjectNames: Set<String> {
        Set(todayRecords.map { $0.areaName })
    }
    
    private func getUniqueDays(for goal: Goal) -> Int {
        let goalRecords = allRecords.filter { $0.goal?.id == goal.id }
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
                    // 상단 D-Day 배너
                    DDayBannerView(targetOffice: settingsManager.targetOffice?.rawValue ?? "전국")
                    
                    // 메인 캐릭터 영역
                    if let goal = primaryGoal {
                        CharacterView(
                            uniqueDays: getUniqueDays(for: goal),
                            characterName: goal.characterName,
                            themeColorName: goal.characterColor,
                            characterType: goal.characterType,
                            goalTitle: goal.title
                        )
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    // ✨ [수정] 3개로 구성된 퀵 메뉴 버튼 (리포트 / 정보 / G스쿨)
                    HStack(spacing: 10) {
                        NavigationLink(destination: ReportListView(userId: currentUserId)) {
                            QuickMenuButton(title: "리포트", icon: "chart.bar.xaxis", color: .purple)
                        }
                        
                        NavigationLink(destination: NoticeListView()) {
                            QuickMenuButton(title: "정보", icon: "megaphone.fill", color: .orange)
                        }
                        
                        // G스쿨 바로가기 (SafariView 연결)
                        Button(action: { showGSchool = true }) {
                            QuickMenuButton(title: "G스쿨", icon: "play.rectangle.fill", color: .blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 오늘의 과목 밸런스 섹션
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
                    
                    // 명언 섹션
                    CompactQuoteView(quote: quoteManager.currentQuote)
                        .padding(.horizontal)
                        .onAppear {
                            quoteManager.updateQuoteIfNeeded()
                        }
                    
                    // 나의 목표 리스트 섹션
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
                            VStack(spacing: 12) {
                                ForEach(goals) { goal in
                                    OldStyleGoalCardView(goal: goal, uniqueDays: getUniqueDays(for: goal))
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
                            .padding(.horizontal)
                        }
                    }
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            // ✨ [수정] 닉네임 + 학습 센터 타이틀 적용
            .navigationTitle("\(authManager.userNickname)님의 학습 센터")
            .sheet(isPresented: $showingAddGoalSheet) { AddGoalView() }
            // ✨ [추가] G스쿨 모바일 웹 뷰 시트
            .sheet(isPresented: $showGSchool) {
                if let url = URL(string: "https://m.g-school.co.kr") {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    private func setPrimaryGoal(_ selectedGoal: Goal) {
        for goal in goals { goal.isPrimaryGoal = (goal.id == selectedGoal.id) }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        try? modelContext.save()
    }
}

// MARK: - 하위 컴포넌트

struct DDayBannerView: View {
    let targetOffice: String
    private let examDate: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 14
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
        .padding(24)
        .background(LinearGradient(gradient: Gradient(colors: [.blue, Color(red: 0.29, green: 0.54, blue: 0.86)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20).padding(.horizontal)
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

struct OldStyleGoalCardView: View {
    let goal: Goal; let uniqueDays: Int
    var body: some View {
        let themeColor = GoalColorHelper.color(for: goal.characterColor)
        let dDay = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: goal.targetDate)).day ?? 0
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(themeColor.opacity(goal.isPrimaryGoal ? 0.2 : 0.1)).frame(width: 50, height: 50)
                Text(CharacterLevel.getLevel(uniqueDays: uniqueDays).emoji(for: goal.characterType))
            }
            VStack(alignment: .leading) {
                Text(goal.title).font(.headline)
                Text(dDay >= 0 ? "D-\(dDay)" : "완료").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            if goal.isPrimaryGoal { Image(systemName: "star.fill").foregroundColor(.orange) }
        }
        .padding().background(Color.white).cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(goal.isPrimaryGoal ? themeColor : Color.clear, lineWidth: 1.5))
    }
}

struct EmptyGoalView: View {
    var body: some View {
        Text("아직 설정된 목표가 없습니다.").font(.caption).padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(15)
    }
}
