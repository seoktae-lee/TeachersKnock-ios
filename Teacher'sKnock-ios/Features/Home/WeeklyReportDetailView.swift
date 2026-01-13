import SwiftUI
import SwiftData
import Charts
import FirebaseAuth

struct WeeklyReportDetailView: View {
    let title: String
    let startDate: Date
    let endDate: Date
    let userId: String
    
    // 렉 방지를 위해 @Query 대신 @State 사용
    @State private var records: [StudyRecord] = []
    @State private var schedules: [ScheduleItem] = []
    @State private var previousRecords: [StudyRecord] = [] // ✨ [추가] 지난주 데이터 (AI 분석용)
    @Environment(\.modelContext) private var modelContext
    
    // 차트용 데이터 구조체
    struct ChartData: Identifiable {
        let id = UUID()
        let label: String
        let seconds: Int
        var color: Color
    }
    
    // ✨ [추가] 차트 탭 상태
    @State private var currentChartTab = 0
    
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. 통합 헤더 (요약 + AI 코치)
                AIAnalysisView(
                    totalSeconds: totalSeconds,
                    mvpSubject: pieData.first.map { ($0.label, $0.color) },
                    records: records,
                    previousRecords: previousRecords,
                    title: "주간 분석"
                )
                .padding(.horizontal)
                
                Divider()
                
                // 3. ✨ [이동됨] 과목 비중 파이 차트 & 레이더 차트 (스와이프)
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text(currentChartTab == 0 ? "과목별 비중" : "과목 밸런스")
                                .font(.headline)
                            Spacer()
                            // 인디케이터 (점)
                            HStack(spacing: 6) {
                                Circle().fill(currentChartTab == 0 ? Color.blue : Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                                Circle().fill(currentChartTab == 1 ? Color.blue : Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal)
                        
                        TabView(selection: $currentChartTab) {
                            // 1. 파이 차트
                            VStack {
                                Chart(pieData) { item in
                                    SectorMark(
                                        angle: .value("시간", item.seconds),
                                        innerRadius: .ratio(0.55),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(item.color)
                                    .annotation(position: .overlay) {
                                        let percent = Double(item.seconds) / Double(totalSeconds) * 100
                                        if percent >= 5 { // 5% 이상만 표시
                                            Text(String(format: "%.0f%%", percent))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .shadow(color: .black.opacity(0.3), radius: 1)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                            .tag(0)
                            
                            // 2. 레이더 차트
                            VStack {
                                RadarChartView(records: records)
                            }
                            .tag(1)
                        }
                        .frame(height: 300) // 탭뷰 높이 확보
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        
                        // 하단 범례 (공통)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(pieData) { item in
                                HStack(spacing: 4) {
                                    Circle().fill(item.color).frame(width: 8, height: 8)
                                    Text(item.label).font(.caption).lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 10)
                }
                
                Divider()
                
                // 4. ✨ [이동됨] 일별 상세 기록 리스트
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("일별 상세 기록")
                            .font(.headline)
                        Spacer()
                        Text("날짜를 누르면 플래너로 이동")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(getDaysInWeek(), id: \.self) { date in
                            NavigationLink(destination: DailyDetailView(date: date, userId: currentUserId)) {
                                // ✨ 새로 디자인된 Row 사용
                                DailyPerformanceRow(
                                    date: date,
                                    schedules: getSchedules(for: date),
                                    records: getRecords(for: date)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Deleted Chart Section (Moved Up)
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
        // 화면 진입 시 데이터 로드 (렉 방지)
        .task {
            fetchData()
        }
    }
    
    // MARK: - Data Loading
    private func fetchData() {
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate<ScheduleItem> { $0.ownerID == userId }
        )
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate<StudyRecord> { $0.ownerID == userId }
        )
        
        do {
            let allS = try modelContext.fetch(scheduleDescriptor)
            let allR = try modelContext.fetch(recordDescriptor)
            
            // endDate 다음날 0시 직전까지 포함
            let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            
            self.schedules = allS.filter { $0.startDate >= startDate && $0.startDate < rangeEnd }
            self.records = allR.filter { $0.date >= startDate && $0.date < rangeEnd }
            
            // ✨ [추가] 지난주 데이터 로드 (7일 전)
            let prevStartDate = Calendar.current.date(byAdding: .day, value: -7, to: startDate)!
            let prevEndDate = startDate // 이번주 시작일 = 지난주 종료일 (exclusive)
            
            self.previousRecords = allR.filter { $0.date >= prevStartDate && $0.date < prevEndDate }
            
        } catch {
            print("리포트 데이터 로드 실패: \(error)")
        }
    }
    
    // MARK: - Helpers & Computed Properties
    
    private var totalSeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { ChartData(label: $0.key, seconds: $0.value, color: SubjectName.color(for: $0.key)) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    // deleted dailyChartData
    
    private func getDaysInWeek() -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        return days
    }
    
    private func getSchedules(for date: Date) -> [ScheduleItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return schedules.filter { $0.startDate >= start && $0.startDate < end }
    }
    
    private func getRecords(for date: Date) -> [StudyRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return records.filter { $0.date >= start && $0.date < end }
    }
    

}

// ✨ [업그레이드 완료] 세련된 일별 리포트 버튼 (DailyPerformanceRow)
struct DailyPerformanceRow: View {
    let date: Date
    let schedules: [ScheduleItem]
    let records: [StudyRecord]
    
    // 계산 로직
    var completedCount: Int { schedules.filter { $0.isCompleted }.count }
    var totalCount: Int { schedules.count }
    var progress: CGFloat { totalCount == 0 ? 0 : CGFloat(completedCount) / CGFloat(totalCount) }
    var totalStudyTime: Int { records.reduce(0) { $0 + $1.durationSeconds } }
    
    // 컬러 로직 (100% 달성 시 초록색 강조)
    var isPerfect: Bool { totalCount > 0 && completedCount == totalCount }
    var statusColor: Color {
        if isPerfect { return .green }      // 완벽
        if totalCount == 0 { return .gray } // 일정 없음
        return .blue                        // 진행 중
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. 날짜 (캘린더 뱃지 스타일)
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(isPerfect ? .white : .gray)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(isPerfect ? .white : .primary)
            }
            .frame(width: 44, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPerfect ? Color.green.opacity(0.8) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPerfect ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
            )
            
            // 2. 일정 진행바 & 텍스트
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if totalCount == 0 {
                        Text("일정 없음")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(isPerfect ? "목표 달성! 🎉" : "할 일 \(completedCount)/\(totalCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                    Spacer()
                }
                
                // 슬림한 프로그레스 바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.1))
                        
                        if totalCount > 0 {
                            Capsule()
                                .fill(statusColor)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                }
                .frame(height: 5)
                
                // ✨ [추가] 주요 과목 (Top 3)
                if !records.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(topSubjects, id: \.name) { subject in
                            Text(subject.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(subject.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(subject.color.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            // 3. 공부 시간 (우측 정렬)
            VStack(alignment: .trailing, spacing: 2) {
                if totalStudyTime > 0 {
                    Text(formatTime(totalStudyTime))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("학습 시간")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text("-")
                        .font(.headline)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .frame(width: 60, alignment: .trailing)
            
            // 4. 화살표
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.05), lineWidth: 1)
        )
    }
    
    // ✨ [추가] 과목 계산 로직 (상위 3개)
    private var topSubjects: [(name: String, color: Color)] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.sorted { $0.value > $1.value }
            .prefix(3)
            .map { (name: $0.key, color: SubjectName.color(for: $0.key)) }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}
