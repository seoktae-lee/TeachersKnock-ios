import SwiftUI
import FirebaseAuth
import SwiftData

struct GroupScheduleView: View {
    var groupID: String
    var groupName: String
    var isLeader: Bool
    @ObservedObject var scheduleManager: GroupScheduleManager
    
    // ✨ [New] Local Sync
    @Environment(\.modelContext) private var modelContext
    
// ✨ [New] 편집용 state (기존 유지)
    @State private var editingSchedule: GroupSchedule?
    @State private var selectedDate = Date() // ✨ [Fixed] Missing State
    
    // Calendar Config
    @Environment(\.calendar) var calendar
    @Namespace var animation
    
    // ✨ [New] 햅틱 피드백
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Calendar
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding()
                .onChange(of: selectedDate) { newDate in
                    feedback.impactOccurred() // 햅틱
                    scheduleManager.listenToDailyMemo(groupID: groupID, date: newDate)
                }
            
            // 2. Content Scroll
            ScrollView {
                VStack(spacing: 20) {
                    
                    if let memo = scheduleManager.currentDailyMemo {
                        let schedules = scheduleManager.schedules(at: selectedDate, from: scheduleManager.groupSchedules)
                        
                        // ✨ [Logic] 스터디 없음 = 스케줄 없음 AND 메모 비어있음
                        if schedules.isEmpty && memo.isEmpty {
                            // Empty State
                             DailyMemoSection(memo: memo, isScheduleEmpty: true) { updatedMemo in
                                scheduleManager.updateDailyMemo(groupID: groupID, memo: updatedMemo) { _ in }
                            }
                            
                        } else {
                            // Study Exists (Memo or Schedules)
                            
                            // 1. Study Section (Memo/Location/Members)
                            DailyMemoSection(memo: memo, isScheduleEmpty: false) { updatedMemo in
                                scheduleManager.updateDailyMemo(groupID: groupID, memo: updatedMemo) { _ in }
                            }
                            
                            // 2. Schedule List
                            LazyVStack(spacing: 12) {
                                if !schedules.isEmpty {
                                    ForEach(schedules) { schedule in
                                        GroupScheduleRow(
                                            schedule: schedule,
                                            isLeader: isLeader,
                                            onDelete: {
                                                let isTimer = schedule.type == .timer
                                                scheduleManager.deleteSchedule(groupID: groupID, scheduleID: schedule.id, scheduleTitle: schedule.title, isCommonTimer: isTimer) { success in
                                                    // ✨ [동기화] 방장이 공통 타이머 일정 삭제 시 로컬 플래너에서도 삭제
                                                    if success && isLeader && isTimer {
                                                        deleteLocalSchedule(scheduleID: schedule.id)
                                                    }
                                                }
                                            },
                                            onEdit: {
                                                editingSchedule = schedule
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // 로딩 중 (데이터가 오기 전)
                        ProgressView()
                            .padding(.top, 50)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduleManager.listenToGroupSchedules(groupID: groupID)
            scheduleManager.listenToDailyMemo(groupID: groupID, date: selectedDate)
        }
        .sheet(item: $editingSchedule) { schedule in
            EditGroupScheduleView(scheduleManager: scheduleManager, schedule: schedule)
                .presentationDetents([.medium])
        }
    }

    
    // ✨ [New] Local Delete Sync
    func deleteLocalSchedule(scheduleID: String) {
        let uuidString = scheduleID
        guard let uuid = UUID(uuidString: uuidString) else { return }
        
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let item = try modelContext.fetch(descriptor).first {
                modelContext.delete(item)
                print("✅ [동기화] 로컬 일정 삭제 완료: \(item.title)")
            }
        } catch {
            print("❌ [동기화] 로컬 일정 삭제 실패: \(error)")
        }
    }
}



// ✨ [New] Daily Memo Component (Refined)
struct DailyMemoSection: View {
    var memo: DailyMemo
    var isScheduleEmpty: Bool
    var onUpdate: (DailyMemo) -> Void
    
    @State private var isEditing = false
    @State private var editContent = ""
    @State private var editLocation = ""
    @State private var editMembers = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if !isEditing && memo.isEmpty && isScheduleEmpty {
                // 완전 빈 상태 (Pure Empty State)
                 VStack(spacing: 15) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("오늘은 스터디가 없습니다.")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        startEditing()
                    }) {
                        Text("스터디 계획하기")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // 내용이 있거나 에디팅 중 (또는 스케줄은 있는데 메모는 비어있는 경우 -> 입력창 표시)
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("스터디 정보")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            if isEditing {
                                save()
                            } else {
                                startEditing()
                            }
                        }) {
                            Text(isEditing ? "완료" : "수정")
                                .font(.subheadline.bold())
                                .foregroundColor(isEditing ? .blue : .gray)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    
                    Divider()
                    
                    // Body
                    VStack(spacing: 0) {
                        if isEditing {
                            VStack(spacing: 0) {
                                InputRow(icon: "mappin.and.ellipse", placeholder: "스터디 장소", text: $editLocation)
                                Divider().padding(.leading, 34)
                                InputRow(icon: "person.2", placeholder: "참여 멤버", text: $editMembers)
                                Divider().padding(.leading, 34)
                                InputRow(icon: "doc.text", placeholder: "스터디 메모", text: $editContent, isMultiLine: true)
                            }
                            .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                DisplayRow(icon: "mappin.and.ellipse", text: memo.location.isEmpty ? "장소 미정" : memo.location)
                                Divider().padding(.leading, 34)
                                DisplayRow(icon: "person.2", text: memo.members.isEmpty ? "멤버 미정" : memo.members)
                                Divider().padding(.leading, 34)
                                DisplayRow(icon: "doc.text", text: memo.content.isEmpty ? "메모 없음" : memo.content)
                            }
                            .padding()
                        }
                    }
                    .background(Color.white)
                }
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }
    
    func startEditing() {
        editContent = memo.content
        editLocation = memo.location
        editMembers = memo.members
        isEditing = true
    }
    
    func save() {
        var newMemo = memo
        newMemo.content = editContent
        newMemo.location = editLocation
        newMemo.members = editMembers
        onUpdate(newMemo)
        isEditing = false
    }
}

// ✨ [New] Input Row (Standardized)
struct InputRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isMultiLine: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
                .padding(.top, 2)
            
            if isMultiLine {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.body)
            } else {
                TextField(placeholder, text: $text)
                    .font(.body)
            }
        }
        .padding(.vertical, 8)
    }
}

// ✨ [New] Display Row (Standardized)
struct DisplayRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue) // Stylish blue
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(text.contains("미정") || text.contains("없음") ? .gray : .primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// ✨ [Refined] GroupScheduleRow (Notice Style)
struct GroupScheduleRow: View {
    let schedule: GroupSchedule
    let isLeader: Bool
    var onDelete: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                 if schedule.type == .timer, let subject = schedule.subject {
                     HStack(spacing: 6) {
                         Text(subject)
                             .font(.caption.bold())
                             .foregroundColor(iconColor)
                             .padding(.horizontal, 6)
                             .padding(.vertical, 2)
                             .background(backgroundColor)
                             .cornerRadius(4)
                         
                         Text(schedule.title)
                             .font(.subheadline.bold())
                             .foregroundColor(.primary)
                     }
                } else {
                    Text(schedule.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                
                // Content (if any)
                if !schedule.content.isEmpty && schedule.content != schedule.title {
                    Text(schedule.content)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16) // More rounded
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isLeader || schedule.authorID == Auth.auth().currentUser?.uid {
                Button(role: .destructive, action: onDelete) {
                    Label("삭제", systemImage: "trash")
                }
                
                Button(action: onEdit) {
                    Label("수정", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }
    
    var backgroundColor: Color {
        switch schedule.type {
        case .notice: return Color.orange.opacity(0.1)
        case .timer: return Color.purple.opacity(0.1)
        case .pairing: return Color.green.opacity(0.1)
        case .gathering: return Color.blue.opacity(0.1)
        case .etc: return Color.gray.opacity(0.1)
        }
    }
    
    var iconName: String {
        switch schedule.type {
        case .notice: return "megaphone.fill"
        case .timer: return "stopwatch"
        case .pairing: return "arrow.triangle.2.circlepath"
        case .gathering: return "person.3.fill"
        case .etc: return "calendar"
        }
    }
    
    var iconColor: Color {
        switch schedule.type {
        case .notice: return .orange
        case .timer: return .purple
        case .pairing: return .green
        case .gathering: return .blue
        case .etc: return .gray
        }
    }
}
