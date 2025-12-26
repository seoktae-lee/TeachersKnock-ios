import SwiftUI
import SwiftData
import FirebaseAuth
import Charts // 차트 기능을 위해 추가 (iOS 16+)

struct DailyDetailView: View {
    let date: Date
    let userId: String
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // 쿼리: 해당 날짜의 스케줄과 타이머 기록을 다 가져옴
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    @State private var showingAddSheet = false
    
    // MARK: - 통계 데이터 계산
    var totalPlannedCount: Int { schedules.count }
    var completedCount: Int { schedules.filter { $0.isCompleted }.count }
    var achievementRate: Double {
        totalPlannedCount == 0 ? 0 : Double(completedCount) / Double(totalPlannedCount)
    }
    
    // 오늘의 실제 총 공부 시간 (초)
    var totalStudySeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let start = Calendar.current.startOfDay(for: date)
        // 빌드 안전성 확보
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        
        // 쿼리 초기화
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> {
            $0.ownerID == userId && $0.date >= start && $0.date < end
        })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. 날짜 헤더
                HStack {
                    VStack(alignment: .leading) {
                        Text(date.formatted(.dateTime.month().day()))
                            .font(.largeTitle).fontWeight(.heavy)
                        Text(date.formatted(.dateTime.weekday(.wide)))
                            .font(.headline).foregroundColor(.gray)
                    }
                    Spacer()
                    
                    // 총 공부 시간 뱃지
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill").foregroundColor(.orange)
                        Text(formatTime(totalStudySeconds))
                            .font(.title3).fontWeight(.bold).monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                // 2. 학습 대시보드 (달성률 링 차트)
                HStack(spacing: 20) {
                    // 왼쪽: 링 차트
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 15)
                        Circle()
                            .trim(from: 0, to: achievementRate)
                            .stroke(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(dampingFraction: 0.6), value: achievementRate)
                        
                        VStack {
                            Text("\(Int(achievementRate * 100))%")
                                .font(.title).fontWeight(.bold)
                            Text("달성률").font(.caption).foregroundColor(.gray)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .padding(.leading)
                    
                    // 오른쪽: 요약 정보 text
                    VStack(alignment: .leading, spacing: 10) {
                        StatisticRow(icon: "list.bullet.clipboard", color: .blue, title: "총 계획", value: "\(totalPlannedCount)개")
                        StatisticRow(icon: "checkmark.circle.fill", color: .green, title: "완료함", value: "\(completedCount)개")
                        StatisticRow(icon: "xmark.circle.fill", color: .gray, title: "미완료", value: "\(totalPlannedCount - completedCount)개")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // 3. 과목별 밸런스 바 (간단 버전)
                // (추후 구현 가능: 과목별로 색깔 다르게 해서 가로 막대 채우기)
                
                // 4. 오늘의 스케줄 리스트
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Time Table")
                            .font(.title2).fontWeight(.bold)
                        Spacer()
                        NavigationLink(destination: AddScheduleView(selectedDate: date)) {
                            HStack {
                                Image(systemName: "plus")
                                Text("일정 추가")
                            }
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                    
                    if schedules.isEmpty {
                        ContentUnavailableView("일정이 없습니다", systemImage: "calendar.badge.plus", description: Text("새로운 계획을 세워보세요!"))
                            .padding(.top, 30)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(schedules) { item in
                                EnhancedScheduleRow(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 시간 포맷함수 (초 -> 00:00)
    func formatTime(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return String(format: "%d시간 %d분", h, m) }
        else { return String(format: "%d분", m) }
    }
    
    private func deleteSchedule(item: ScheduleItem) {
        modelContext.delete(item)
    }
}

// MARK: - 통계 행 컴포넌트
// MARK: - 통계 행 컴포넌트
struct StatisticRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title).font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
    }
}

// MARK: - 향상된 스케줄 행 (Enhanced Schedule Row)
struct EnhancedScheduleRow: View {
    let item: ScheduleItem
    @Environment(\.modelContext) var context
    
    // 과목별 색상 매핑 (안전하게)
    var subjectColor: Color {
        // SubjectName에 정의된 색상이 있다면 쓰고, 없으면 해시값 기반으로 랜덤 파스텔 생성
        return Color.blue // TODO: SubjectName 연동 시 수정
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // 1. 과목 컬러 바 (왼쪽)
            RoundedRectangle(cornerRadius: 2)
                .fill(subjectColor)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            // 2. 체크박스
            Button(action: {
                withAnimation {
                    item.isCompleted.toggle()
                    try? context.save()
                }
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            
            // 3. 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body).fontWeight(.medium)
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundColor(item.isCompleted ? .gray : .primary)
                
                HStack(spacing: 6) {
                    // 시간 표시
                    Image(systemName: "clock").font(.caption2)
                    Text("\(formatDate(item.startDate)) ~ \(formatDate(item.endDate ?? item.startDate))")
                        .font(.caption)
                    
                    // 과목 태그
                    Text(item.subject)
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subjectColor.opacity(0.1))
                        .foregroundColor(subjectColor)
                        .cornerRadius(4)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 4. 우측 메뉴 (더보기) -> 삭제/수정 등등
            Menu {
                // 완료 토글
                Button(action: {
                    withAnimation {
                        item.isCompleted.toggle()
                        try? context.save()
                    }
                }) {
                    Label(item.isCompleted ? "완료 취소" : "완료하기", systemImage: "checkmark")
                }
                
                Divider()
                
                // 미루기
                Menu("미루기") {
                    Button("1시간 뒤로") { postpone(1) }
                    Button("내일 이 시간으로") { postponeToTomorrow() }
                }
                
                Divider()
                
                Button(role: .destructive, action: { context.delete(item) }) {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(10)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm" // 오전/오후 시간
        return f.string(from: date)
    }

    // MARK: - Helper Methods
    func postpone(_ hours: Int) {
        item.startDate = item.startDate.addingTimeInterval(TimeInterval(hours * 3600))
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(TimeInterval(hours * 3600))
        }
        try? context.save()
    }
    
    func postponeToTomorrow() {
        item.startDate = item.startDate.addingTimeInterval(86400)
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(86400)
        }
        try? context.save()
    }
}
