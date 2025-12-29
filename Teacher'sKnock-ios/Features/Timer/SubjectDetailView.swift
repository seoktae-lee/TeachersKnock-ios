import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let subjectName: String
    let userId: String
    
    @Query private var records: [StudyRecord]
    
    // ✨ 과목별 고유 색상 가져오기 (예: 도덕 -> 민트색)
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
    
    // 차트 데이터: 공부 시간이 많은 순서대로 정렬 (진한 색이 큰 비중을 차지하도록)
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
            // MARK: - 1. 차트 섹션 (상단)
            Section {
                if !records.isEmpty {
                    VStack {
                        Text("학습 유형 분석")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 10)
                        
                        ZStack {
                            // ✨ [수정] 차트 색상을 과목 색상(subjectColor)의 농도 차이로 표현
                            Chart(Array(purposeData.enumerated()), id: \.element.id) { index, item in
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                // 🎨 1등은 진하게(100%), 순위가 내려갈수록 점점 연하게(투명도 조절)
                                .foregroundStyle(subjectColor.opacity(max(0.2, 1.0 - (Double(index) * 0.15))))
                                .annotation(position: .overlay) {
                                    // 10% 이상인 경우에만 퍼센트 표시
                                    if Double(item.totalSeconds) / Double(totalSeconds) > 0.1 {
                                        Text("\(Int(Double(item.totalSeconds) / Double(totalSeconds) * 100))%")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 250)
                            
                            // 차트 가운데: 총 공부 시간
                            VStack(spacing: 4) {
                                Text("총 누적")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(totalSeconds / 3600)시간")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(subjectColor) // ✨ 총 시간도 과목 색상
                                Text("\((totalSeconds % 3600) / 60)분")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // ✨ [추가] 차트 범례 (색상 설명)
                        // 차트 색상과 동일한 순서와 색상으로 범례 표시
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
                    // 데이터 없음 표시
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
            
            // MARK: - 2. 상세 기록 리스트 (밀어서 삭제 가능)
            if !records.isEmpty {
                Section(header: Text("상세 기록 내역 (밀어서 삭제)")) {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // 뱃지: 과목 색상의 연한 배경 + 진한 글자
                                Text(record.studyPurpose)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(subjectColor.opacity(0.15))
                                    .foregroundColor(subjectColor)
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                // 시간 표시
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
                            
                            // 일정 제목(메모)
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
                            
                            // 날짜
                            Text(record.date.formatted(date: .long, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deleteRecords) // ✨ 삭제 기능 연결
                }
            }
        }
        .listStyle(.insetGrouped) // 깔끔한 카드형 리스트 스타일
        .navigationTitle(subjectName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 기록 삭제 함수
    private func deleteRecords(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let recordToDelete = records[index]
                modelContext.delete(recordToDelete)
            }
        }
    }
}
