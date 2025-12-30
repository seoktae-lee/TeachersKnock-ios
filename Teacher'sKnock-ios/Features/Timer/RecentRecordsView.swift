import SwiftUI
import SwiftData

struct RecentRecordsView: View {
    let userId: String
    
    @Query private var recentRecords: [StudyRecord]
    
    init(userId: String) {
        self.userId = userId
        // 최근 3개의 기록만 가져오도록 쿼리 설정 (내림차순 정렬)
        _recentRecords = Query(
            filter: #Predicate<StudyRecord> { $0.ownerID == userId },
            sort: \.date,
            order: .reverse
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 학습 기록")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            if recentRecords.isEmpty {
                HStack {
                    Spacer()
                    Text("아직 기록이 없어요")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentRecords.prefix(3)) { record in
                            RecentRecordCell(record: record)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct RecentRecordCell: View {
    let record: StudyRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(SubjectName.color(for: record.areaName))
                    .frame(width: 8, height: 8)
                Text(record.areaName)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(record.date.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            Text(formatDuration(record.durationSeconds))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            if let memo = record.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)시간 \(m)분"
        } else {
            return "\(m)분"
        }
    }
}
