import SwiftUI
import FirebaseAuth

struct GroupScheduleView: View {
    var groupID: String
    var groupName: String
    var isLeader: Bool
    @ObservedObject var scheduleManager: GroupScheduleManager
    
    @Binding var selectedDate: Date
    @State private var showingAddSheet = false
    // ✨ [New] 편집용 state
    @State private var editingSchedule: GroupSchedule?
    
    // Calendar Config
    @Environment(\.calendar) var calendar
    @Namespace var animation
    
    var body: some View {
        VStack {
            // Calendar
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding()
            
            // Events List
            List {
                ForEach(scheduleManager.schedules(at: selectedDate, from: scheduleManager.groupSchedules)) { schedule in
                    GroupScheduleRow(
                        schedule: schedule,
                        isLeader: isLeader,
                        onDelete: {
                            scheduleManager.deleteSchedule(groupID: groupID, scheduleID: schedule.id) { _ in }
                        },
                        onEdit: {
                            editingSchedule = schedule
                        }
                    )
                }
                
                if scheduleManager.schedules(at: selectedDate, from: scheduleManager.groupSchedules).isEmpty {
                    Text("일정이 없습니다.")
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(groupName) // 헤더 타이틀
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // 방장 혹은 멤버 모두에게 일정 추가 권한 부여
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            scheduleManager.listenToGroupSchedules(groupID: groupID)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddGroupScheduleView(scheduleManager: scheduleManager, groupID: groupID, selectedDate: selectedDate)
                .presentationDetents([.medium])
        }
        .sheet(item: $editingSchedule) { schedule in
            EditGroupScheduleView(scheduleManager: scheduleManager, schedule: schedule)
                .presentationDetents([.medium])
        }
    }
}

struct GroupScheduleRow: View {
    let schedule: GroupSchedule
    let isLeader: Bool
    var onDelete: () -> Void
    // ✨ [New] 편집 액션 클로저 추가
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: schedule.type.icon)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(typeColor(schedule.type))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.subheadline.bold())
                
                if !schedule.content.isEmpty {
                    Text(schedule.content)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete Action (작성자 or 리더)
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
    
    func typeColor(_ type: GroupSchedule.ScheduleType) -> Color {
        switch type {
        case .notice: return .orange
        case .pairing: return .green
        case .timer: return .purple
        case .gathering: return .blue
        case .etc: return .gray
        }
    }
}
