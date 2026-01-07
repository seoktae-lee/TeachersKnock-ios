import SwiftUI
import FirebaseAuth

struct AddGroupScheduleView: View {
    @ObservedObject var scheduleManager: GroupScheduleManager
    var groupID: String
    var selectedDate: Date
    
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var type: GroupSchedule.ScheduleType = .etc
    @State private var date: Date
    
    init(scheduleManager: GroupScheduleManager, groupID: String, selectedDate: Date) {
        self.scheduleManager = scheduleManager
        self.groupID = groupID
        self.selectedDate = selectedDate
        self._date = State(initialValue: selectedDate)
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
            }
            .navigationTitle("일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addSchedule()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    func addSchedule() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
        
        // 시간은 선택하지만, ScheduleRow는 날짜별로 보여짐
        let newSchedule = GroupSchedule(
            groupID: groupID,
            title: title,
            content: content,
            date: date,
            type: type,
            authorID: uid,
            authorName: nickname
        )
        
        scheduleManager.addSchedule(schedule: newSchedule) { success in
            if success {
                dismiss()
            }
        }
    }
}
