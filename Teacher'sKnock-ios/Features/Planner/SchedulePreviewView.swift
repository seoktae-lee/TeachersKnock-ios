import SwiftUI

struct SchedulePreviewView: View {
    let existingSchedules: [ScheduleItem]
    let draftSchedule: ScheduleItem?
    
    // 삭제 요청을 부모 뷰(ViewModel)로 전달하기 위한 클로저
    var onDelete: ((ScheduleItem) -> Void)?
    
    // 날짜별로 일정을 묶기 위한 구조체
    struct DailySection: Identifiable {
        let id = UUID()
        let date: Date
        let items: [ScheduleItem]
    }
    
    // 데이터를 날짜별 섹션으로 변환
    var sections: [DailySection] {
        // 1. 전체 아이템 합치기 (미뤄진 일정 제외)
        var items = existingSchedules.filter { !$0.isPostponed }
        if let draft = draftSchedule {
            items.append(draft)
        }
        
        // 2. 시간순 정렬
        let sortedItems = items.sorted { $0.startDate < $1.startDate }
        
        // 3. 날짜별 그룹화
        let grouped = Dictionary(grouping: sortedItems) { item in
            Calendar.current.startOfDay(for: item.startDate)
        }
        
        // 4. 날짜순으로 섹션 정렬
        return grouped.map { DailySection(date: $0.key, items: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        LazyVStack(spacing: 20) {
            if sections.isEmpty {
                Text("표시할 일정이 없습니다.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        // ✨ 날짜 헤더 (날짜가 바뀔 때만 표시)
                        HStack {
                            Text(formatSectionDate(section.date))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // 해당 날짜의 일정들
                        ForEach(section.items) { item in
                            timelineRow(for: item)
                                .contextMenu { // ✨ 꾹 눌러서 삭제 (기존 일정만 가능)
                                    if item.id != draftSchedule?.id {
                                        Button(role: .destructive) {
                                            onDelete?(item)
                                        } label: {
                                            Label("삭제하기", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    // 섹션 날짜 포맷 (예: 12월 4일 (목))
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
    
    private func timelineRow(for item: ScheduleItem) -> some View {
        let isDraft = (item.id == draftSchedule?.id)
        
        return HStack(alignment: .top, spacing: 15) {
            // 1. 시간 표시 (왼쪽)
            VStack(alignment: .trailing) {
                Text(item.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(item.endDate?.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 60, alignment: .trailing)
            
            // 2. 타임라인 선과 점 (중앙)
            VStack(spacing: 0) {
                Circle()
                    .fill(isDraft ? Color.orange : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                
                // 마지막 아이템 체크가 복잡해졌으므로, 단순히 긴 선을 그림 (섹션 내부에서 처리 가능하지만 생략)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                    .frame(minHeight: 35)
            }
            
            // 3. 일정 카드 (오른쪽)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "(새 일정)" : item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isDraft ? .white : .primary)
                    .strikethrough(item.isCompleted)
                
                if !item.details.isEmpty {
                    Text(item.details)
                        .font(.caption)
                        .foregroundColor(isDraft ? .white.opacity(0.8) : .gray)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDraft ? Color.orange : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDraft ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }
}
