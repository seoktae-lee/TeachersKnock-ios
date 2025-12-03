import SwiftUI
import SwiftData
import Charts

struct DailyDetailView: View {
    let date: Date
    let userId: String
    
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    // 타임라인 등에서 선택된 일정 (수정 시트용)
    @State private var selectedSchedule: ScheduleItem? = nil
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _schedules = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
        })
    }
    
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color {
            if let matched = SubjectName.allCases.first(where: { $0.rawValue == subject }) {
                return matched.color
            }
            return .gray
        }
    }
    
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    // 퍼센트 계산을 위한 총 시간
    var totalSeconds: Int {
        pieData.reduce(0) { $0 + $1.seconds }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. 날짜 헤더
                HStack {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // 2. ✨ [순서 변경] To-Do List (가장 위로 이동)
                HStack {
                    Text("To-Do List")
                        .font(.headline)
                    Spacer()
                    Text("\(schedules.filter { $0.isCompleted }.count) / \(schedules.count) 완료")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                VStack(spacing: 0) {
                    if schedules.isEmpty {
                        Text("등록된 일정이 없습니다.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(schedules) { item in
                            HStack {
                                Button(action: { toggleComplete(item) }) {
                                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.isCompleted ? .green : .gray)
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .strikethrough(item.isCompleted)
                                        .foregroundColor(item.isCompleted ? .gray : .primary)
                                    if let end = item.endDate {
                                        Text("\(item.startDate.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Circle()
                                    .fill(SubjectName.color(for: item.title))
                                    .frame(width: 8, height: 8)
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSchedule = item // 리스트 눌러도 수정 가능
                            }
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                
                Divider()
                
                // 3. ✨ [순서 변경] 타임테이블 (중간)
                HStack {
                    Text("타임테이블").font(.headline)
                    Spacer()
                    Text("일정을 누르면 수정할 수 있어요")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                DailyTimelineView(schedules: schedules, onItemTap: { item in
                    selectedSchedule = item
                })
                .frame(height: 550) // 높이 충분히 확보 (스크롤 없음)
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                
                Divider()
                
                // 4. ✨ [순서 변경 & 퍼센트 추가] 오늘의 공부 통계 (맨 아래)
                if !pieData.isEmpty {
                    VStack {
                        Text("과목별 학습 비중").font(.headline).padding(.top)
                        
                        Chart(pieData) { item in
                            // 퍼센트 계산
                            let percentage = Double(item.seconds) / Double(totalSeconds) * 100
                            
                            SectorMark(
                                angle: .value("시간", item.seconds),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.0
                            )
                            .foregroundStyle(item.color)
                            // ✨ 차트 위에 퍼센트 글씨 올리기
                            .annotation(position: .overlay) {
                                if percentage >= 5 { // 5% 이상일 때만 표시 (겹침 방지)
                                    Text(String(format: "%.0f%%", percentage))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0) // 그림자로 가독성 확보
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        
                        // 범례
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(pieData) { item in
                                HStack(spacing: 4) {
                                    Circle().fill(item.color).frame(width: 8, height: 8)
                                    Text(item.subject).font(.caption).lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("일일 리포트")
        .sheet(item: $selectedSchedule) { item in
            EditScheduleView(item: item)
        }
    }
    
    private func toggleComplete(_ item: ScheduleItem) {
        item.isCompleted.toggle()
    }
}
