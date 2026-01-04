import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var records: [StudyRecord]
    
    let userId: String
    
    // 통계 모드 상태
    enum StatMode {
        case today
        case total
    }
    @State private var selectedMode: StatMode = .today
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    init(userId: String) {
        self.userId = userId
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    // MARK: - Data Models
    
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    struct DailyStudyData: Identifiable {
        let id = UUID()
        let date: Date
        let totalSeconds: Int
        let primarySubject: String // 가장 많이 공부한 과목
    }
    
    // MARK: - Computed Properties
    
    var todaySeconds: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 오늘의 과목별 데이터
    var todaySubjectData: [SubjectData] {
        let calendar = Calendar.current
        let targetRecords = records.filter { calendar.isDateInToday($0.date) }
        return processSubjectData(from: targetRecords)
    }
    
    // 전체 과목별 데이터
    var totalSubjectData: [SubjectData] {
        return processSubjectData(from: records)
    }
    
    // 날짜별 기록 데이터 (전체 모드용)
    var dailyHistoryData: [DailyStudyData] {
        let calendar = Calendar.current
        // 날짜별 그룹화
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        
        return grouped.map { (date, dailyRecords) in
            let total = dailyRecords.reduce(0) { $0 + $1.durationSeconds }
            // 가장 많이 공부한 과목 찾기
            let subjects = Dictionary(grouping: dailyRecords, by: { $0.areaName })
            let primary = subjects.max(by: {
                $0.value.reduce(0, { $0 + $1.durationSeconds }) < $1.value.reduce(0, { $0 + $1.durationSeconds })
            })?.key ?? "알 수 없음"
            
            return DailyStudyData(date: date, totalSeconds: total, primarySubject: primary)
        }.sorted { $0.date > $1.date } // 최신순 정렬
    }
    
    // 월별 그룹화 데이터 (전체 모드용)
    var monthlyHistoryData: [(month: String, days: [DailyStudyData])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dailyHistoryData) { item in
            let components = calendar.dateComponents([.year, .month], from: item.date)
            return calendar.date(from: components)!
        }
        
        return grouped.map { (date, items) in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 M월"
            return (month: formatter.string(from: date), days: items)
        }.sorted { $0.month > $1.month } // 최신 월 순서
    }
    
    // 최근 7일 데이터 (차트용)
    var recentWeeklyData: [DailyStudyData] {
        let history = dailyHistoryData
        // 최근 7일 (오늘 포함) 필터링
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 날짜가 없어도 0으로 채워넣기 위해 7일치 빈 배열 생성
        var result: [DailyStudyData] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            if let existing = history.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                result.append(existing)
            } else {
                result.append(DailyStudyData(date: date, totalSeconds: 0, primarySubject: "-"))
            }
        }
        return result.reversed() // 차트는 과거 -> 현재 순서로 그려야 하므로 뒤집기
    }
    
    // Helper
    func processSubjectData(from records: [StudyRecord]) -> [SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)시간 \(m)분"
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
    
    // ✨ [New] 차트 X축 날짜 포맷 (MM.dd)
    func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // MARK: - Header Buttons
                HStack(spacing: 15) {
                    modeButton(mode: .today, title: "오늘 공부", time: todaySeconds)
                    modeButton(mode: .total, title: "총 누적", time: totalSecondsAll)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if selectedMode == .today {
                    if !todaySubjectData.isEmpty {
                        PieChartView(data: todaySubjectData, title: "오늘 과목별 비중")
                        SubjectListView(data: todaySubjectData, title: "오늘 상세 기록", userId: userId, targetDate: Date())
                    } else {
                        EmptyStateView()
                    }
                } else {
                    // MARK: - Total View (History)
                    if !records.isEmpty {
                        // 1. 주간 흐름 차트 (Bar)
                        VStack(alignment: .leading) {
                            Text("최근 7일 학습 흐름")
                                .font(.headline)
                                .padding(.top)
                        
                            Chart(recentWeeklyData) { item in
                                BarMark(
                                    x: .value("날짜", formatChartDate(item.date)), // ✨ MM.dd 포맷 적용
                                    y: .value("시간", Double(item.totalSeconds) / 3600.0) // 시간 단위
                                )
                                .foregroundStyle(brandColor.gradient)
                                .cornerRadius(5)
                                .annotation(position: .top) {
                                    if item.totalSeconds > 0 {
                                        Text(String(format: "%.1f", Double(item.totalSeconds) / 3600.0))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .frame(height: 200)
                            // ✨ [New] 차트 축 커스터마이징
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            Text(String(format: "%.1f h", doubleValue))
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisValueLabel()
                                }
                            }
                            .padding(.vertical)
                        }
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        
                        // 2. 일별 상세 기록 (List)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("일별 상세 기록")
                                .font(.headline)
                                .padding()
                            
                            // ✨ [Modified] 월별 폴더링 (DisclosureGroup) - 별도 뷰로 분리하여 상태 관리
                            ForEach(monthlyHistoryData, id: \.month) { monthGroup in
                                MonthlySectionView(monthGroup: monthGroup, brandColor: brandColor, userId: userId)
                                Divider()
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        
                    } else {
                        EmptyStateView()
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground)) // 배경색 변경
        .navigationTitle("학습 통계")
    }
    
    // MARK: - Components
    
    private func modeButton(mode: StatMode, title: String, time: Int) -> some View {
        Button(action: { withAnimation { selectedMode = mode } }) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(selectedMode == mode ? brandColor : .gray)
                Text(formatTime(seconds: time))
                    .font(.title3)
                    .bold()
                    .foregroundColor(selectedMode == mode ? brandColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selectedMode == mode ? brandColor.opacity(0.1) : .white)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(selectedMode == mode ? brandColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ✨ [New] 월별 섹션 뷰 (상태 관리를 위해 분리)
struct MonthlySectionView: View {
    let monthGroup: (month: String, days: [StatisticsView.DailyStudyData])
    let brandColor: Color
    let userId: String
    
    @State private var isExpanded: Bool = true // 기본 펼침
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ForEach(monthGroup.days) { item in
                    NavigationLink(destination: DailyStatisticsView(date: item.date, userId: userId)) {
                        HStack {
                            // 날짜 및 대표 과목
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(item.date))
                                    .font(.body.bold())
                                    .foregroundColor(.primary)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(SubjectName.color(for: item.primarySubject))
                                        .frame(width: 8, height: 8)
                                    Text(item.primarySubject)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(formatTime(seconds: item.totalSeconds))
                                    .fontWeight(.semibold)
                                    .foregroundColor(brandColor)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white)
                    }
                    Divider()
                }
            },
            label: {
                Text(monthGroup.month)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
            }
        )
        .padding(.horizontal)
        .accentColor(.gray)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)시간 \(m)분"
    }
}

// MARK: - Subviews

struct PieChartView: View {
    let data: [StatisticsView.SubjectData]
    let title: String
    
    var totalSeconds: Int {
        data.reduce(0) { $0 + $1.totalSeconds }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.leading)
                .padding(.top)
            
            Chart(data) { item in
                SectorMark(
                    angle: .value("시간", item.totalSeconds),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.0
                )
                .cornerRadius(5)
                .foregroundStyle(SubjectName.color(for: item.subject))
            }
            .frame(height: 250)
            .padding(.horizontal)
            .padding(.top, 10)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(data) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(SubjectName.color(for: item.subject))
                            .frame(width: 8, height: 8)
                        Text(item.subject)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
        .padding(.horizontal)
    }
}

struct SubjectListView: View {
    let data: [StatisticsView.SubjectData]
    let title: String
    let userId: String
    var targetDate: Date? = nil // ✨ [New] 날짜 필터링 지원
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding()
            
            ForEach(data) { item in
                // ✨ [Modified] SubjectDetailView에 날짜 전달
                NavigationLink(destination: SubjectDetailView(subjectName: item.subject, userId: userId, targetDate: targetDate)) {
                    HStack {
                        Circle()
                            .fill(SubjectName.color(for: item.subject))
                            .frame(width: 6, height: 6)
                        
                        Text(item.subject)
                            .bold()
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatTime(seconds: item.totalSeconds))
                            .foregroundColor(.gray)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white)
                }
                Divider()
            }
        }
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.1), radius: 5)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)시간 \(m)분"
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.2))
            Text("아직 데이터가 없습니다.")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .background(Color.white)
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

// ✨ [New] 일별 통계 상세 뷰
struct DailyStatisticsView: View {
    let date: Date
    let userId: String
    
    @Query private var records: [StudyRecord]
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId &&
            record.date >= startOfDay &&
            record.date < endOfDay
        }, sort: \.date, order: .reverse)
    }
    
    var dailySubjectData: [StatisticsView.SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { StatisticsView.SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                if !records.isEmpty {
                    PieChartView(data: dailySubjectData, title: "\(formatDate(date)) 과목별 비중")
                    // ✨ [Modified] SubjectListView에 date 전달
                    SubjectListView(data: dailySubjectData, title: "일별 상세 기록", userId: userId, targetDate: date)
                } else {
                    EmptyStateView()
                }
            }
            .padding(.top)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(formatDate(date))
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
}
