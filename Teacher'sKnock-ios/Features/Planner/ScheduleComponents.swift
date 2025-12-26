import SwiftUI
import SwiftData

// MARK: - 통계 행 컴포넌트
struct StatisticRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title).font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
    }
}

// MARK: - 향상된 스케줄 행 (Enhanced Schedule Row)
struct EnhancedScheduleRow: View {
    let item: ScheduleItem
    @Environment(\.modelContext) var context
    
    // 과목별 색상 매핑 (안전하게)
    var subjectColor: Color {
        // SubjectName에 정의된 색상이 있다면 쓰고, 없으면 해시값 기반으로 랜덤 파스텔 생성
        return Color.blue // TODO: SubjectName 연동 시 수정
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // 1. 과목 컬러 바 (왼쪽)
            RoundedRectangle(cornerRadius: 2)
                .fill(subjectColor)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            // 2. 체크박스
            Button(action: {
                withAnimation {
                    item.isCompleted.toggle()
                    try? context.save()
                }
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            
            // 3. 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body).fontWeight(.medium)
                    .strikethrough(item.isCompleted, color: .gray)
                    .foregroundColor(item.isCompleted ? .gray : .primary)
                
                HStack(spacing: 6) {
                    // 시간 표시
                    Image(systemName: "clock").font(.caption2)
                    Text("\(formatDate(item.startDate)) ~ \(formatDate(item.endDate ?? item.startDate))")
                        .font(.caption)
                    
                    // 과목 태그
                    Text(item.subject)
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subjectColor.opacity(0.1))
                        .foregroundColor(subjectColor)
                        .cornerRadius(4)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 4. 우측 메뉴 (더보기) -> 삭제/수정 등등
            // 4. 우측 메뉴 (더보기) -> 삭제/수정 등등
            Menu {
                // 완료 토글
                Button(action: {
                    withAnimation {
                        item.isCompleted.toggle()
                        try? context.save()
                    }
                }) {
                    Label(item.isCompleted ? "완료 취소" : "완료하기", systemImage: "checkmark")
                }
                
                Divider()
                
                // 미루기
                Menu("미루기") {
                    Button("1시간 뒤로") { postpone(1) }
                    Button("내일 이 시간으로") { postponeToTomorrow() }
                }
                
                Divider()
                
                Button(role: .destructive, action: { context.delete(item) }) {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(10)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm" // 오전/오후 시간
        return f.string(from: date)
    }

    // MARK: - Helper Methods
    func postpone(_ hours: Int) {
        item.startDate = item.startDate.addingTimeInterval(TimeInterval(hours * 3600))
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(TimeInterval(hours * 3600))
        }
        try? context.save()
    }
    
    func postponeToTomorrow() {
        item.startDate = item.startDate.addingTimeInterval(86400)
        if let end = item.endDate {
            item.endDate = end.addingTimeInterval(86400)
        }
        try? context.save()
    }
}
