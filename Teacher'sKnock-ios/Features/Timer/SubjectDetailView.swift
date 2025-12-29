import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    let subjectName: String
    let userId: String
    
    @Query private var records: [StudyRecord]
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
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
    
    // ✨ 차트용 데이터: 표준 카테고리(studyPurpose)별로 그룹화
    var purposeData: [PurposeData] {
        var dict: [String: Int] = [:]
        for record in records {
            let p = record.studyPurpose.isEmpty ? "기타" : record.studyPurpose
            dict[p, default: 0] += record.durationSeconds
        }
        return dict.map { PurposeData(purpose: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 1. 헤더
                VStack(spacing: 5) {
                    Text(subjectName).font(.title2).fontWeight(.bold)
                    let total = records.reduce(0) { $0 + $1.durationSeconds }
                    Text("총 \(total / 3600)시간 \((total % 3600) / 60)분").font(.headline).foregroundColor(brandColor)
                }
                .padding(.top, 20)
                
                if !records.isEmpty {
                    // 2. 학습 유형 분석 차트 (표준 카테고리 기준)
                    VStack(alignment: .leading) {
                        Text("학습 유형 분석").font(.headline).padding(.bottom, 10)
                        Chart(purposeData) { item in
                            BarMark(x: .value("시간", item.totalSeconds), y: .value("목적", item.purpose))
                                .foregroundStyle(brandColor.gradient)
                                .cornerRadius(5)
                        }
                        .frame(height: 200)
                    }
                    .padding().background(Color.white).cornerRadius(15).padding(.horizontal)
                    
                    // 3. ✨ 상세 기록 리스트 (메모 포함)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("상세 기록 내역").font(.headline).padding()
                        
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    // 표준 카테고리 표시
                                    Text(record.studyPurpose)
                                        .font(.caption).bold()
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(brandColor.opacity(0.1)).foregroundColor(brandColor).cornerRadius(6)
                                    
                                    Spacer()
                                    
                                    Text("\(record.durationSeconds / 60)분 \(record.durationSeconds % 60)초")
                                        .font(.subheadline).foregroundColor(.gray)
                                }
                                
                                // ✨ 연동된 일정 제목(memo) 표시
                                if let memo = record.memo {
                                    Text(memo)
                                        .font(.body).fontWeight(.medium)
                                }
                                
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2).foregroundColor(.gray.opacity(0.6))
                            }
                            .padding()
                            Divider()
                        }
                    }
                    .background(Color.white).cornerRadius(15).padding(.horizontal)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemGray6))
    }
}
