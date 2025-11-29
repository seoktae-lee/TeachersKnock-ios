import SwiftUI
import SwiftData

struct AddScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var details = ""
    @State private var scheduleDate = Date()
    @State private var hasReminder = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("일정 내용")) {
                    TextField("할 일을 입력하세요 (예: 교육학 3강 수강)", text: $title)
                    TextField("상세 메모 (선택)", text: $details)
                }
                
                Section(header: Text("날짜 및 시간")) {
                    DatePicker("날짜", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .accentColor(brandColor)
                }
                
                Section {
                    Toggle("중요 알림 설정", isOn: $hasReminder)
                        .tint(brandColor)
                }
            }
            .navigationTitle("새 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        addSchedule()
                    }
                    .foregroundColor(brandColor)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addSchedule() {
        let newItem = ScheduleItem(
            title: title,
            details: details,
            startDate: scheduleDate,
            isCompleted: false,
            hasReminder: hasReminder
        )
        modelContext.insert(newItem)
        dismiss()
    }
}
