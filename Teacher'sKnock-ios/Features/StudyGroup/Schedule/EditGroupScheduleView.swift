import SwiftUI
import FirebaseAuth
import SwiftData

struct EditGroupScheduleView: View {
    @ObservedObject var scheduleManager: GroupScheduleManager
    var schedule: GroupSchedule
    @Environment(\.dismiss) var dismiss
    
    // ✨ [New] Local Sync
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String
    @State private var content: String
    @State private var type: GroupSchedule.ScheduleType
    @State private var date: Date
    
    init(scheduleManager: GroupScheduleManager, schedule: GroupSchedule) {
        self.scheduleManager = scheduleManager
        self.schedule = schedule
        _title = State(initialValue: schedule.title)
        _content = State(initialValue: schedule.content)
        _type = State(initialValue: schedule.type)
        _date = State(initialValue: schedule.date)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("일정 제목", text: $title)
                    TextField("메모 (선택)", text: $content)
                }
                
                Section {
                    DatePicker("날짜", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("유형", selection: $type) {
                        ForEach(GroupSchedule.ScheduleType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section {
                    Text("💡 일정을 수정하면 스터디 그룹 공지사항에 자동으로 업데이트 알림이 등록됩니다.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("일정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("수정") {
                        updateSchedule()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    func updateSchedule() {
        var updatedSchedule = schedule
        updatedSchedule.title = title
        updatedSchedule.content = content
        updatedSchedule.date = date
        updatedSchedule.type = type
        
        scheduleManager.updateSchedule(schedule: updatedSchedule) { success in
            if success {
                // ✨ [동기화] 방장이 공통 타이머 일정 수정 시 로컬 플래너에서도 수정
                if updatedSchedule.type == .timer {
                    updateLocalSchedule(scheduleID: updatedSchedule.id, newTitle: title, newDate: date, newContent: content)
                }
                dismiss()
            }
        }
    }
    
    // ✨ [New] Local Update Sync
    func updateLocalSchedule(scheduleID: String, newTitle: String, newDate: Date, newContent: String) {
        guard let uuid = UUID(uuidString: scheduleID) else { return }
        
        do {
            let descriptor = FetchDescriptor<ScheduleItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let item = try modelContext.fetch(descriptor).first {
                item.title = newTitle
                item.startDate = newDate
                // 종료 시간은 시작 시간 + 1시간 (기본값) 또는 기존 기간 유지
                let duration = item.endDate?.timeIntervalSince(item.startDate) ?? 3600
                item.endDate = newDate.addingTimeInterval(duration)
                item.details = newContent
                print("✅ [동기화] 로컬 일정 수정 완료: \(item.title)")
            }
        } catch {
            print("❌ [동기화] 로컬 일정 수정 실패: \(error)")
        }
    }
}
