import SwiftUI
import SwiftData
import FirebaseAuth
import Charts

struct DailyDetailView: View {
    let date: Date
    let userId: String
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // 쿼리
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    @State private var showingAddSheet = false
    
    // MARK: - 통계 계산
    var totalPlannedCount: Int { schedules.count }
    var completedCount: Int { schedules.filter { $0.isCompleted }.count }
    var achievementRate: Double {
        totalPlannedCount == 0 ? 0 : Double(completedCount) / Double(totalPlannedCount)
    }
    
    var totalStudySeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var studyTimeFormatted: String {
        let h = totalStudySeconds / 3600
        let m = (totalStudySeconds % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> {
            $0.ownerID == userId && $0.date >= start && $0.date < end
        })
    }
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 커스텀 헤더 (날짜 및 네비게이션)
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 2. ✨ [NEW] 일일 요약 대시보드
                        summaryCard
                        
                        // 3. ✨ [NEW] 타임라인 & 리스트 하이브리드
                        if schedules.isEmpty {
                            emptyStateView
                        } else {
                            timelineListView
                        }
                    }
                    .padding(.bottom, 80) // 하단 플로팅 버튼 여백
                }
            }
            
            // 4. 플로팅 추가 버튼
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddScheduleView(selectedDate: date)
        }
    }
    
    // MARK: - Components
    
    var headerView: some View {
        HStack {
            // 날짜 표시
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            // 닫기 버튼 (옵션)
            // DailySwipeView 내부에서 쓰일 땐 굳이 필요 없지만, 독립 실행 시 유용
        }
        .padding()
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.1)), alignment: .bottom)
    }
    
    // ✨ 핵심: 요약 카드
    var summaryCard: some View {
        HStack(spacing: 15) {
            // A. 공부 시간
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("총 공부 시간")
                        .font(.caption).foregroundColor(.gray)
                }
                Text(studyTimeFormatted)
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
            
            // B. 달성률
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.green)
                    Text("계획 달성률")
                        .font(.caption).foregroundColor(.gray)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(Int(achievementRate * 100))")
                        .font(.title2).fontWeight(.bold)
                    Text("%")
                        .font(.caption).fontWeight(.bold).padding(.bottom, 4)
                }
                .foregroundColor(.primary)
                
                // 미니 프로그레스 바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2).fill(Color.green)
                            .frame(width: geo.size.width * achievementRate)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // ✨ 핵심: 타임라인 리스트
    var timelineListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(schedules.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 15) {
                    // 1. 왼쪽 타임라인 줄기
                    VStack(spacing: 0) {
                        Text(item.startDate.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .trailing)
                        
                        // 세로 줄
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .padding(.top, 4)
                            .padding(.leading, 38) // 텍스트 너비 + 여백 고려
                    }
                    
                    // 2. 일정 카드
                    ScheduleRow(item: item, context: modelContext)
                        .padding(.bottom, 15)
                }
                .padding(.horizontal)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.3))
            Text("아직 등록된 일정이 없어요.\n플러스 버튼을 눌러 계획을 세워보세요!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
}

// ✨ 일정 행 컴포넌트 (Swipe Action 및 디자인 개선)
struct ScheduleRow: View {
    let item: ScheduleItem
    let context: ModelContext
    
    // 과목 색상 가져오기 (임시 로직, 실제론 SubjectName enum 활용 추천)
    var subjectColor: Color {
        SubjectName.color(for: item.subject)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 과목 컬러 바
            RoundedRectangle(cornerRadius: 2)
                .fill(subjectColor)
                .frame(width: 4)
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                // 제목 & 체크박스
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .gray : .primary)
                    
                    Spacer()
                    
                    Button(action: toggleComplete) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(item.isCompleted ? .green : .gray.opacity(0.4))
                    }
                }
                
                // 시간 범위 & 과목명
                HStack(spacing: 8) {
                    Label(
                        "\(formatTime(item.startDate)) ~ \(formatTime(item.endDate ?? item.startDate))",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(item.subject)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(subjectColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subjectColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        // 스와이프 액션 (삭제/수정)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: { context.delete(item) }) {
                Label("삭제", systemImage: "trash")
            }
        }
    }
    
    func toggleComplete() {
        withAnimation {
            item.isCompleted.toggle()
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}
