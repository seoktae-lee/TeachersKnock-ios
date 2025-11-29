import SwiftUI
import SwiftData

// D-day 목표를 보여주고 관리하는 뷰입니다.
struct GoalListView: View {
    // 💡 SwiftData에서 저장된 모든 Goal 모델을 자동으로 불러옵니다.
    @Query(sort: \Goal.targetDate, order: .forward) private var goals: [Goal]
    
    // 새 목표 추가 화면을 띄울지 결정하는 상태 변수
    @State private var showingAddGoalSheet = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        // NavigationStack을 사용하여 상단에 제목과 버튼을 배치합니다.
        NavigationStack {
            
            // 목표가 없을 때 보여줄 화면
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("D-day 목표 없음", systemImage: "target")
                } description: {
                    Text("새 목표를 추가하여 임용고시 D-day를 설정하세요.")
                } actions: {
                    Button("목표 추가") {
                        showingAddGoalSheet = true
                    }
                }
            } else {
                // 목표가 있을 때 목록을 보여줍니다.
                List {
                    ForEach(goals) { goal in
                        // D-day 카운터와 목표 제목을 표시하는 셀
                        GoalRow(goal: goal)
                    }
                    .onDelete(perform: deleteGoals)
                }
                .listStyle(.plain) // 목록 스타일을 깔끔하게 변경
            }
        }
        // 상단 네비게이션 바 설정
        .navigationTitle("나의 D-day 목표")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton() // 목록 편집 버튼
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // 새 목표 추가 버튼
                Button(action: {
                    showingAddGoalSheet = true
                }) {
                    Label("Add Item", systemImage: "plus")
                        .foregroundColor(brandColor)
                }
            }
        }
        // 새 목표 추가 시 띄울 모달 화면
        .sheet(isPresented: $showingAddGoalSheet) {
            AddGoalView() // ✨ 방금 만든 화면 연결
        }
    }
    
    // 목표 삭제 함수
    private func deleteGoals(offsets: IndexSet) {
        // 이 함수는 P2-2 단계에서 SwiftData 코드를 추가하여 완성합니다.
        // 현재는 삭제 로직이 비어있습니다.
    }
}


// 목표 목록의 각 행을 보여주는 보조 뷰 (GoalListView 안에 추가해도 됨)
struct GoalRow: View {
    @Bindable var goal: Goal
    
    // 목표 날짜까지 남은 일수를 계산하는 함수
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: goal.targetDate)
        
        // 날짜 간의 차이를 일수로 계산
        if let days = calendar.dateComponents([.day], from: today, to: target).day {
            // 당일 포함을 위해 1일 추가
            return days
        }
        return 0
    }
    
    var body: some View {
        HStack {
            // D-day 뱃지
            VStack(alignment: .leading) {
                Text(goal.title)
                    .font(.headline)
                Text(goal.targetDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // D-day 카운터
            Text("D\(daysRemaining <= 0 ? "-Day" : "-\(daysRemaining)")")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(daysRemaining <= 0 ? .red : .blue)
        }
    }
}

#Preview {
    GoalListView()
        // Preview를 위해 MainTabView의 EnvironmentObject를 제공합니다.
        .environmentObject(AuthManager())
}
