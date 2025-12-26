import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    
    // 날짜 받아오는 기능은 유지 (오류 방지 및 편의성)
    init(selectedDate: Date = Date()) {
        let now = Date()
        let calendar = Calendar.current
        
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        let start = calendar.date(from: components) ?? selectedDate
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }
    
    // 유저 ID (TimeTableView용)
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 타임테이블 (상단 고정, 높이 제한)
            // 현재 날짜의 스케줄을 참고할 수 있도록 함
            VStack(alignment: .leading) {
                Text("Time Table (06:00 ~ 02:00)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                HorizontalTimelineView(date: startDate, userId: currentUserId)
                    .frame(height: 80) // 한눈에 보기 적당한 높이
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            Divider().padding(.vertical, 10)
            
            // 2. 입력 폼
            Form {
                Section(header: Text("일정 정보")) {
                    TextField("일정 제목 (예: 교육학 인강 듣기)", text: $title)
                }
                
                Section(header: Text("시간 설정")) {
                    DatePicker("시작", selection: $startDate, displayedComponents: [.hourAndMinute])
                    DatePicker("종료", selection: $endDate, displayedComponents: [.hourAndMinute])
                }
            }
            .scrollContentBackground(.hidden) // 배경색 조화
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("일정 추가")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    saveSchedule()
                }
                .disabled(title.isEmpty)
            }
        }
    }
    
    private func saveSchedule() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // subject 없이 저장
        let newSchedule = ScheduleItem(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            ownerID: uid
        )
        
        modelContext.insert(newSchedule)
        dismiss()
    }
}
