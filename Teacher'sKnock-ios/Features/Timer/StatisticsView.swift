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
    
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    var todaySeconds: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var displayData: [SubjectData] {
        let calendar = Calendar.current
        var targetRecords: [StudyRecord] = []
        
        switch selectedMode {
        case .today: targetRecords = records.filter { calendar.isDateInToday($0.date) }
        case .total: targetRecords = records
        }
        
        var dict: [String: Int] = [:]
        for record in targetRecords {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var currentTotalSeconds: Int {
        displayData.reduce(0) { $0 + $1.totalSeconds }
    }
    
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)시간 \(m)분"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // 상단 버튼 영역 (오늘 / 총 누적)
                    HStack(spacing: 15) {
                        Button(action: { withAnimation { selectedMode = .today } }) {
                            VStack(spacing: 5) {
                                Text("오늘 공부").font(.caption).foregroundColor(selectedMode == .today ? brandColor : .gray)
                                Text(formatTime(seconds: todaySeconds)).font(.title3).bold().foregroundColor(selectedMode == .today ? brandColor : .primary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(selectedMode == .today ? brandColor.opacity(0.1) : .white)
                            .cornerRadius(15)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(selectedMode == .today ? brandColor : .clear, lineWidth: 2))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { withAnimation { selectedMode = .total } }) {
                            VStack(spacing: 5) {
                                Text("총 누적").font(.caption).foregroundColor(selectedMode == .total ? brandColor : .gray)
                                Text(formatTime(seconds: totalSecondsAll)).font(.title3).bold().foregroundColor(selectedMode == .total ? brandColor : .primary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(selectedMode == .total ? brandColor.opacity(0.1) : .white)
                            .cornerRadius(15)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(selectedMode == .total ? brandColor : .clear, lineWidth: 2))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if !displayData.isEmpty {
                        // 1. 차트 영역
                        VStack(alignment: .leading) {
                            Text(selectedMode == .today ? "오늘 과목별 비중" : "전체 과목별 비중")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top)
                            
                            // ✨ [수정] 차트 색상을 과목별 고유 색상으로 적용
                            Chart(displayData) { item in
                                let percentage = Double(item.totalSeconds) / Double(currentTotalSeconds) * 100
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.0
                                )
                                .cornerRadius(5)
                                .foregroundStyle(SubjectName.color(for: item.subject)) // ✨ 과목 색상 적용
                                .annotation(position: .overlay) {
                                    if percentage >= 5 {
                                        Text(String(format: "%.0f%%", percentage))
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 1)
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // ✨ [추가] 차트 하단 범례 (과목명과 색상 매칭)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                                ForEach(displayData) { item in
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
                        
                        // 2. 리스트 영역 (상세 기록 바로가기)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(selectedMode == .today ? "오늘 상세 기록" : "전체 상세 기록")
                                .font(.headline)
                                .padding()
                            
                            ForEach(displayData) { item in
                                NavigationLink(destination: SubjectDetailView(subjectName: item.subject, userId: userId)) {
                                    HStack {
                                        // 과목명 앞에 작은 색상 표시로 구분감 추가
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
                        
                    } else {
                        // 데이터 없음
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
            }
            .background(Color(.systemGray6))
            .navigationTitle("학습 통계")
        }
    }
}
