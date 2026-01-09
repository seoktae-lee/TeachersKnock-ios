import SwiftUI

struct NoticeSheet: View {
    @Binding var group: StudyGroup
    let isLeader: Bool
    @ObservedObject var studyManager: StudyGroupManager
    @Environment(\.dismiss) var dismiss
    
    @State private var noticeText: String = ""
    @State private var isAdding: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if displayNotices.isEmpty {
                    // Empty State
                     VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("새로운 공지사항이 없습니다.")
                            .font(.body)
                            .foregroundColor(.gray)
                        Text("지난 알림은 공유 일정표에서 확인하세요.")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(displayNotices) { notice in
                            NoticeRow(notice: notice)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    
                    // ✨ [New] 모두 확인 버튼
                    Button(action: {
                        studyManager.updateReadStatus(groupID: group.id)
                        dismiss()
                    }) {
                        Text("모두 확인 및 닫기")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding()
                    }
                }
            }
            .navigationTitle("공지사항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        // 닫을 때 읽음 처리
                        studyManager.updateReadStatus(groupID: group.id)
                        dismiss()
                    }
                }
                
                if isLeader {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { isAdding = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                NavigationStack {
                    VStack {
                        TextEditor(text: $noticeText)
                            .padding()
                            .navigationTitle("새 공지사항")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("취소") {
                                        isAdding = false
                                        noticeText = ""
                                    }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("등록") {
                                        addNotice()
                                    }
                                    .disabled(noticeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                    }
                }
                .presentationDetents([.medium])
            }
            .onDisappear {
               studyManager.updateReadStatus(groupID: group.id)
            }
        }
    }
    
    // ✨ [New] 표시할 공지사항 (방장 공지는 고정, 나머지는 안 읽은 것 + 최근 24시간 내 알림)
    var displayNotices: [StudyGroup.NoticeItem] {
        let key = "lastReadNotice_\(group.id)"
        let lastRead = UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast
        
        let filtered = group.notices.filter { notice in
            // 1. 방장 공지(.announcement)는 항상 표시
            if notice.type == .announcement { return true }
            
            // 2. 안 읽은 공지는 표시 (읽으면 즉시 사라짐)
            return notice.date > lastRead.addingTimeInterval(1)
        }
        
        // ✨ 정렬: 공지사항(announcement)을 최상단에 고정, 나머지는 최신순
        return filtered.sorted { (n1, n2) -> Bool in
            if n1.type == .announcement && n2.type != .announcement { return true }
            if n1.type != .announcement && n2.type == .announcement { return false }
            return n1.date > n2.date
        }
    }
    
    func addNotice() {
        studyManager.addNotice(groupID: group.id, content: noticeText)
        isAdding = false
        noticeText = ""
    }
}

// ✨ [New] 공지사항 행 디자인 (아이콘 + 내용)
struct NoticeRow: View {
    let notice: StudyGroup.NoticeItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Content
                Text(notice.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    // Date
                    Text(dateString(notice.date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // ✨ [New] 공통 타이머 공지일 경우 과목 표시
                    if notice.type == .timer, let subject = notice.subject, !subject.isEmpty {
                        Text(subject)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
    }
    
    var backgroundColor: Color {
        switch notice.type {
        case .announcement: return Color.red.opacity(0.1) // ✨ Red for Announcement
        case .general: return Color.blue.opacity(0.1)
        case .timer: return Color.purple.opacity(0.1)
        case .pairing: return Color.green.opacity(0.1)
        }
    }
    
    var iconName: String {
        switch notice.type {
        case .announcement: return "megaphone.fill"       // ✨ Megaphone
        case .general: return "calendar"
        case .timer: return "stopwatch"
        case .pairing: return "arrow.triangle.2.circlepath"
        }
    }
    
    var iconColor: Color {
        switch notice.type {
        case .announcement: return .red
        case .general: return .blue
        case .timer: return .purple
        case .pairing: return .green
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d a h:mm"
        return f.string(from: date)
    }
}
