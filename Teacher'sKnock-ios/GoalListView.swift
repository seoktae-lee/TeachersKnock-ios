import SwiftUI
import SwiftData
import FirebaseAuth

struct GoalListView: View {
    // 쿼리는 init에서 설정하므로 여기선 타입만 선언
    @Query private var goals: [Goal]
    
    @State private var showingAddGoalSheet = false
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // ✨ 생성자: 내 ID에 해당하는 데이터만 필터링하도록 설정
    init(userId: String) {
        // ownerID가 현재 userId와 같은 것만 가져오고, 날짜순으로 정렬
        _goals = Query(filter: #Predicate<Goal> { goal in
            goal.ownerID == userId
        }, sort: \.targetDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
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

// 목표 카드 디자인 (이전과 동일)
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
                Text(goal.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(goal.targetDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Text(dDay)
                .font(.title)
                .fontWeight(.black)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [brandColor, brandColor.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 5)
        .padding(.vertical, 5)
        .listRowSeparator(.hidden) // 리스트 구분선 숨기기
    }
}
