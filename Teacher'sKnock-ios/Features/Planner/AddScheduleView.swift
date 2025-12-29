import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 뷰모델 연결
    @StateObject private var viewModel: AddScheduleViewModel
    
    init(selectedDate: Date) {
        let uid = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: AddScheduleViewModel(userId: uid, selectedDate: selectedDate))
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
                    
                    // MARK: - 2. 제목 입력
                    TitleSection(viewModel: viewModel)
                    
                    // MARK: - 3. 시간 설정
                    TimeSection(viewModel: viewModel)
                    
                    Spacer(minLength: 80)
                }
                .padding(.vertical)
            }
            .background(Color.white)
            .navigationTitle("새 일정")
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
                viewModel.autoSetStartTimeToLastSchedule()
                
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
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "3.circle.fill").foregroundColor(.blue)
                Text("시간을 설정해주세요").font(.headline)
                
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
            
            HStack(spacing: 0) {
                DatePicker("시작", selection: $viewModel.startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                Image(systemName: "arrow.right").foregroundColor(.gray).frame(width: 40)
                DatePicker("종료", selection: $viewModel.endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
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
        }
    }
}
