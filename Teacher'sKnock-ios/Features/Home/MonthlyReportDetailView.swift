import SwiftUI
import SwiftData
import Charts

struct MonthlyReportDetailView: View {
    let title: String
    let startDate: Date
    let endDate: Date
    let userId: String
    
    // 공부 기록 데이터
    @State private var records: [StudyRecord] = []
    @State private var previousRecords: [StudyRecord] = [] // ✨ [추가] 지난달 데이터 (AI 분석용)
    
    @Environment(\.modelContext) private var modelContext
    
    // 차트용 데이터 구조체
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color { SubjectName.color(for: subject) }
    }
    
    // ✨ [추가] 차트 탭 상태
    @State private var currentChartTab = 0
    
    init(title: String, startDate: Date, endDate: Date, userId: String) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.userId = userId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 1. 통합 헤더 (요약 + AI 코치)
                AIAnalysisView(
                    totalSeconds: totalSeconds,
                    mvpSubject: pieData.first.map { ($0.subject, $0.color) }, // Monthly uses 'subject' not 'label'
                    records: records,
                    previousRecords: previousRecords,
                    title: "월간 분석"
                )
                .padding(.horizontal)
                
                Divider()
                
                // 2. ✨ [이동됨] 과목별 분석 (파이 & 레이더 스와이프)
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text(currentChartTab == 0 ? "과목별 학습 분석" : "과목 밸런스")
                                .font(.headline)
                            Spacer()
                            // 인디케이터
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
                        .frame(height: 300)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        
                        Divider().padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(pieData.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.caption2).bold()
                                        .frame(width: 20, height: 20)
                                        .background(index < 3 ? item.color.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundColor(index < 3 ? item.color : .gray)
                                        .clipShape(Circle())
                                    
                                    Text(item.subject)
                                        .font(.subheadline)
                                        .frame(width: 80, alignment: .leading)
                                        .lineLimit(1)
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.gray.opacity(0.1))
                                            Capsule().fill(item.color)
                                                .frame(width: geo.size.width * (Double(item.seconds) / Double(maxSeconds)))
                                        }
                                    }
                                    .frame(height: 8)
                                    
                                    Text(formatTimeShort(item.seconds))
                                        .font(.caption).foregroundColor(.gray)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("이 달에는 공부 기록이 없습니다.")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.vertical, 30)
                }
                
                Divider()
                
                // 3. ✨ [이동됨] 학습 습관 캘린더 (잔디 + 감정)
                VStack(alignment: .leading, spacing: 10) {
                    Text("월간 학습")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // ✨ notes 데이터 전달 제거
                    StudyHeatmapView(startDate: startDate, endDate: endDate, records: records)
                        .padding(.horizontal)
                }
                
                Divider()
                

            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
        .task {
            fetchData()
        }
    }
    
    // ✨ 데이터 로드 함수 수정 (공부 기록 + 일기)
    private func fetchData() {
        // 1. 공부 기록 가져오기
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate<StudyRecord> { $0.ownerID == userId }
        )
        // 2. 일기 가져오기
        do {
            let allR = try modelContext.fetch(recordDescriptor)
            
            let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            
            self.records = allR.filter { $0.date >= startDate && $0.date < rangeEnd }
            
            // ✨ [추가] 지난달 데이터 로드 (한 달 전)
            let prevStartDate = Calendar.current.date(byAdding: .month, value: -1, to: startDate)!
            // 이번달 시작일이 지난달 종료일(exclusive)이라고 가정해도 되지만, 
            // 정확히는 interval만큼 빼는게 맞으나, 간단히 한달 전으로 계산
            let prevEndDate = startDate
            
            self.previousRecords = allR.filter { $0.date >= prevStartDate && $0.date < prevEndDate }
            
        } catch {
            print("월간 리포트 로드 실패: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private var totalSeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    private var maxSeconds: Int {
        pieData.map { $0.seconds }.max() ?? 1
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d일" // 예: 5일
        return formatter.string(from: date)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
    
    private func formatTimeShort(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// ✨ [수정됨] 잔디 심기
struct StudyHeatmapView: View {
    let startDate: Date
    let endDate: Date
    let records: [StudyRecord]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var days: [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        var current = startDate
        while current <= endDate {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }
    
    // 날짜별 공부 시간 매핑
    var studyMap: [Date: Int] {
        var map: [Date: Int] = [:]
        let calendar = Calendar.current
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            map[day, default: 0] += record.durationSeconds
        }
        return map
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                    Text(day).font(.caption2).foregroundColor(.gray)
                }
                
                let firstWeekday = Calendar.current.component(.weekday, from: startDate)
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                }
                
                ForEach(days, id: \.self) { date in
                    let dayKey = Calendar.current.startOfDay(for: date)
                    let seconds = studyMap[dayKey] ?? 0
                    ZStack {
                        // 1. 공부량 배경 (색상)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getColor(seconds: seconds))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
    
    func getColor(seconds: Int) -> Color {
        if seconds == 0 { return Color.gray.opacity(0.1) }
        if seconds < 3600 { return Color.blue.opacity(0.2) }
        if seconds < 10800 { return Color.blue.opacity(0.5) }
        if seconds < 18000 { return Color.blue.opacity(0.8) }
        return Color.blue
    }
}
