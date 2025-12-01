import SwiftUI
import SwiftData
import FirebaseAuth

struct GoalListView: View {
    // 쿼리는 init에서 설정
    @Query private var goals: [Goal]
    
    @State private var showingAddGoalSheet = false
    
    // ✨ 오늘의 명언 상태 변수
    @State private var todayQuote: Quote = Quote(text: "오늘도 힘내세요!", author: "Tino")
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 생성자: 내 ID에 해당하는 데이터만 필터링
    init(userId: String) {
        _goals = Query(filter: #Predicate<Goal> { goal in
            goal.ownerID == userId
        }, sort: \.targetDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✨ 상단 명언 카드 추가
                QuoteCard(quote: todayQuote)
                    .padding()
                
                if goals.isEmpty {
                    ContentUnavailableView {
                        Label("목표가 없습니다", systemImage: "target")
                    } description: {
                        Text("우측 상단 + 버튼을 눌러\n시험 목표를 추가해보세요.")
                    }
                } else {
                    List {
                        ForEach(goals) { goal in
                            GoalRow(goal: goal)
                        }
                        .onDelete(perform: deleteGoals)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("나의 D-day")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoalSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(brandColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            // ✨ 화면이 나타날 때마다 랜덤 명언 교체
            .onAppear {
                todayQuote = QuoteManager.getRandomQuote()
            }
        }
    }
    
    // 데이터 삭제 함수
    @Environment(\.modelContext) private var modelContext
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}

// ✨ 명언 카드 디자인 뷰
struct QuoteCard: View {
    let quote: Quote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            
            Text(quote.text)
                .font(.system(.body, design: .serif)) // 명언 느낌 나는 폰트
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
            
            HStack {
                Spacer()
                Text("- \(quote.author) -")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 3)
    }
}

// 목표 카드 디자인 (기존 유지)
struct GoalRow: View {
    let goal: Goal
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var dDay: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: goal.targetDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        if let days = components.day {
            if days == 0 { return "D-Day" }
            else if days > 0 { return "D-\(days)" }
            else { return "D+\(-days)" }
        }
        return "Error"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title).font(.title3).fontWeight(.bold).foregroundColor(.white)
                Text(goal.targetDate, style: .date).font(.caption).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text(dDay).font(.title).fontWeight(.black).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.2)).cornerRadius(10)
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [brandColor, brandColor.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 5)
        .padding(.vertical, 5)
        .listRowSeparator(.hidden)
    }
}
