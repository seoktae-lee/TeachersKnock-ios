import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 입력 상태
    @State private var title = ""
    @State private var details = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasReminder = false
    
    // 인터랙션 감지
    @State private var hasInteracted = false
    
    // ✨ [NEW] 수정할 기존 일정을 저장할 변수
    @State private var selectedExistingSchedule: ScheduleItem? = nil
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        let minute = components.minute ?? 0
        components.minute = minute < 30 ? 30 : 0
        if minute >= 30 { components.hour = (components.hour ?? 0) + 1 }
        
        let roundedStart = calendar.date(from: components) ?? now
        let oneHourLater = roundedStart.addingTimeInterval(3600)
        
        _startDate = State(initialValue: roundedStart)
        _endDate = State(initialValue: oneHourLater)
    }
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var draftSchedule: ScheduleItem {
        ScheduleItem(
            title: title,
            details: details,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            hasReminder: hasReminder,
            ownerID: currentUserId
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 상단: 타임라인 미리보기
                ZStack(alignment: .bottom) {
                    TimelinePreviewContainer(
                        date: startDate,
                        userId: currentUserId,
                        draftItem: hasInteracted ? draftSchedule : nil,
                        // ✨ [NEW] 타임라인의 기존 일정 클릭 시 실행
                        onItemTap: { item in
                            selectedExistingSchedule = item
                        }
                    )
                    .background(Color.white)
                    
                    // 하단 그라데이션
                    LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                        .frame(height: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // 2. 하단: 입력 컨트롤 영역
                VStack(spacing: 15) {
                    // 핸들바
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    
                    // 제목 입력
                    TextField("일정 제목 (예: 교육학 암기)", text: $title)
                        .font(.headline)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .onChange(of: title) { _, _ in hasInteracted = true }
                    
                    // 시간 선택기
                    HStack {
                        VStack(alignment: .center, spacing: 5) {
                            Text("시작").font(.caption).foregroundColor(.gray)
                            DatePicker("", selection: $startDate, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .onChange(of: startDate) { _, _ in hasInteracted = true }
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.caption)
                        
                        VStack(alignment: .center, spacing: 5) {
                            Text("종료").font(.caption).foregroundColor(.gray)
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .onChange(of: endDate) { _, _ in hasInteracted = true }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    
                    // 옵션
                    Toggle("시작 전 알림", isOn: $hasReminder)
                        .padding(.horizontal)
                        .tint(brandColor)
                    
                    // 저장 버튼
                    Button(action: addSchedule) {
                        Text("일정 추가하기")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.gray.opacity(0.5) : brandColor)
                            .cornerRadius(12)
                    }
                    .disabled(title.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, y: -5)
            }
            .navigationTitle("새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            // ✨ [NEW] 기존 일정 클릭 시 수정 시트 띄우기
            .sheet(item: $selectedExistingSchedule) { item in
                EditScheduleView(item: item)
            }
        }
    }
    
    private func addSchedule() {
        modelContext.insert(draftSchedule)
        dismiss()
    }
}

// ✨ 헬퍼 뷰 수정: onItemTap 클로저 전달 기능 추가
struct TimelinePreviewContainer: View {
    let date: Date
    let userId: String
    let draftItem: ScheduleItem?
    // ✨ 터치 이벤트 전달받을 변수
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    @Query private var existingSchedules: [ScheduleItem]
    
    init(date: Date, userId: String, draftItem: ScheduleItem?, onItemTap: ((ScheduleItem) -> Void)? = nil) {
        self.date = date
        self.userId = userId
        self.draftItem = draftItem
        self.onItemTap = onItemTap
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _existingSchedules = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
        }, sort: \.startDate)
    }
    
    var body: some View {
        DailyTimelineView(
            schedules: existingSchedules,
            draftSchedule: draftItem,
            onItemTap: onItemTap // ✨ DailyTimelineView로 전달
        )
    }
}
