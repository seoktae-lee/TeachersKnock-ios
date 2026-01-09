import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct CommonTimerSetupView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var studyManager: StudyGroupManager
    let group: StudyGroup
    
    @Binding var showCommonTimer: Bool // 설정 완료 후 타이머 화면으로 바로 이동하기 위함
    
    // ✨ [New] Auto-fill Params
    var initialSubject: String?
    var initialPurpose: StudyPurpose?
    
    // ✨ [New] Member Selection
    @State private var selectedMemberIDs: Set<String> = []
    
    // Form States
    @State private var goalTitle: String = ""
    @State private var selectedSubject: String = ""
    @State private var selectedPurpose: StudyPurpose = .study // ✨ [Fixed] .selfStudy -> .study
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600) // 기본 1시간
    
    // Pickers State
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    
    // Feedback
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    var durationString: String {
        let diff = endTime.timeIntervalSince(startTime)
        let m = Int(diff) / 60
        let h = m / 60
        let min = m % 60
        
        if h > 0 {
            return "\(h)시간" + (min > 0 ? " \(min)분" : "")
        } else {
            return "\(min)분"
        }
    }
    
    // Environment Objects needed for Subjects
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 설정")) {
                    TextField("예: 티처스 노크 모의고사 1회차", text: $goalTitle)
                }
                
                Section(header: Text("공부 설정")) {
                    HStack(spacing: 12) {
                        // 1. 공부 과목
                        VStack(alignment: .leading, spacing: 4) {
                            Text("공부 과목").font(.caption2).foregroundColor(.gray).padding(.leading, 4)
                            
                            Menu {
                                ForEach(settingsManager.favoriteSubjects) { subject in
                                    Button(action: {
                                        selectedSubject = subject.name
                                    }) {
                                        HStack {
                                            Text(subject.name)
                                            if selectedSubject == subject.name {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedSubject.isEmpty ? "선택" : selectedSubject)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .foregroundColor(selectedSubject.isEmpty ? .gray : SubjectName.color(for: selectedSubject))
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 3)
                            }
                        }
                        
                        // 2. 공부 목적
                        VStack(alignment: .leading, spacing: 4) {
                            Text("공부 목적").font(.caption2).foregroundColor(.gray).padding(.leading, 4)
                            Menu {
                                ForEach(StudyPurpose.orderedCases, id: \.self) { purpose in
                                    Button(action: {
                                        selectedPurpose = purpose
                                    }) {
                                        HStack {
                                            Text(purpose.localizedName)
                                            if selectedPurpose == purpose {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedPurpose.localizedName)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity)
                                .background(Color.white).cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 3)
                            }
                        }
                    }
                    .padding(.vertical, 5) // 내부 여백
                    .listRowBackground(Color.clear) // 리스트 셀 배경 제거
                    .listRowInsets(EdgeInsets()) // 리스트 셀 패딩 제거 (커스텀 뷰 자체 패딩 사용)
                }
                
                Section(header: Text("참여 멤버 선택")) {
                    if let members = studyManager.groupMembersData[group.id] {
                        ForEach(members) { member in
                            HStack {
                                Text(member.nickname)
                                Spacer()
                                if selectedMemberIDs.contains(member.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedMemberIDs.contains(member.id) {
                                    selectedMemberIDs.remove(member.id)
                                } else {
                                    selectedMemberIDs.insert(member.id)
                                }
                            }
                        }
                    } else {
                        Text("멤버 정보를 불러오는 중...")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("시간 설정")) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text(formatDate(startTime))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            // 총 시간 표시
                            Text("총 \(durationString)")
                                .font(.caption).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        
                        // ✨ [수정] 커스텀 피커 버튼 영역 (Planner Style)
                        HStack(spacing: 0) {
                            timeButton(title: "시작", date: startTime) {
                                showingStartPicker = true
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                                .frame(width: 40)
                                .padding(.top, 20)
                            
                            timeButton(title: "종료", date: endTime) {
                                showingEndPicker = true
                            }
                        }
                        
                        // 시간 조절 버튼들
                        HStack(spacing: 8) {
                            Button("+10분") { addDuration(10) }.frame(maxWidth: .infinity)
                            Button("+30분") { addDuration(30) }.frame(maxWidth: .infinity)
                            Button("+1시간") { addDuration(60) }.frame(maxWidth: .infinity)
                            Button("-10분") { addDuration(-10) }.frame(maxWidth: .infinity).tint(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 5)
                }
                .sheet(isPresented: $showingStartPicker) {
                    SingleDayTimePicker(selection: Binding(
                        get: { startTime },
                        set: { newDate in
                            let duration = endTime.timeIntervalSince(startTime)
                            startTime = newDate
                            endTime = newDate.addingTimeInterval(duration)
                        }
                    ), title: "시작 시간 설정")
                        .presentationDetents([.height(300)])
                }
                .sheet(isPresented: $showingEndPicker) {
                    SingleDayTimePicker(selection: endTimeBinding, title: "종료 시간 설정")
                        .presentationDetents([.height(300)])
                }

                
                Section {
                    Button(action: startTimer) {
                        HStack {
                            Spacer()
                            Text("타이머 설정 및 시작")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(goalTitle.isEmpty || selectedSubject.isEmpty || selectedMemberIDs.isEmpty)
                } footer: {
                    Text("선택된 멤버들이 모두 입장하고, 설정한 시간이 되면 자동으로 타이머가 시작됩니다.")
                }
            }
            .navigationTitle("공유 타이머 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                // 1. 초기값 주입 (플래너 연동 등)
                if let subject = initialSubject, !subject.isEmpty {
                    selectedSubject = subject
                } else if selectedSubject.isEmpty {
                    selectedSubject = settingsManager.favoriteSubjects.first?.name ?? ""
                }
                
                if let purpose = initialPurpose {
                    selectedPurpose = purpose
                }
                
                // 멤버 데이터 요청
                studyManager.fetchGroupMembers(groupID: group.id, memberUIDs: group.members)
            }
        }
    }
    
    // ✨ [New] Smart Binding for End Time to handle "Next Day" logic
    var endTimeBinding: Binding<Date> {
        Binding(
            get: { endTime },
            set: { newDate in
                let calendar = Calendar.current
                let h = calendar.component(.hour, from: newDate)
                let m = calendar.component(.minute, from: newDate)
                
                // 1. startTime과 같은 날짜의 시간으로 설정
                if let sameDayDate = calendar.date(bySettingHour: h, minute: m, second: 0, of: startTime) {
                    // 2. 만약 설정한 시간이 시작 시간보다 이전이라면, '다음 날'로 간주 (밤샘 공부 등)
                    // 단, 12시간 이상 차이나는 엄청난 과거라면 다음날로,
                    // 그렇지 않고 미세하게 앞이라면(예: 00:30 시작인데 00:35 종료 -> 5분) 정상.
                    
                    if sameDayDate < startTime {
                        // 예: 23:00 시작 -> 01:00 종료 설정 시 (sameDayDate는 오늘 01:00 < 23:00)
                        // -> 내일 01:00로 설정
                         endTime = calendar.date(byAdding: .day, value: 1, to: sameDayDate) ?? sameDayDate
                    } else {
                        // 예: 00:30 시작 -> 00:35 종료 설정 시 (sameDayDate는 오늘 00:35 > 00:30)
                        endTime = sameDayDate
                    }
                }
            }
        )
    }
    
    func startTimer() {
        // StudyManager를 통해 Firestore 업데이트
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // ✨ [Fix] 닉네임 가져오기 우선순위 변경 (Group Member Data -> UserDefaults -> Auth -> Unknown)
        var nickname = "알 수 없음"
        if let members = studyManager.groupMembersData[group.id],
           let currentUser = members.first(where: { $0.id == uid }) {
            nickname = currentUser.nickname
        } else {
            nickname = UserDefaults.standard.string(forKey: "userNickname") ?? Auth.auth().currentUser?.displayName ?? "알 수 없음"
        }
        
        let state = StudyGroup.CommonTimerState(
            goal: goalTitle,
            startTime: startTime,
            endTime: endTime, // ✨ [Updated] 직접 설정한 종료 시간 사용
            subject: selectedSubject,
            purpose: selectedPurpose.rawValue, // String rawValue used
            isActive: true,
            activeParticipants: [], // 초기엔 아무도 없음
            targetMembers: Array(selectedMemberIDs), // ✨ [New] 선택된 멤버들
            creatorID: uid,
            creatorName: nickname
        )
        
        studyManager.updateCommonTimer(groupID: group.id, state: state) { success in
            if success {
                dismiss()
                showCommonTimer = true // 타이머 화면 진입 trigger
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E)"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    func addDuration(_ minutes: Int) {
        feedback.impactOccurred()
        let newEnd = endTime.addingTimeInterval(TimeInterval(minutes * 60))
        if newEnd > startTime {
            endTime = newEnd
        }
    }
    
    // ✨ [New] Duration Preset Button Helper -> Time Button Helper
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
        .buttonStyle(.plain)
    }
}



