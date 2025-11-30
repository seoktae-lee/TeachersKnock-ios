import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    // 쿼리는 init에서 동적으로 설정
    @Query private var records: [StudyRecord]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // ✨ 생성자: 내 ID에 해당하는 공부 기록만 필터링
    init(userId: String) {
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    var chartData: [SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var totalStudyTime: String {
        let totalSeconds = records.reduce(0) { $0 + $1.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)시간 \(minutes)분"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    VStack {
                        Text("총 누적 공부 시간")
                            .font(.headline).foregroundColor(.gray)
                        Text(totalStudyTime)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(brandColor)
                    }
                    .frame(maxWidth: .infinity).padding().background(Color.white)
                    .cornerRadius(15).shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    
                    if !chartData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("과목별 비중").font(.title2).bold().padding(.leading).padding(.top)
                            
                            Chart(chartData) { item in
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5), angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("과목", item.subject))
                            }
                            .frame(height: 300).padding()
                        }
                        .background(Color.white).cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5).padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("과목별 상세 기록").font(.headline).padding(.leading).padding(.top)
                            ForEach(chartData) { item in
                                HStack {
                                    Text(item.subject).bold()
                                    Spacer()
                                    let h = item.totalSeconds / 3600
                                    let m = (item.totalSeconds % 3600) / 60
                                    Text("\(h)시간 \(m)분").foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                                Divider()
                            }
                            .padding(.bottom)
                        }
                        .background(Color.white).cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5).padding(.horizontal)
                        
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 50)).foregroundColor(.gray.opacity(0.3))
                            Text("아직 공부 기록이 없습니다.\n타이머를 실행해서 기록을 쌓아보세요!")
                                .multilineTextAlignment(.center).foregroundColor(.gray)
                        }
                        .frame(height: 300).frame(maxWidth: .infinity)
                        .background(Color.white).cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5).padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color(.systemGray6))
            .navigationTitle("학습 통계")
        }
    }
}
