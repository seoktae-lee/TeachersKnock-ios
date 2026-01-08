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
    
    // Form States
    @State private var goalTitle: String = ""
    @State private var selectedSubject: String = ""
    @State private var selectedPurpose: StudyPurpose = .study // ✨ [Fixed] .selfStudy -> .study
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600) // Default 1 hour
    
    // Environment Objects needed for Subjects
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 설정")) {
                    TextField("예: 티처스 노크 모의고사 1회차", text: $goalTitle)
                }
                
                Section(header: Text("공부 설정")) {
                    Picker("과목", selection: $selectedSubject) {
                        if settingsManager.favoriteSubjects.isEmpty {
                            Text("등록된 과목 없음").tag("")
                        } else {
                            ForEach(settingsManager.favoriteSubjects) { subject in
                                Text(subject.name).tag(subject.name)
                            }
                        }
                    }
                    
                    Picker("목적", selection: $selectedPurpose) {
                        ForEach(StudyPurpose.allCases, id: \.self) { purpose in
                            Text(purpose.localizedName).tag(purpose as StudyPurpose) // ✨ [Fixed] Explicit tag type
                        }
                    }
                }
                
                Section(header: Text("시간 설정")) {
                    DatePicker("시작 시간", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("종료 시간", selection: $endTime, in: startTime..., displayedComponents: [.hourAndMinute])
                    
                    HStack {
                        Spacer()
                        Text("총 \(formatDuration(endTime.timeIntervalSince(startTime)))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
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
                    .disabled(goalTitle.isEmpty || selectedSubject.isEmpty)
                } footer: {
                    Text("공유 타이머를 시작하면 모든 스터디원들에게 알림이 가며, 설정한 시간에 맞춰 공유 타이머가 작동합니다.")
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
                
                // 기본 시작 시간을 현재 시간의 다음 정각이나 30분 단위로 맞추면 좋을듯 하지만, 일단 현재 시간
            }
        }
    }
    
    func startTimer() {
        // StudyManager를 통해 Firestore 업데이트
        // 실제 구현은 StudyGroupManager 확장이 필요함
        // 여기서는 임시로 프린트 및 닫기
        
        let state = StudyGroup.CommonTimerState(
            goal: goalTitle,
            startTime: startTime,
            endTime: endTime,
            subject: selectedSubject,
            purpose: selectedPurpose.rawValue, // String rawValue used
            isActive: true
        )
        
        studyManager.updateCommonTimer(groupID: group.id, state: state) { success in
            if success {
                dismiss()
                showCommonTimer = true // 타이머 화면 진입 trigger
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration / 60)
        let h = m / 60
        let min = m % 60
        if h > 0 {
            return "\(h)시간 \(min)분"
        } else {
            return "\(min)분"
        }
    }
}
