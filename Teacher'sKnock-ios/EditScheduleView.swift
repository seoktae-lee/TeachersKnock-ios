import SwiftUI
import SwiftData

struct EditScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 수정할 대상 객체
    let item: ScheduleItem
    
    // 수정할 내용을 담을 상태 변수들
    @State private var title: String
    @State private var details: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasReminder: Bool
    
    // 초기화 시점에 기존 데이터를 State로 가져옴
    init(item: ScheduleItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _details = State(initialValue: item.details)
        _startDate = State(initialValue: item.startDate)
        _endDate = State(initialValue: item.endDate ?? item.startDate.addingTimeInterval(3600))
        _hasReminder = State(initialValue: item.hasReminder)
    }
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("내용 수정")) {
                    TextField("일정 제목", text: $title)
                        .font(.headline)
                    TextField("상세 메모", text: $details)
                }
                
                Section(header: Text("시간 변경")) {
                    DatePicker("시작", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .tint(brandColor)
                    
                    DatePicker("종료", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                        .tint(brandColor)
                }
                
                Section {
                    Toggle("시작 전 알림", isOn: $hasReminder)
                        .tint(brandColor)
                }
                
                // 삭제 버튼
                Section {
                    Button(role: .destructive, action: deleteSchedule) {
                        HStack {
                            Spacer()
                            Text("이 일정 삭제하기")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("일정 상세 및 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { saveChanges() }
                        .fontWeight(.bold)
                        .foregroundColor(brandColor)
                }
            }
        }
    }
    
    private func saveChanges() {
        // 기존 객체에 덮어쓰기
        item.title = title
        item.details = details
        item.startDate = startDate
        item.endDate = endDate
        item.hasReminder = hasReminder
        
        dismiss()
    }
    
    private func deleteSchedule() {
        modelContext.delete(item)
        dismiss()
    }
}
