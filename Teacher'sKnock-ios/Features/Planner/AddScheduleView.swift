import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 뷰모델 연결
    @StateObject private var viewModel: AddScheduleViewModel
    
    init(selectedDate: Date, scheduleToEdit: ScheduleItem? = nil) {
        let uid = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: AddScheduleViewModel(userId: uid, selectedDate: selectedDate, scheduleToEdit: scheduleToEdit))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // MARK: - 미리보기
                    PreviewSection(viewModel: viewModel)
                    
                    Divider()
                    
                    // MARK: - 1. 어떤 일정인가요? (공부 목적 UI 개선됨 ✨)
                    SelectionSection(viewModel: viewModel)
                    
                    // ✨ [New] 공통 타이머 설정
                    CommonTimerSection(viewModel: viewModel)
                    
                    // MARK: - 2. 제목 입력
                    TitleSection(viewModel: viewModel)
                    
                    // MARK: - 3. 시간 설정
                    TimeSection(viewModel: viewModel)
                    
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
            .background(Color.white)
            .navigationTitle(viewModel.editingSchedule == nil ? "새 일정" : "일정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        viewModel.saveSchedule { dismiss() }
                    }
                    .fontWeight(.bold)
                    .disabled(viewModel.title.isEmpty)
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                
                // ✨ [수정] 새 일정 추가 모드일 때만 '이어달리기' 시간 자동 설정
                if viewModel.editingSchedule == nil {
                    viewModel.autoSetStartTimeToLastSchedule()
                } else if viewModel.isCommonTimer {
                    // 수정 모드이고 공통 타이머가 켜져있다면 그룹 정보를 불러와야 권한 체크 가능
                    viewModel.fetchMyStudyGroups()
                }
                
                if viewModel.isStudySubject && !settingsManager.favoriteSubjects.isEmpty {
                    let allNames = settingsManager.favoriteSubjects.map { $0.name }
                    if !allNames.contains(viewModel.selectedSubject) {
                        viewModel.selectedSubject = allNames.first ?? ""
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct PreviewSection: View {
    @ObservedObject var viewModel: AddScheduleViewModel
    @State private var isAppearing = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("미리보기")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 1. 배경
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 40)
                    
                    // 2. 기존 일정 (회색)
                    ForEach(viewModel.existingSchedules) { schedule in
                        TimeBlockView(start: schedule.startDate, end: schedule.endDate ?? schedule.startDate, totalWidth: geo.size.width, color: .gray.opacity(0.3))
                    }
                    
                    // 현재 선택된 과목의 색상 가져오기
                    let currentColor: Color = viewModel.isStudySubject
                        ? SubjectName.color(for: viewModel.selectedSubject)
                        : Color.green
                    
                    // 3. 현재 추가 중인 일정
                    TimeBlockView(start: viewModel.startDate, end: viewModel.endDate, totalWidth: geo.size.width, color: currentColor)
                        .shadow(radius: 2)
                        .offset(x: isAppearing ? 0 : geo.size.width)
                }
            }
            .frame(height: 40)
            .padding(.horizontal)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    isAppearing = true
                }
            }
            
            HStack {
                Text("0시").font(.caption2)
                Spacer()
                Text("12시").font(.caption2)
                Spacer()
                Text("24시").font(.caption2)
            }
            .foregroundColor(.gray)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct TimeBlockView: View {
    let start: Date
    let end: Date
    let totalWidth: CGFloat
    let color: Color
    
    var body: some View {
        let startP = percentOfDay(for: start)
        let endP = percentOfDay(for: end)
        let validStart = max(0, min(1, startP))
        let validEnd = max(0, min(1, endP))
        let width = max(CGFloat(validEnd - validStart) * totalWidth, 2)
        let offset = CGFloat(validStart) * totalWidth
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: width, height: 30)
            .offset(x: offset)
    }
    
    private func percentOfDay(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: date))
        let minute = Double(calendar.component(.minute, from: date))
        return (hour * 60 + minute) / (24 * 60)
    }
}

struct SelectionSection: View {
    @ObservedObject var viewModel: AddScheduleViewModel
    @EnvironmentObject var settingsManager: SettingsManager
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "1.circle.fill").foregroundColor(.blue)
                Text("어떤 일정을 추가할까요?").font(.headline)
            }
            .padding(.horizontal)
            
            // 1. 루틴 선택 (기존 코드)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.routines) { routine in
                        Button(action: {
                            feedback.impactOccurred()
                            withAnimation { viewModel.applyRoutine(routine) }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: routine.icon).font(.title3)
                                Text(routine.label).font(.caption).bold()
                            }
                            .frame(width: 70, height: 70)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.title == routine.title ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            }
            
            // 2. 카테고리 선택 (기존 코드)
            VStack(alignment: .leading) {
                Picker("분류", selection: $viewModel.isStudySubject) {
                    Text("✍️ 공부").tag(true)
                    Text("🌱 생활").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let items: [String] = viewModel.isStudySubject
                            ? settingsManager.favoriteSubjects.map { $0.name }
                            : viewModel.lifeCategories
                        
                        if items.isEmpty && viewModel.isStudySubject {
                            Text("등록된 과목이 없습니다.").font(.caption).foregroundColor(.gray).padding()
                        } else {
                            ForEach(items, id: \.self) { item in
                                Button(action: {
                                    feedback.impactOccurred()
                                    viewModel.selectCategory(item, isStudy: viewModel.isStudySubject)
                                }) {
                                    let isSelected = viewModel.selectedSubject == item
                                    let buttonColor = viewModel.isStudySubject ? SubjectName.color(for: item) : Color.green
                                    
                                    Text(item)
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? buttonColor : Color.gray.opacity(0.1))
                                        .foregroundColor(isSelected ? .white : .gray)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                }
            }
            
            // ✨ [추천 스타일] 공부 목적 선택 (가로 스크롤 칩)
            if viewModel.isStudySubject {
                VStack(alignment: .leading, spacing: 8) {
                    Text("공부 목적").font(.caption).foregroundColor(.gray).padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                let isSelected = viewModel.selectedPurpose == purpose
                                
                                Button(action: {
                                    feedback.impactOccurred()
                                    withAnimation { viewModel.selectedPurpose = purpose }
                                }) {
                                    Text(purpose.localizedName)
                                        .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10) // 터치 영역 확보
                                        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .foregroundColor(isSelected ? .blue : .gray)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct TitleSection: View {
    @ObservedObject var viewModel: AddScheduleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "2.circle.fill").foregroundColor(.blue)
                Text("제목을 입력해주세요").font(.headline)
            }
            .padding(.horizontal)

            TextField("예: 전공 서적 읽기", text: $viewModel.title)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }
}

struct TimeSection: View {
    @ObservedObject var viewModel: AddScheduleViewModel
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "3.circle.fill").foregroundColor(.blue)
                Text("시간을 설정해주세요").font(.headline)
                
                // 날짜 표시
                Text("(\(viewModel.formattedDateString))")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 총 시간 표시
                Text("총 \(viewModel.durationString)")
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
            .padding(.horizontal)
            
            // ✨ [수정] 커스텀 피커 버튼 영역
            HStack(spacing: 0) {
                timeButton(title: "시작", date: viewModel.startDate) {
                    showingStartPicker = true
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)
                    .frame(width: 40)
                    .padding(.top, 20) // 텍스트 높이 고려하여 정렬 맞춤
                
                timeButton(title: "종료", date: viewModel.endDate) {
                    showingEndPicker = true
                }
            }
            .padding(.horizontal)
            
            // 시간 조절 버튼들
            HStack(spacing: 8) {
                Button("+10분") { feedback.impactOccurred(); viewModel.addDuration(10) }.frame(maxWidth: .infinity)
                Button("+30분") { feedback.impactOccurred(); viewModel.addDuration(30) }.frame(maxWidth: .infinity)
                Button("+1시간") { feedback.impactOccurred(); viewModel.addDuration(60) }.frame(maxWidth: .infinity)
                Button("-10분") { feedback.impactOccurred(); viewModel.addDuration(-10) }.frame(maxWidth: .infinity).tint(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.horizontal)
            
            if let conflict = viewModel.overlappingScheduleTitle {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("'\(conflict)' 일정과 겹쳐요!")
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal)
            }
            
            // 알림 설정 토글
            Toggle(isOn: $viewModel.hasReminder) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(viewModel.hasReminder ? .blue : .gray)
                    Text("시작 알림 받기")
                        .font(.system(size: 16))
                    if viewModel.hasReminder {
                        Text("(정시 + 10분 전)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
            .onChange(of: viewModel.hasReminder) { newValue in
                if newValue {
                     NotificationManager.shared.requestAuthorization()
                }
            }
        }
        .sheet(isPresented: $showingStartPicker) {
            SingleDayTimePicker(selection: Binding(
                get: { viewModel.startDate },
                set: { newDate in
                    let duration = viewModel.endDate.timeIntervalSince(viewModel.startDate)
                    viewModel.startDate = newDate
                    viewModel.endDate = newDate.addingTimeInterval(duration)
                }
            ), title: "시작 시간 설정")
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingEndPicker) {
            SingleDayTimePicker(selection: Binding(
                get: { viewModel.endDate },
                set: { newDate in
                    // 종료 시간 선택 시, 날짜가 꼬이는 문제(예: 24시간, 72시간 등)를 방지하기 위해
                    // 시작 날짜와 동일한 날짜로 강제 보정합니다.
                    // (오버나이트 일정은 ViewModel의 effectiveEndDate 로직이 처리)
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: newDate)
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: viewModel.startDate)
                    dateComponents.hour = timeComponents.hour
                    dateComponents.minute = timeComponents.minute
                    
                    if let resetDate = calendar.date(from: dateComponents) {
                        viewModel.endDate = resetDate
                    } else {
                        viewModel.endDate = newDate
                    }
                }
            ), title: "종료 시간 설정")
                .presentationDetents([.height(300)])
        }
    }
    
    // 시간 표시 버튼 헬퍼
    func timeButton(title: String, date: Date, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title).font(.caption).foregroundColor(.gray)
                HStack {
                    Text(formatTime(date))
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}

// ✨ [추가] 커스텀 휠 피커 (날짜 변경 없는 순수 시간 선택기)
struct SingleDayTimePicker: View {
    @Binding var selection: Date
    let title: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            // 헤더
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("완료") {
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 휠 피커 영역
            HStack(spacing: 0) {
                // 시간 (0~23)
                Picker("시간", selection: Binding(
                    get: { Calendar.current.component(.hour, from: selection) },
                    set: { newHour in
                        let calendar = Calendar.current
                        if let newDate = calendar.date(bySetting: .hour, value: newHour, of: selection) {
                            selection = newDate
                        }
                    }
                )) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)시").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                
                // 분 (0~59)
                Picker("분", selection: Binding(
                    get: { Calendar.current.component(.minute, from: selection) },
                    set: { newMinute in
                        let calendar = Calendar.current
                        if let newDate = calendar.date(bySetting: .minute, value: newMinute, of: selection) {
                            selection = newDate
                        }
                    }
                )) {
                    ForEach(0..<60) { minute in
                        Text("\(minute)분").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.white)
    }
}

// ✨ [New] 공통 타이머 섹션
struct CommonTimerSection: View {
    @ObservedObject var viewModel: AddScheduleViewModel
    @State private var showingGroupSelection = false
    
    var body: some View {
        // 공부 스케줄인 경우에만 표시 + 말하기가 아닐 때만 표시
        if viewModel.isStudySubject && viewModel.selectedPurpose != .speaking {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "timer.square").foregroundColor(.blue)
                    Text("공통 타이머 사용").font(.headline)
                    Spacer()
                    Toggle("", isOn: $viewModel.isCommonTimer)
                        .labelsHidden()
                        .onChange(of: viewModel.isCommonTimer) { newValue in
                            if newValue {
                                // 켜면 그룹 목록 로드
                                viewModel.fetchMyStudyGroups()
                            }
                        }
                }
                .padding(.horizontal)
                
                if viewModel.isCommonTimer {
                    if viewModel.myStudyGroups.isEmpty {
                        Text("가입된 스터디 그룹이 없습니다.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.myStudyGroups) { group in
                                    Button(action: {
                                        withAnimation { viewModel.targetGroupID = group.id }
                                    }) {
                                        VStack(spacing: 6) {
                                            Image(systemName: "person.3.fill")
                                                .font(.headline)
                                            Text(group.name)
                                                .font(.caption2)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(viewModel.targetGroupID == group.id ? Color.blue.opacity(0.1) : Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(viewModel.targetGroupID == group.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                        )
                                        .foregroundColor(viewModel.targetGroupID == group.id ? .blue : .gray)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
}
