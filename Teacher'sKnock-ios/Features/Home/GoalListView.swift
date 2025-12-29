import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

struct GoalListView: View {
    // 날짜순 정렬
    @Query(sort: \Goal.targetDate) private var goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAddGoalSheet = false
    @State private var showingCharacterDetail = false
    @State private var selectedGoal: Goal?
    
    // 명언 상태
    @State private var todayQuote: Quote = Quote(id: nil, text: "오늘의 명언을 불러오는 중...", author: "")
    
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var authManager: AuthManager
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    // 생성자에서 필터링
    init(userId: String) {
        _goals = Query(filter: #Predicate<Goal> { goal in
            goal.ownerID == userId
        }, sort: \.targetDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 15) {
                // 1. 명언 배너
                CompactQuoteView(quote: todayQuote)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // 2. 목표 리스트
                if goals.isEmpty {
                    ContentUnavailableView {
                        Label("목표가 없습니다", systemImage: "target")
                    } description: {
                        Text("우측 상단 + 버튼을 눌러\n시험 목표를 추가해보세요.")
                    }
                } else {
                    List {
                        ForEach(goals) { goal in
                            Button(action: {
                                if goal.hasCharacter {
                                    selectedGoal = goal
                                    showingCharacterDetail = true
                                }
                            }) {
                                GoalRow(goal: goal, userId: currentUserId)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            // 꾹 눌러서 대표 목표 설정
                            .contextMenu {
                                Button {
                                    setPrimaryGoal(goal)
                                } label: {
                                    if goal.isPrimaryGoal {
                                        Label("이미 대표 목표입니다", systemImage: "crown.fill")
                                    } else {
                                        Label("대표 목표로 설정", systemImage: "crown")
                                    }
                                }
                                .disabled(goal.isPrimaryGoal)
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteGoal(goal)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(authManager.userNickname)님의 D-day")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 15) {
                        NavigationLink(destination: ReportListView(userId: currentUserId)) {
                            Image(systemName: "doc.text.image").font(.title3).foregroundColor(brandColor)
                        }
                        NavigationLink(destination: NoticeListView()) {
                            Image(systemName: "megaphone.fill").font(.title3).foregroundColor(.orange)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoalSheet = true }) {
                        Image(systemName: "plus").foregroundColor(brandColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            // ✨ [수정 완료] 이제 에러 안 납니다! (데이터 전달 추가)
            .sheet(item: $selectedGoal) { goal in
                VStack(spacing: 30) {
                    Text("나의 성장 기록").font(.title2).bold().padding(.top, 30)
                    Text(goal.title).font(.headline).foregroundColor(.gray)
                    
                    // ✨ 여기에 필요한 정보를 꽉 채워줍니다
                    CharacterView(
                        userId: currentUserId,
                        totalGoalDays: goal.totalDays,
                        characterName: goal.characterName,
                        themeColorName: goal.characterColor
                    ).padding()
                    
                    Spacer()
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                checkAndLoadDailyQuote()
                if goals.isEmpty {
                    restoreGoalsFromServer()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active { checkAndLoadDailyQuote() }
            }
        }
    }
    
    // MARK: - Logic
    
    private func restoreGoalsFromServer() {
        guard !currentUserId.isEmpty else { return }
        Task {
            do {
                let fetchedGoals = try await GoalManager.shared.fetchGoals(userId: currentUserId)
                if !fetchedGoals.isEmpty {
                    await MainActor.run {
                        for data in fetchedGoals {
                            let goal = Goal(
                                id: data.id,
                                title: data.title,
                                targetDate: data.targetDate,
                                ownerID: data.ownerID,
                                hasCharacter: data.hasCharacter,
                                startDate: data.startDate,
                                characterName: data.characterName,
                                characterColor: data.characterColor,
                                isPrimaryGoal: data.isPrimaryGoal
                            )
                            modelContext.insert(goal)
                        }
                        print("✅ 서버에서 목표 \(fetchedGoals.count)개 복구 완료")
                    }
                }
            } catch {
                print("목표 복구 실패: \(error)")
            }
        }
    }
    
    private func setPrimaryGoal(_ targetGoal: Goal) {
        for g in goals { g.isPrimaryGoal = false }
        targetGoal.isPrimaryGoal = true
        GoalManager.shared.saveGoal(targetGoal)
        for g in goals { if g !== targetGoal { GoalManager.shared.saveGoal(g) } }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func deleteGoal(_ goal: Goal) {
        GoalManager.shared.deleteGoal(goalId: goal.id.uuidString, userId: currentUserId)
        modelContext.delete(goal)
    }
    
    func checkAndLoadDailyQuote() {
        let defaults = UserDefaults.standard
        let todayKey = Date().formatted(date: .numeric, time: .omitted)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isAfternoon = currentHour >= 14
        
        if let savedDate = defaults.string(forKey: "quoteDate"), savedDate == todayKey {
            if isAfternoon {
                let text = defaults.string(forKey: "quotePM_text") ?? "오후도 힘내세요!"
                let author = defaults.string(forKey: "quotePM_author") ?? "T-No"
                self.todayQuote = Quote(id: nil, text: text, author: author)
            } else {
                let text = defaults.string(forKey: "quoteAM_text") ?? "좋은 아침입니다!"
                let author = defaults.string(forKey: "quoteAM_author") ?? "T-No"
                self.todayQuote = Quote(id: nil, text: text, author: author)
            }
        } else {
            QuoteManager.shared.fetchQuote { quote1 in
                let q1 = quote1 ?? Quote(id: nil, text: "오늘 하루도 파이팅!", author: "티노")
                QuoteManager.shared.fetchQuote { quote2 in
                    let q2 = quote2 ?? Quote(id: nil, text: "끝까지 포기하지 마세요!", author: "티노")
                    defaults.set(todayKey, forKey: "quoteDate")
                    defaults.set(q1.text, forKey: "quoteAM_text")
                    defaults.set(q1.author, forKey: "quoteAM_author")
                    defaults.set(q2.text, forKey: "quotePM_text")
                    defaults.set(q2.author, forKey: "quotePM_author")
                    withAnimation { self.todayQuote = isAfternoon ? q2 : q1 }
                }
            }
        }
    }
}

// MARK: - Subviews

struct CompactQuoteView: View {
    let quote: Quote
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening").font(.caption).foregroundColor(.gray.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.text).font(.subheadline).fontWeight(.medium).foregroundColor(.primary.opacity(0.8)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if !quote.author.isEmpty { Text("- \(quote.author)").font(.caption2).foregroundColor(.gray) }
            }
            Spacer()
        }
        .padding(.vertical, 12).padding(.horizontal, 16).background(Color(.systemGray6).opacity(0.5)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct GoalRow: View {
    let goal: Goal
    let userId: String
    
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
    // GoalColorHelper는 AddGoalView 파일에 있는 것을 사용합니다.
    // 만약 찾을 수 없다는 에러가 나면, AddGoalView.swift에 있는 struct GoalColorHelper {...}를 복사해서
    // 이 파일 맨 아래에 붙여넣어주세요.
    var themeColor: Color {
        return GoalColorHelper.color(for: goal.characterColor)
    }
    
    init(goal: Goal, userId: String) {
        self.goal = goal
        self.userId = userId
        _records = Query(filter: #Predicate<StudyRecord> { record in record.ownerID == userId })
        _scheduleItems = Query(filter: #Predicate<ScheduleItem> { item in item.ownerID == userId })
    }
    
    var currentEmoji: String {
        let calendar = Calendar.current
        let timerDays = records.map { calendar.startOfDay(for: $0.date) }
        let plannerDays = scheduleItems.filter { $0.isCompleted }.map { calendar.startOfDay(for: $0.startDate) }
        let uniqueDays = Set(timerDays + plannerDays).count
        return CharacterLevel.getLevel(currentDays: uniqueDays, totalGoalDays: goal.totalDays).emoji
    }
    
    var dDayString: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: goal.targetDate)
        let diff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if diff == 0 { return "D-Day" } else if diff > 0 { return "D-\(diff)" } else { return "D+\(-diff)" }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if goal.isPrimaryGoal {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .shadow(color: .orange.opacity(0.5), radius: 2)
                    }
                    
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text(goal.targetDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if goal.hasCharacter {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(currentEmoji) \(goal.characterName)")
                            .font(.caption).bold()
                            .foregroundColor(.white)
                    }
                }
            }
            
            Spacer()
            
            Text(dDayString)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [themeColor, themeColor.opacity(0.8)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: themeColor.opacity(0.3), radius: 6, x: 0, y: 4)
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
    }
}
