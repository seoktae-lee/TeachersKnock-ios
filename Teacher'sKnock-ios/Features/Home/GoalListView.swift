import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

struct GoalListView: View {
    @Query private var goals: [Goal]
    
    @State private var showingAddGoalSheet = false
    @State private var showingCharacterDetail = false
    @State private var selectedGoal: Goal?
    
    // 리포트 화면 이동 상태
    @State private var showingReportList = false
    
    // ✨ [수정됨] Quote 초기화 시 'id: nil' 추가 (컴파일 에러 해결)
    @State private var todayQuote: Quote = Quote(id: nil, text: "오늘의 명언을 불러오는 중...", author: "")
    
    @EnvironmentObject var authManager: AuthManager
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
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
                
                // 1. 작아진 명언 배너
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
                                selectedGoal = goal
                                showingCharacterDetail = true
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
                // 좌측 상단: 리포트 버튼
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingReportList = true }) {
                        Image(systemName: "doc.text.image")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
                
                // 우측 상단: 목표 추가 버튼
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoalSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(brandColor)
                    }
                }
            }
            .navigationDestination(isPresented: $showingReportList) {
                ReportListView()
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            .sheet(item: $selectedGoal) { goal in
                VStack(spacing: 30) {
                    Text("나의 성장 기록")
                        .font(.title2).bold().padding(.top, 30)
                    Text(goal.title).font(.headline).foregroundColor(.gray)
                    CharacterView(userId: currentUserId).padding()
                    Spacer()
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                checkAndLoadDailyQuote()
            }
        }
    }
    
    // 하루 1회 명언 로직
    func checkAndLoadDailyQuote() {
        let defaults = UserDefaults.standard
        let todayKey = Date().formatted(date: .numeric, time: .omitted)
        
        if let savedDate = defaults.string(forKey: "savedQuoteDate"),
           savedDate == todayKey,
           let savedText = defaults.string(forKey: "savedQuoteText"),
           let savedAuthor = defaults.string(forKey: "savedQuoteAuthor") {
            
            // 저장된 명언 불러오기 (id: nil 추가)
            self.todayQuote = Quote(id: nil, text: savedText, author: savedAuthor)
            
        } else {
            // 새 명언 가져오기
            QuoteManager.shared.fetchQuote { quote in
                if let quote = quote {
                    withAnimation {
                        self.todayQuote = quote
                    }
                    defaults.set(todayKey, forKey: "savedQuoteDate")
                    defaults.set(quote.text, forKey: "savedQuoteText")
                    defaults.set(quote.author, forKey: "savedQuoteAuthor")
                } else {
                    // 실패 시 기본 명언 (id: nil 추가)
                    self.todayQuote = Quote(id: nil, text: "실패는 성공의 어머니이다.", author: "에디슨")
                }
            }
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}

// 명언 뷰 디자인
struct CompactQuoteView: View {
    let quote: Quote
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !quote.author.isEmpty {
                    Text("- \(quote.author)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// GoalRow (기존 유지)
struct GoalRow: View {
    let goal: Goal
    let userId: String
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
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
                        Text(currentEmoji).font(.title3).padding(6).background(Color.white.opacity(0.2)).clipShape(Circle())
                    }
                }
                Text(goal.targetDate, style: .date).font(.caption).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text(dDay).font(.title).fontWeight(.black).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.white.opacity(0.2)).cornerRadius(10)
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [brandColor, brandColor.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(15).shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 5)
        .padding(.vertical, 5).listRowSeparator(.hidden)
    }
}
