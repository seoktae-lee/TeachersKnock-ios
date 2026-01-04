import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let subjectName: String
    let userId: String
    let targetDate: Date? // ✨ [NEW] 날짜 필터링 (Optional)
    
    @Query private var records: [StudyRecord]
    
    private var subjectColor: Color {
        SubjectName.color(for: subjectName)
    }
    
    // ✨ [NEW] 동적 쿼리 생성
    init(subjectName: String, userId: String, targetDate: Date? = nil) {
        self.subjectName = subjectName
        self.userId = userId
        self.targetDate = targetDate
        
        if let date = targetDate {
            // 특정 날짜의 기록만 조회
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            _records = Query(filter: #Predicate<StudyRecord> { record in
                record.ownerID == userId &&
                record.areaName == subjectName &&
                record.date >= startOfDay &&
                record.date < endOfDay
            }, sort: \.date, order: .reverse)
        } else {
            // 전체 기록 조회
            _records = Query(filter: #Predicate<StudyRecord> { record in
                record.ownerID == userId &&
                record.areaName == subjectName
            }, sort: \.date, order: .reverse)
        }
    }
    
    // MARK: - Data Models
    
    struct PurposeData: Identifiable {
        let id = UUID()
        let purpose: String
        let totalSeconds: Int
    }
    
    // 차트용 데이터 (전체 합계)
    var purposeData: [PurposeData] {
        var dict: [String: Int] = [:]
        for record in records {
            let p = record.studyPurpose.isEmpty ? "기타" : record.studyPurpose
            dict[p, default: 0] += record.durationSeconds
        }
        return dict.map { PurposeData(purpose: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    // ✨ [NEW] 같은 목적끼리 합친 리스트 데이터
    struct AggregatedRecord: Identifiable {
        let id = UUID()
        let purpose: String
        let totalSeconds: Int
        let count: Int
        let ids: [PersistentIdentifier] // 삭제를 위해 원본 ID 저장
    }
    
    var aggregatedRecords: [AggregatedRecord] {
        let grouped = Dictionary(grouping: records) { $0.studyPurpose.isEmpty ? "기타" : $0.studyPurpose }
        
        return grouped.map { (purpose, items) in
            let total = items.reduce(0) { $0 + $1.durationSeconds }
            return AggregatedRecord(
                purpose: purpose,
                totalSeconds: total,
                count: items.count,
                ids: items.map { $0.persistentModelID }
            )
        }.sorted { $0.totalSeconds > $1.totalSeconds } // 시간 순 정렬
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
                                Text(targetDate != nil ? "일간 합계" : "총 누적")
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
            
            // MARK: - 2. 상세 기록 리스트 (Aggregated)
            if !aggregatedRecords.isEmpty {
                Section(header: Text("상세 기록 내역")) {
                    ForEach(aggregatedRecords) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.purpose)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(subjectColor.opacity(0.15))
                                    .foregroundColor(subjectColor)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                Group {
                                    if item.totalSeconds >= 3600 {
                                        Text("\(item.totalSeconds / 3600)시간 \((item.totalSeconds % 3600) / 60)분")
                                    } else {
                                        Text("\(item.totalSeconds / 60)분 \(item.totalSeconds % 60)초")
                                    }
                                }
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            }
                            
                            // 몇 개의 기록이 합쳐졌는지 표시
                            if item.count > 1 {
                                Text("총 \(item.count)개의 기록 합산됨")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                // 단일 기록일 경우 날짜 표시 (옵션)
                                // 여기에 날짜를 표시하려면 AggregatedRecord에 날짜 정보도 포함해야 함
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deleteAggregatedRecords)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subjectName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // ✨ 합산된 기록 삭제 함수
    private func deleteAggregatedRecords(at offsets: IndexSet) {
        withAnimation {
            // 선택된 Aggregated Record 찾기
            let selectedItems = offsets.map { aggregatedRecords[$0] }
            
            // 해당 그룹에 속한 모든 원본 레코드 삭제
            for group in selectedItems {
                for id in group.ids {
                    if let record = modelContext.model(for: id) as? StudyRecord {
                        modelContext.delete(record)
                    }
                }
            }
        }
    }
}

