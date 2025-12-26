import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

struct GoalListView: View {
    @Query private var goals: [Goal]
    
    @State private var showingAddGoalSheet = false
    @State private var showingCharacterDetail = false
    @State private var selectedGoal: Goal?
    
    @State private var todayQuote: Quote = Quote(id: nil, text: "오늘의 명언을 불러오는 중...", author: "")
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var authManager: AuthManager
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
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
                        }
                        .onDelete(perform: deleteGoals)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(authManager.userNickname)님의 D-day")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 15) {
                        NavigationLink(destination: ReportListView(userId: currentUserId)) {
                            Image(systemName: "doc.text.image")
                                .font(.title3).foregroundColor(.blue)
                        }
                        NavigationLink(destination: NoticeListView()) {
                            Image(systemName: "megaphone.fill")
                                .font(.title3).foregroundColor(.orange)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoalSheet = true }) {
                        Image(systemName: "plus").foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            // ✨ [수정됨] 상세 화면에 데이터 전달 (색상, 이름 포함)
            .sheet(item: $selectedGoal) { goal in
                VStack(spacing: 30) {
                    Text("나의 성장 기록").font(.title2).bold().padding(.top, 30)
                    Text(goal.title).font(.headline).foregroundColor(.gray)
                    
                    CharacterView(
                        userId: currentUserId,
                        totalGoalDays: goal.totalDays,
                        characterName: goal.characterName,
                        themeColorName: goal.characterColor
                    )
                    .padding()
                    
                    Spacer()
                }
                .presentationDetents([.medium])
            }
            .onAppear { checkAndLoadDailyQuote() }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active { checkAndLoadDailyQuote() }
            }
        }
    }
    
    // ... (명언 로직은 기존과 동일)
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
    
    @Environment(\.modelContext) private var modelContext
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets { modelContext.delete(goals[index]) }
    }
}

// Subviews
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

// ✨ [수정됨] 색상과 별명이 반영된 목표 카드
struct GoalRow: View {
    let goal: Goal
    let userId: String
    
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
    // 목표별 테마 색상 (Helper 사용)
    var themeColor: Color {
        GoalColorHelper.color(for: goal.characterColor)
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
    
    var dDay: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: goal.targetDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        if let days = components.day {
            if days == 0 { return "D-Day" } else if days > 0 { return "D-\(days)" } else { return "D+\(-days)" }
        }
        return "Error"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.title).font(.title3).fontWeight(.bold).foregroundColor(.white)
                    
                    if goal.hasCharacter {
                        // ✨ 캐릭터 이모지 + 별명 표시
                        HStack(spacing: 4) {
                            Text(currentEmoji)
                            Text(goal.characterName)
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(themeColor) // 텍스트를 테마색으로
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                Text(goal.targetDate, style: .date).font(.caption).foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            
            // D-Day 배지
            Text(dDay)
                .font(.title).fontWeight(.black)
                .foregroundColor(themeColor) // 텍스트를 테마색으로
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(10)
        }
        .padding()
        // ✨ 배경 그라디언트에 테마 색상 적용
        .background(
            LinearGradient(
                gradient: Gradient(colors: [themeColor, themeColor.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
        .shadow(color: themeColor.opacity(0.3), radius: 5, x: 0, y: 5)
        .padding(.vertical, 5)
        .listRowSeparator(.hidden)
    }
}
