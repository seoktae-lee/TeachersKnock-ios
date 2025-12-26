import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    
    @StateObject private var viewModel: AddScheduleViewModel
    @FocusState private var isTitleFocused: Bool
    
    init(selectedDate: Date = Date()) {
        let uid = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: AddScheduleViewModel(userId: uid, selectedDate: selectedDate))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 타임라인 미리보기 + 총 시간 (상단 고정)
                previewSection
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // ✨ 2. [NEW] 퀵 루틴 (가장 먼저 배치)
                        // 수험생이 자주 쓰는 패턴을 원터치로 입력
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                                Text("자주 쓰는 루틴 불러오기")
                                    .font(.headline).foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.routines) { routine in
                                        RoutineButton(routine: routine) {
                                            triggerHapticFeedback(style: .medium) // 햅틱 톡!
                                            withAnimation {
                                                viewModel.applyRoutine(routine)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 20)
                        
                        Divider().padding(.horizontal)
                        
                        // 3. 카테고리 선택
                        VStack(alignment: .leading, spacing: 15) {
                            Text("1. 무슨 일정을 등록하시나요?")
                                .font(.headline).foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            // A. 공부 과목
                            VStack(alignment: .leading, spacing: 8) {
                                Text("✍️ 공부 과목").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                                    .padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(settingsManager.favoriteSubjects) { subject in
                                            SubjectChip(
                                                name: subject.name,
                                                isSelected: viewModel.selectedSubject == subject.name,
                                                color: SubjectName.color(for: subject.name)
                                            ) {
                                                triggerHapticFeedback(style: .light)
                                                viewModel.selectCategory(subject.name, isStudy: true)
                                            }
                                        }
                                        SubjectChip(
                                            name: "기타 공부",
                                            isSelected: viewModel.selectedSubject == "기타 공부",
                                            color: .gray
                                        ) {
                                            triggerHapticFeedback(style: .light)
                                            viewModel.selectCategory("기타 공부", isStudy: true)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // B. 생활/휴식
                            VStack(alignment: .leading, spacing: 8) {
                                Text("☕️ 생활 / 휴식").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                                    .padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(viewModel.lifeCategories, id: \.self) { category in
                                            SubjectChip(
                                                name: category,
                                                isSelected: viewModel.selectedSubject == category,
                                                color: getLifeCategoryColor(category)
                                            ) {
                                                triggerHapticFeedback(style: .light)
                                                viewModel.selectCategory(category, isStudy: false)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // 4. 구체적인 내용
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. 구체적인 내용이 있다면요? (선택)")
                                .font(.headline).foregroundColor(.primary)
                            
                            TextField("예: \(viewModel.isStudySubject ? "1단원 개념 정리" : "점심 메뉴: 돈까스")", text: $viewModel.title)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isTitleFocused ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .focused($isTitleFocused)
                        }
                        .padding(.horizontal)
                        
                        // 5. 시간 설정
                        VStack(alignment: .leading, spacing: 15) {
                            Text("3. 언제, 얼마나 할까요?")
                                .font(.headline).foregroundColor(.primary)
                            
                            // 시간 선택 UI
                            HStack(spacing: 15) {
                                VStack(spacing: 5) {
                                    Text("시작").font(.caption).foregroundColor(.gray)
                                    DatePicker("", selection: $viewModel.startDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .onChange(of: viewModel.startDate) { _ in viewModel.validateTime() }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                
                                Image(systemName: "arrow.right").foregroundColor(.gray.opacity(0.5))
                                
                                VStack(spacing: 5) {
                                    Text("종료").font(.caption).foregroundColor(.gray)
                                    DatePicker("", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            }
                            
                            // 빠른 시간 조절 버튼 (+10분, +30분, -10분)
                            HStack(spacing: 10) {
                                DurationButton(label: "+10분", color: .blue) {
                                    triggerHapticFeedback(style: .medium)
                                    viewModel.addDuration(10)
                                }
                                DurationButton(label: "+30분", color: .blue) {
                                    triggerHapticFeedback(style: .medium)
                                    viewModel.addDuration(30)
                                }
                                DurationButton(label: "-10분", color: .red) {
                                    triggerHapticFeedback(style: .medium)
                                    viewModel.addDuration(-10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 50)
                }
                .background(Color(.systemGray6))
                .onTapGesture { isTitleFocused = false }
            }
            .navigationTitle("일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("등록") {
                        triggerHapticFeedback(style: .heavy) // 저장할 땐 묵직하게
                        viewModel.saveSchedule { dismiss() }
                    }
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                
                // ✨ [이어달리기] 화면 켜지고 0.1초 뒤에 마지막 일정 뒤로 시간 자동 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        viewModel.autoSetStartTimeToLastSchedule()
                    }
                }
                
                if viewModel.selectedSubject == "교육학", let first = settingsManager.favoriteSubjects.first {
                    viewModel.selectCategory(first.name, isStudy: true)
                }
            }
        }
    }
    
    // ✨ 햅틱 피드백 발생 함수
    func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func getLifeCategoryColor(_ name: String) -> Color {
        switch name {
        case "식사": return .orange
        case "운동": return .green
        case "휴식": return .mint
        case "이동": return .gray
        case "약속": return .pink
        default: return .gray
        }
    }

    // 상단 미리보기 섹션
    var previewSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("타임라인 미리보기")
                    .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                Spacer()
                if let conflict = viewModel.overlappingScheduleTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("'\(conflict)' 겹침")
                    }
                    .font(.caption).foregroundColor(.orange)
                    .onAppear { triggerHapticFeedback(style: .heavy) } // 겹침 경고 시 진동
                }
            }
            .padding(.horizontal)
            
            TimelinePreview(
                existingSchedules: viewModel.existingSchedules,
                draftSchedule: viewModel.draftSchedule,
                currentSubjectColor: viewModel.isStudySubject ? SubjectName.color(for: viewModel.selectedSubject) : getLifeCategoryColor(viewModel.selectedSubject)
            )
            .frame(height: 50)
            .padding(.horizontal)
            
            HStack {
                Spacer()
                Text("총 소요 시간")
                    .font(.caption).foregroundColor(.gray)
                Text(viewModel.durationString)
                    .font(.title3).fontWeight(.bold).foregroundColor(.blue)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .padding(.top, 15)
        .padding(.bottom, 10)
        .background(Color.white)
        .shadow(color: .black.opacity(0.03), radius: 5, y: 5)
        .zIndex(1)
    }
}

// MARK: - Subviews

// ✨ [NEW] 루틴 버튼 컴포넌트
struct RoutineButton: View {
    let routine: RoutineItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .overlay(
                        Image(systemName: routine.icon)
                            .foregroundColor(.blue)
                    )
                
                Text(routine.label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct TimelinePreview: View {
    let existingSchedules: [ScheduleItem]
    let draftSchedule: ScheduleItem?
    let currentSubjectColor: Color
    
    private let startHour = 6
    private let endHour = 26
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHours = CGFloat(endHour - startHour)
            let hourWidth = totalWidth / totalHours
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)).frame(height: 25)
                
                HStack(spacing: 0) {
                    ForEach(startHour...endHour, id: \.self) { h in
                        if (h - startHour) % 6 == 0 {
                            Text("\(h >= 24 ? h - 24 : h)")
                                .font(.system(size: 10)).foregroundColor(.gray)
                                .frame(width: hourWidth * 6, alignment: .leading)
                                .offset(y: 20)
                        }
                    }
                }
                
                ForEach(existingSchedules) { item in
                    if !item.isPostponed {
                        let (x, w) = calculateFrame(for: item, totalWidth: totalWidth)
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.4))
                            .frame(width: w, height: 25).offset(x: x)
                    }
                }
                
                if let draft = draftSchedule {
                    let (x, w) = calculateFrame(for: draft, totalWidth: totalWidth)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(currentSubjectColor)
                        RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1)
                    }
                    .frame(width: max(w, 4), height: 25).offset(x: x)
                    .shadow(color: currentSubjectColor.opacity(0.4), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.top, 5)
        }
    }
    
    private func calculateFrame(for item: ScheduleItem, totalWidth: CGFloat) -> (CGFloat, CGFloat) {
        let calendar = Calendar.current
        let startComp = calendar.dateComponents([.hour, .minute], from: item.startDate)
        let h = (startComp.hour ?? 0) < startHour ? (startComp.hour ?? 0) + 24 : (startComp.hour ?? 0)
        
        if h >= endHour || h < startHour { return (-100, 0) }
        
        let m = startComp.minute ?? 0
        let duration = (item.endDate ?? item.startDate.addingTimeInterval(3600)).timeIntervalSince(item.startDate)
        
        let totalMin = CGFloat(endHour - startHour) * 60
        let startMin = CGFloat((h - startHour) * 60 + m)
        let durMin = CGFloat(duration / 60)
        
        return ((startMin / totalMin) * totalWidth, (durMin / totalMin) * totalWidth)
    }
}

struct SubjectChip: View {
    let name: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? color : Color.white)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 3, y: 2)
        }
    }
}

struct DurationButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .cornerRadius(10)
        }
    }
}
