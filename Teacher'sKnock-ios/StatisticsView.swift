import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var records: [StudyRecord]
    
    // 상세 화면 전달용 ID
    let userId: String
    
    // ✨ [NEW] 통계 모드 상태 (오늘 vs 전체)
    enum StatMode {
        case today
        case total
    }
    @State private var selectedMode: StatMode = .today // 기본값은 '오늘'
    
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
    
    // MARK: - 시간 계산 로직
    
    // 오늘 공부 시간 (고정값)
    var todaySeconds: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 전체 누적 시간 (고정값)
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    // ✨ [핵심] 선택된 모드에 따라 차트/리스트에 보여줄 데이터가 바뀜
    var displayData: [SubjectData] {
        let calendar = Calendar.current
        var targetRecords: [StudyRecord] = []
        
        switch selectedMode {
        case .today:
            // 오늘 데이터만 필터링
            targetRecords = records.filter { calendar.isDateInToday($0.date) }
        case .total:
            // 전체 데이터 사용
            targetRecords = records
        }
        
        // 과목별 합계 계산
        var dict: [String: Int] = [:]
        for record in targetRecords {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    // 현재 보여주는 총 시간 (차트 % 계산용)
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
                    
                    // 1. ✨ 상단 탭 버튼 (오늘 vs 총 누적)
                    HStack(spacing: 15) {
                        // [버튼 1] 오늘 공부
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMode = .today
                            }
                        }) {
                            VStack(spacing: 5) {
                                Text("오늘 공부")
                                    .font(.caption)
                                    .foregroundColor(selectedMode == .today ? brandColor : .gray)
                                    .fontWeight(selectedMode == .today ? .bold : .regular)
                                
                                Text(formatTime(seconds: todaySeconds))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedMode == .today ? brandColor : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            // ✨ 선택 시 음영 처리 및 테두리
                            .background(selectedMode == .today ? brandColor.opacity(0.1) : Color.white)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(selectedMode == .today ? brandColor : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: .gray.opacity(0.1), radius: 5)
                        }
                        .buttonStyle(PlainButtonStyle()) // 버튼 깜빡임 효과 제거
                        
                        // [버튼 2] 총 누적
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMode = .total
                            }
                        }) {
                            VStack(spacing: 5) {
                                Text("총 누적")
                                    .font(.caption)
                                    .foregroundColor(selectedMode == .total ? brandColor : .gray)
                                    .fontWeight(selectedMode == .total ? .bold : .regular)
                                
                                Text(formatTime(seconds: totalSecondsAll))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(selectedMode == .total ? brandColor : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            // ✨ 선택 시 음영 처리 및 테두리
                            .background(selectedMode == .total ? brandColor.opacity(0.1) : Color.white)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(selectedMode == .total ? brandColor : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: .gray.opacity(0.1), radius: 5)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 2. 과목별 파이 차트 (데이터 연동: displayData)
                    if !displayData.isEmpty {
                        VStack(alignment: .leading) {
                            // 제목도 선택된 모드에 따라 변경
                            Text(selectedMode == .today ? "오늘 과목별 비중" : "전체 과목별 비중")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top)
                                .transition(.opacity) // 글자 바뀔 때 부드럽게
                            
                            Chart(displayData) { item in
                                let percentage = Double(item.totalSeconds) / Double(currentTotalSeconds) * 100
                                
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.0
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("과목", item.subject))
                                .annotation(position: .overlay) {
                                    if percentage >= 5 {
                                        Text(String(format: "%.0f%%", percentage))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.4), radius: 1, x: 1, y: 1)
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                            // 차트 데이터가 바뀔 때 애니메이션 효과
                            .id(selectedMode)
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        
                        // 3. 상세 리스트 (데이터 연동: displayData)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(selectedMode == .today ? "오늘 상세 기록" : "전체 상세 기록")
                                .font(.headline)
                                .padding()
                            
                            ForEach(displayData) { item in
                                NavigationLink(destination: SubjectDetailView(subjectName: item.subject, userId: userId)) {
                                    HStack {
                                        Text(item.subject)
                                            .bold()
                                            .foregroundColor(.primary)
                                        Spacer()
                                        
                                        Text(formatTime(seconds: item.totalSeconds))
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 5)
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
                        // 데이터 없을 때 (Empty State)
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20)
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.2))
                            
                            // 문구도 상황에 맞게 변경
                            if selectedMode == .today {
                                Text("오늘 공부 기록이 없습니다.\n지금 바로 시작해보세요!")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                            } else {
                                Text("아직 저장된 공부 기록이 없습니다.")
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 30)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("학습 통계")
        }
    }
}

#Preview {
    StatisticsView(userId: "preview")
        .modelContainer(for: StudyRecord.self, inMemory: true)
}
