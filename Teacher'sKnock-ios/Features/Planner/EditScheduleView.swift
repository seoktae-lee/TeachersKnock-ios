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
    
    // 겹침 확인을 위한 기존 일정 목록
    @State private var existingSchedules: [ScheduleItem] = []
    
    var overlappingTitle: String? {
        // 나 자신을 제외하고, 미뤄지지 않은 일정들 중에서 겹치는 것 찾기
        let others = existingSchedules.filter { $0.id != item.id && !$0.isPostponed }
        
        for other in others {
            let otherEnd = other.endDate ?? other.startDate.addingTimeInterval(3600)
            // 겹침 판정
            if startDate < otherEnd && endDate > other.startDate {
                return other.title
            }
        }
        return nil
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
                        .onChange(of: startDate) { _ in fetchSchedules() } // 날짜 변경 시 재조회
                    
                    DatePicker("종료", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                        .tint(brandColor)
                    
                    // ✨ [겹침 경고]
                    if let conflict = overlappingTitle {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("'\(conflict)' 일정과 겹쳐요!")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
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
            .onAppear {
                fetchSchedules()
            }
        }
    }
    
    // 해당 날짜의 일정 불러오기
    private func fetchSchedules() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let ownerID = item.ownerID
        
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { target in
                target.ownerID == ownerID && target.startDate >= startOfDay && target.startDate < endOfDay
            }
        )
        
        do {
            existingSchedules = try modelContext.fetch(descriptor)
        } catch {
            print("일정 로드 실패: \(error)")
        }
    }
    
    private func saveChanges() {
        // 기존 객체에 덮어쓰기
        item.title = title
        item.details = details
        item.startDate = startDate
        item.endDate = endDate
        item.hasReminder = hasReminder
        
        // ✨ [알림] 변경된 내용으로 알림 업데이트
        NotificationManager.shared.updateNotifications(for: item)
        
        dismiss()
    }
    
    private func deleteSchedule() {
        // ✨ [알림] 삭제 시 알림 취소
        NotificationManager.shared.cancelNotifications(for: item)
        
        modelContext.delete(item)
        dismiss()
    }
}
