import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let subjectName: String
    let userId: String
    
    @Query private var records: [StudyRecord]
    
    private var subjectColor: Color {
        SubjectName.color(for: subjectName)
    }
    
    init(subjectName: String, userId: String) {
        self.subjectName = subjectName
        self.userId = userId
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId && record.areaName == subjectName
        }, sort: \.date, order: .reverse)
    }
    
    struct PurposeData: Identifiable {
        let id = UUID()
        let purpose: String
        let totalSeconds: Int
    }
    
    var purposeData: [PurposeData] {
        var dict: [String: Int] = [:]
        for record in records {
            let p = record.studyPurpose.isEmpty ? "기타" : record.studyPurpose
            dict[p, default: 0] += record.durationSeconds
        }
        return dict.map { PurposeData(purpose: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var totalSeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var body: some View {
        List {
            // MARK: - 1. 차트 섹션
            Section {
                if !records.isEmpty {
                    VStack {
                        Text("학습 유형 분석")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 10)
                        
                        ZStack {
                            Chart(Array(purposeData.enumerated()), id: \.element.id) { index, item in
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(subjectColor.opacity(max(0.2, 1.0 - (Double(index) * 0.15))))
                                .annotation(position: .overlay) {
                                    // ✨ [수정] 0으로 나누기 방지 코드 추가
                                    let total = Double(totalSeconds)
                                    if total > 0 {
                                        let percentage = Double(item.totalSeconds) / total * 100
                                        if percentage > 10 { // 10% 초과일 때만 표시
                                            Text("\(Int(percentage))%")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .frame(height: 250)
                            
                            VStack(spacing: 4) {
                                Text("총 누적")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(totalSeconds / 3600)시간")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(subjectColor)
                                Text("\((totalSeconds % 3600) / 60)분")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // 차트 범례
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(Array(purposeData.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(subjectColor.opacity(max(0.2, 1.0 - (Double(index) * 0.15))))
                                        .frame(width: 8, height: 8)
                                    Text(item.purpose)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 15)
                    }
                    .padding(.vertical, 10)
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("아직 학습 기록이 없어요")
                            .foregroundColor(.gray)
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                }
            }
            .listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
            
            // MARK: - 2. 상세 기록 리스트
            if !records.isEmpty {
                Section(header: Text("상세 기록 내역 (밀어서 삭제)")) {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.studyPurpose)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(subjectColor.opacity(0.15))
                                    .foregroundColor(subjectColor)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Group {
                                    if record.durationSeconds >= 3600 {
                                        Text("\(record.durationSeconds / 3600)시간 \((record.durationSeconds % 3600) / 60)분")
                                    } else {
                                        Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초")
                                    }
                                }
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            }
                            
                            if let memo = record.memo, !memo.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(memo)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(record.date.formatted(date: .long, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subjectName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // ✨ 안전한 삭제 함수
    private func deleteRecords(at offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { records[$0] }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        }
    }
}
