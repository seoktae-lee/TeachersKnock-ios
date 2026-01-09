import SwiftUI
import FirebaseAuth
import SwiftData

struct GroupScheduleView: View {
    var groupID: String
    var groupName: String
    var isLeader: Bool
    
    // ✨ [Modified] View owns the StateObject -> Lifecycle Fix!
    @StateObject private var scheduleManager = GroupScheduleManager()
    
    // Local Sync
    @Environment(\.modelContext) private var modelContext
    
    // State
    @State private var editingSchedule: GroupSchedule?
    @State private var selectedDate = Date()
    @State private var isAddingSchedule = false
    
    // Haptics
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Calendar Section
                    VStack {
                        DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .onChange(of: selectedDate) { newDate in
                        feedback.impactOccurred()
                        scheduleManager.listenToDailyMemo(groupID: groupID, date: newDate)
                    }
                    
                    // 2. Daily Content Section
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Header for the selected date
                        Text(dateHeaderString(selectedDate))
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        // 2-1. Daily Memo (Study Info)
                        // ✨ [Logic Improved] Prioritize Loading -> Then Content -> Then Empty Check
                        if scheduleManager.isLoadingMemo {
                             HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                            .frame(height: 100) // Prevent layout collapse
                        } else {
                            // If memo exists (even empty), show it. If nil (initial load fail?), show empty state.
                            if let memo = scheduleManager.currentDailyMemo {
                                DailyMemoCard(memo: memo, groupID: groupID, scheduleManager: scheduleManager)
                                    .padding(.horizontal)
                            } else {
                                // Fallback loading (shouldn't happen often if listenToDailyMemo works)
                                ProgressView()
                                    .padding()
                            }
                        }
                        
                        // 2-2. Schedule List (Shared Schedules)
                        let schedules = scheduleManager.schedules(at: selectedDate, from: scheduleManager.groupSchedules)
                        
                        // ✨ [Logic Improved] Always show schedules list area
                        LazyVStack(spacing: 12) {
                            if schedules.isEmpty {
                                // Empty Schedule State
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray.opacity(0.3))
                                        Text("등록된 일정이 없습니다.")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 30)
                            } else {
                                ForEach(schedules) { schedule in
                                    GroupScheduleRow(
                                        schedule: schedule,
                                        isLeader: isLeader,
                                        onDelete: {
                                            deleteSchedule(schedule)
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
                    .padding(.bottom, 80) // Space for FAB
                }
            } // End of ScrollView
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(groupName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // ✨ Ensure Listeners are only set once or updated correctly
            scheduleManager.listenToGroupSchedules(groupID: groupID)
            scheduleManager.listenToDailyMemo(groupID: groupID, date: selectedDate)
        }
        .sheet(item: $editingSchedule) { schedule in
            EditGroupScheduleView(scheduleManager: scheduleManager, schedule: schedule)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isAddingSchedule) {
            AddGroupScheduleView(scheduleManager: scheduleManager, groupID: groupID, selectedDate: selectedDate)
                .presentationDetents([.medium])
        }
    }
    
    // Helpers
    func dateHeaderString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: date)
    }
    
    func deleteSchedule(_ schedule: GroupSchedule) {
        let isTimer = schedule.type == .timer
        scheduleManager.deleteSchedule(groupID: groupID, scheduleID: schedule.id, scheduleTitle: schedule.title, isCommonTimer: isTimer) { success in
            if success && isLeader && isTimer {
                deleteLocalSchedule(scheduleID: schedule.id)
            }
        }
    }
    
    func deleteLocalSchedule(scheduleID: String) {
        let uuidString = scheduleID
        guard let uuid = UUID(uuidString: uuidString) else { return }
        
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let item = try modelContext.fetch(descriptor).first {
                modelContext.delete(item)
            }
        } catch {
            print("Failed to delete local schedule: \(error)")
        }
    }
}

// ✨ [New] Daily Memo Card matching the style
struct DailyMemoCard: View {
    var memo: DailyMemo
    var groupID: String
    var scheduleManager: GroupScheduleManager
    
    @State private var isEditing = false
    @State private var editContent = ""
    @State private var editLocation = ""
    @State private var editMembers = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Edit Button
            HStack {
                Text("오늘의 스터디 정보")
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
                        .font(.caption.bold())
                        .foregroundColor(isEditing ? .blue : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            
            Divider()
            
            // Content
            VStack(spacing: 0) {
                if isEditing {
                    VStack(spacing: 0) { // spacing 0 to allow dividers to look connected if needed, but here we use standard spacing
                        InputRow(icon: "mappin.and.ellipse", placeholder: "장소", text: $editLocation)
                        Divider().padding(.leading, 34)
                        InputRow(icon: "person.2", placeholder: "참여 멤버", text: $editMembers)
                        Divider().padding(.leading, 34)
                        InputRow(icon: "doc.text", placeholder: "메모", text: $editContent, isMultiLine: true)
                    }
                    .padding(16)
                } else {
                    // check if empty
                    if memo.location.isEmpty && memo.members.isEmpty && memo.content.isEmpty {
                         HStack {
                            Spacer()
                            Text("등록된 정보가 없습니다.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if !memo.location.isEmpty { DisplayRow(icon: "mappin.and.ellipse", text: memo.location) }
                            if !memo.location.isEmpty && (!memo.members.isEmpty || !memo.content.isEmpty) { Divider().padding(.leading, 34) }
                            
                            if !memo.members.isEmpty { DisplayRow(icon: "person.2", text: memo.members) }
                            if !memo.members.isEmpty && !memo.content.isEmpty { Divider().padding(.leading, 34) }
                            
                            if !memo.content.isEmpty { DisplayRow(icon: "doc.text", text: memo.content) }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
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
        scheduleManager.updateDailyMemo(groupID: groupID, memo: newMemo) { _ in }
        isEditing = false
    }
}

// Reusing InputRow and DisplayRow
struct InputRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isMultiLine: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(width: 20, height: 20)
                .padding(.top, 4)
            
            if isMultiLine {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.subheadline)
            } else {
                TextField(placeholder, text: $text)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DisplayRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
                .padding(.top, 2)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

// ✨ [New] GroupScheduleRow Style matching NoticeRow
struct GroupScheduleRow: View {
    let schedule: GroupSchedule
    let isLeader: Bool
    var onDelete: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(schedule.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Content (Time or Description)
                if schedule.type == .timer {
                    HStack(spacing: 6) {
                        Text(timeString(schedule.date))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // ✨ [New] 과목 표시
                        if let subject = schedule.subject, !subject.isEmpty {
                            Text(subject)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                } else {
                    Text(schedule.content)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // ✨ [Removed] 자동화된 시스템이므로 수동 편집/삭제 메뉴 제거
            // (사용자 요청: "자동 시스템이니까 이거는 없애자")
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
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
    
    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: date)
    }
}
