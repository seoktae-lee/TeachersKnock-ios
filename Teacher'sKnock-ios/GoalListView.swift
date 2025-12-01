import SwiftUI      // 👈 이게 없어서 'View', 'Color' 오류가 뜸
import SwiftData    // 👈 이게 없어서 'Query', 'Predicate' 오류가 뜸
import FirebaseAuth // 👈 사용자 ID 가져오기용

struct GoalListView: View {
    // 저장된 목표 불러오기 (쿼리는 init에서 설정)
    @Query private var goals: [Goal]
    
    // 상태 변수들
    @State private var showingAddGoalSheet = false
    @State private var showingCharacterDetail = false // 팝업 표시 여부
    @State private var selectedGoal: Goal? // 어떤 목표를 눌렀는지 저장
    @State private var todayQuote: Quote = Quote(text: "로딩 중...", author: "")
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 현재 로그인한 유저 ID
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // 생성자: 내 ID에 해당하는 데이터만 필터링
    init(userId: String) {
        _goals = Query(filter: #Predicate<Goal> { goal in
            goal.ownerID == userId
        }, sort: \.targetDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 상단 명언 카드
                QuoteCard(quote: todayQuote)
                    .padding()
                
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
                            // ✨ 카드를 버튼으로 감싸서 클릭 가능하게 만듦
                            Button(action: {
                                selectedGoal = goal
                                showingCharacterDetail = true
                            }) {
                                GoalRow(goal: goal, userId: currentUserId)
                            }
                            .buttonStyle(.plain) // 리스트 기본 선택 효과 제거
                            .listRowSeparator(.hidden) // 줄 없애기
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
            // 목표 추가 시트
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            // ✨ 캐릭터 상세 정보 팝업
            .sheet(item: $selectedGoal) { goal in
                VStack(spacing: 30) {
                    Text("나의 성장 기록")
                        .font(.title2)
                        .bold()
                        .padding(.top, 30)
                    
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    // 캐릭터 상세 뷰 (사용자 ID 전달)
                    CharacterView(userId: currentUserId)
                        .padding()
                    
                    Spacer()
                }
                .presentationDetents([.medium])
            }
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

// ---------------------------------------------------------
// ✨ 하위 뷰 1: 명언 카드
struct QuoteCard: View {
    let quote: Quote
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "quote.opening").foregroundColor(.white.opacity(0.7)); Spacer() }
            Text(quote.text)
                .font(.system(.body, design: .serif))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
            HStack { Spacer(); Text("- \(quote.author) -").font(.caption).foregroundColor(.white.opacity(0.8)) }
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 3)
    }
}

// ---------------------------------------------------------
// ✨ 하위 뷰 2: 목표 카드 (GoalRow) - 미니 이모지 로직 포함
struct GoalRow: View {
    let goal: Goal
    let userId: String
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 공부 기록과 플래너 기록을 모두 가져옴
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
    init(goal: Goal, userId: String) {
        self.goal = goal
        self.userId = userId
        
        // 타이머 기록 필터링
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        })
        
        // 플래너 기록 필터링
        _scheduleItems = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId
        })
    }
    
    // ✨ 현재 레벨에 맞는 이모지 계산 (타이머 + 플래너)
    var currentEmoji: String {
        let calendar = Calendar.current
        
        // 1. 타이머 날짜
        let timerDays = records.map { calendar.startOfDay(for: $0.date) }
        
        // 2. 플래너 완료 날짜
        let plannerDays = scheduleItems
            .filter { $0.isCompleted }
            .map { calendar.startOfDay(for: $0.startDate) }
        
        // 3. 합산 (중복 제거)
        let uniqueDays = Set(timerDays + plannerDays).count
        
        // 목표 기간 대비 진행률로 이모지 결정
        return CharacterLevel.getLevel(currentDays: uniqueDays, totalGoalDays: goal.totalDays).emoji
    }
    
    // D-day 계산
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
                    
                    // ✨ 캐릭터 육성 옵션이 켜져있을 때만 이모지 표시
                    if goal.hasCharacter {
                        Text(currentEmoji)
                            .font(.title3)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                
                Text(goal.targetDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // D-day 뱃지
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
        .listRowSeparator(.hidden)
    }
}
