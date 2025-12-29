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
    // ✨ [추가] 감정 일기 데이터
    @State private var notes: [DailyNote] = []
    
    @Environment(\.modelContext) private var modelContext
    
    // 차트용 데이터 구조체
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color { SubjectName.color(for: subject) }
    }
    
    init(title: String, startDate: Date, endDate: Date, userId: String) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.userId = userId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 1. 헤더
                headerSection
                
                Divider()
                
                // 2. 학습 습관 캘린더 (잔디 + 감정)
                VStack(alignment: .leading, spacing: 10) {
                    Text("📅 월간 학습 & 감정")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // ✨ notes 데이터 전달
                    StudyHeatmapView(startDate: startDate, endDate: endDate, records: records, notes: notes)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // 3. 과목별 분석
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("📊 과목별 학습 분석")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart(pieData) { item in
                            SectorMark(
                                angle: .value("시간", item.seconds),
                                innerRadius: .ratio(0.55),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                        }
                        .frame(height: 220)
                        
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
                
                // 4. ✨ [추가] 이번 달의 한마디 (일기 모아보기)
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("📝 이번 달의 한마디")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // 날짜순 정렬
                            ForEach(notes.sorted(by: { $0.date < $1.date })) { note in
                                HStack(alignment: .top, spacing: 12) {
                                    // 날짜 & 감정
                                    VStack(spacing: 4) {
                                        Text(formatDateShort(note.date))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text(note.emotion)
                                            .font(.title3)
                                    }
                                    .frame(width: 40)
                                    
                                    // 내용
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !note.content.isEmpty {
                                            Text(note.content)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        } else {
                                            Text("(내용 없음)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
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
        let noteDescriptor = FetchDescriptor<DailyNote>(
            predicate: #Predicate<DailyNote> { $0.ownerID == userId }
        )
        
        do {
            let allR = try modelContext.fetch(recordDescriptor)
            let allN = try modelContext.fetch(noteDescriptor)
            
            let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            
            self.records = allR.filter { $0.date >= startDate && $0.date < rangeEnd }
            self.notes = allN.filter { $0.date >= startDate && $0.date < rangeEnd }
            
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
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("이번 달 총 학습")
                .font(.subheadline).foregroundColor(.gray)
            Text(formatTime(totalSeconds))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.blue)
            
            Text("\(formatDate(startDate)) ~ \(formatDate(endDate))")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
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

// ✨ [수정됨] 잔디 심기 + 감정 이모지 뷰
struct StudyHeatmapView: View {
    let startDate: Date
    let endDate: Date
    let records: [StudyRecord]
    // ✨ notes 추가
    let notes: [DailyNote]
    
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
    
    // ✨ 날짜별 감정 매핑 (빠른 검색용)
    var noteMap: [Date: String] {
        var map: [Date: String] = [:]
        let calendar = Calendar.current
        for note in notes {
            let day = calendar.startOfDay(for: note.date)
            map[day] = note.emotion // 그날의 이모지 저장
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
                    let emotion = noteMap[dayKey] // 그날의 기분
                    
                    ZStack {
                        // 1. 공부량 배경 (색상)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getColor(seconds: seconds))
                            .aspectRatio(1, contentMode: .fit)
                        
                        // 2. ✨ 감정 이모지 오버레이
                        if let emoji = emotion {
                            Text(emoji)
                                .font(.system(size: 14)) // 칸 크기에 맞춰 조절
                                .shadow(color: .white.opacity(0.5), radius: 1) // 가독성 확보
                        }
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
