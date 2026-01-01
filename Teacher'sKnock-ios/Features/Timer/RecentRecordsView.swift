import SwiftUI
import SwiftData

struct RecentRecordsView: View {
    let userId: String
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [StudyRecord]
    
    init(userId: String) {
        self.userId = userId
        // 해당 유저의 최근 기록 5개만 가져오기
        _records = Query(filter: #Predicate<StudyRecord> { $0.ownerID == userId }, sort: \.date, order: .reverse)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 공부 기록").font(.headline)
                Spacer()
                NavigationLink(destination: StatisticsView(userId: userId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                        Text("통계")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            if records.isEmpty {
                Text("아직 기록이 없습니다.")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding()
            } else {
                List {
                    ForEach(records.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.areaName).font(.subheadline).bold()
                                Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(record.durationSeconds / 60)분").font(.subheadline).bold()
                        }
                        // List row styling to match the previous look as much as possible within a List
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.white)
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteRecord)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // Remove default list background
                .frame(height: 250) // Adjust height for List
            }
        }
    }
    
    private func deleteRecord(at offsets: IndexSet) {
        // Since we are showing only the prefix(5) but the query fetches all (sorted),
        // we need to be careful. However, 'records' query returns them in order.
        // The ForEach is over `records.prefix(5)`.
        // The index in offsets corresponds to the index in the prefixed collection.
        
        for index in offsets {
            if index < records.count {
                let recordToDelete = records[index]
                modelContext.delete(recordToDelete)
            }
        }
    }
}
