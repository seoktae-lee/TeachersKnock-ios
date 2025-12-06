import SwiftUI
import SwiftData

struct ReportListView: View {
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    
    let userId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var weeklyGroups: [ReportGroup] = []
    @State private var monthlyGroups: [ReportGroup] = []
    @State private var isLoading = true
    
    init(userId: String) {
        self.userId = userId
        _records = Query(
            filter: #Predicate<StudyRecord> { $0.ownerID == userId },
            sort: \.date,
            order: .reverse
        )
    }
    
    // 백그라운드 데이터 전송용 구조체
    struct RecordData: Sendable {
        let date: Date
        let duration: Int
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("기간", selection: $selectedTab) {
                Text("주간 리포트").tag(0)
                Text("월간 리포트").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color.white)
            
            if isLoading {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("데이터 분석 중...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        if records.isEmpty {
                            emptyView
                        } else if selectedTab == 0 {
                            ForEach(weeklyGroups, id: \.id) { group in
                                NavigationLink(destination: WeeklyReportDetailView(
                                    title: group.title,
                                    startDate: group.startDate,
                                    endDate: group.endDate,
                                    userId: userId
                                )) {
                                    ReportCard(title: group.title, dateRange: group.rangeString, totalTime: group.totalSeconds, isNew: isRecent(group.endDate))
                                }.buttonStyle(.plain)
                            }
                        } else {
                            ForEach(monthlyGroups, id: \.id) { group in
                                NavigationLink(destination: MonthlyReportDetailView(
                                    title: group.title,
                                    startDate: group.startDate,
                                    endDate: group.endDate,
                                    userId: userId
                                )) {
                                    ReportCard(title: group.title, dateRange: group.rangeString, totalTime: group.totalSeconds, isNew: isRecent(group.endDate))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
            }
        }
        .navigationTitle("학습 리포트")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { // .task 대신 onAppear 사용
            // ✨ [핵심 수정] 화면 진입 애니메이션이 끝날 때까지 0.5초 대기 후 계산 시작
            if isLoading {
                let rawData = records.map { RecordData(date: $0.date, duration: $0.durationSeconds) }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task {
                        await calculateInBackground(data: rawData)
                    }
                }
            }
        }
    }
    
    private func calculateInBackground(data: [RecordData]) async {
        let result = await Task.detached(priority: .userInitiated) {
            return ReportCalculator.process(data: data)
        }.value
        
        await MainActor.run {
            self.weeklyGroups = result.weekly
            self.monthlyGroups = result.monthly
            withAnimation {
                self.isLoading = false
            }
        }
    }
    
    // ... (이하 Helper 함수 및 ReportCalculator는 이전 코드와 동일하므로 그대로 유지) ...
    
    private var emptyView: some View {
        VStack(spacing: 15) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 50)).foregroundColor(.gray.opacity(0.5))
            Text("아직 생성된 리포트가 없어요.").font(.headline).foregroundColor(.gray)
            Text("공부를 기록하면 리포트가 쌓입니다!").font(.caption).foregroundColor(.gray)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 100)
    }
    
    private func isRecent(_ date: Date) -> Bool {
        let diff = Calendar.current.dateComponents([.day], from: date, to: Date())
        return (diff.day ?? 100) < 7
    }
    
    struct ReportGroup: Identifiable, Sendable {
        let id = UUID(); let title: String; let rangeString: String; let totalSeconds: Int; let startDate: Date; let endDate: Date
    }
}

// (ReportCalculator와 ReportCard는 이전과 동일합니다. 파일에 포함되어 있어야 합니다.)
struct ReportCalculator {
    static func process(data: [ReportListView.RecordData]) -> (weekly: [ReportListView.ReportGroup], monthly: [ReportListView.ReportGroup]) {
        var calendar = Calendar.current; calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        
        let wGrouped = Dictionary(grouping: data) { r in "\(calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: r.date).yearForWeekOfYear!)-\(calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: r.date).weekOfYear!)" }
        let wSorted = wGrouped.keys.sorted(by: >)
        let weekly = wSorted.compactMap { key -> ReportListView.ReportGroup? in
            guard let items = wGrouped[key], let first = items.first else { return nil }
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first.date)) else { return nil }
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            if let thurs = calendar.date(byAdding: .day, value: 3, to: startOfWeek) {
                let month = calendar.component(.month, from: thurs); let week = calendar.component(.weekOfMonth, from: thurs)
                return ReportListView.ReportGroup(title: "\(month)월 \(week)주차 리포트", rangeString: "\(formatDate(startOfWeek)) ~ \(formatDate(endOfWeek))", totalSeconds: items.reduce(0){$0+$1.duration}, startDate: startOfWeek, endDate: endOfWeek)
            }
            return nil
        }
        
        let mGrouped = Dictionary(grouping: data) { r in "\(calendar.dateComponents([.year, .month], from: r.date).year!)-\(calendar.dateComponents([.year, .month], from: r.date).month!)" }
        let mSorted = mGrouped.keys.sorted(by: >)
        let monthly = mSorted.compactMap { key -> ReportListView.ReportGroup? in
            guard let items = mGrouped[key], let first = items.first else { return nil }
            let month = calendar.component(.month, from: first.date)
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date))!
            let range = calendar.dateInterval(of: .month, for: startOfMonth)
            let endStr = range != nil ? formatDate(range!.end.addingTimeInterval(-86400)) : ""
            return ReportListView.ReportGroup(title: "\(month)월 월간 분석", rangeString: "\(formatDate(startOfMonth)) ~ \(endStr)", totalSeconds: items.reduce(0){$0+$1.duration}, startDate: startOfMonth, endDate: range?.end ?? Date())
        }
        return (weekly, monthly)
    }
    static func formatDate(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: d) }
}

struct ReportCard: View {
    let title: String; let dateRange: String; let totalTime: Int; let isNew: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    if isNew { Text("NEW").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Color.red.opacity(0.8)).clipShape(Capsule()) }
                }
                Text(dateRange).font(.caption).foregroundColor(.gray)
                Text("총 학습 시간: \(formatTime(totalTime))").font(.caption2).fontWeight(.bold).foregroundColor(.blue).padding(.top, 2)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
        }.padding().background(Color.white).cornerRadius(16).shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    private func formatTime(_ s: Int) -> String { let h = s/3600; let m = (s%3600)/60; return h>0 ? "\(h)시간 \(m)분" : "\(m)분" }
}
