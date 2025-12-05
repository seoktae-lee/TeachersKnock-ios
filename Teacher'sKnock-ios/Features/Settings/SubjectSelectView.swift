import SwiftUI
import FirebaseAuth

struct SubjectSelectView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 기본 제공되는 모든 과목 (자율선택 제외)
    let allSubjects = SubjectName.allCases.filter { $0 != .selfStudy }
    
    // 현재 로그인한 내 ID
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        List {
            Section(header: Text("자주 공부하는 과목을 최대 8개 선택해주세요."),
                    footer: Text("\(settingsManager.favoriteSubjects.count) / 8 선택됨")) {
                
                ForEach(allSubjects) { subjectName in
                    // ✨ [핵심] Enum -> Struct 변환 (비교를 위해)
                    let studySubject = StudySubject(name: subjectName.localizedName)
                    let isSelected = settingsManager.favoriteSubjects.contains(where: { $0.name == studySubject.name })
                    
                    HStack {
                        Text(subjectName.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // 선택 여부에 따라 체크 표시
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.3))
                                .font(.title3)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSubject(studySubject)
                    }
                }
            }
        }
        .navigationTitle("선호 과목 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // ✨ [수정됨] StudySubject를 인자로 받음
    func toggleSubject(_ subject: StudySubject) {
        guard let uid = currentUserId else { return }
        
        var newFavorites = settingsManager.favoriteSubjects
        
        // 이미 있는지 확인 (이름으로 비교)
        if let index = newFavorites.firstIndex(where: { $0.name == subject.name }) {
            // 있으면 제거
            newFavorites.remove(at: index)
        } else {
            // 없으면 추가 (8개 제한)
            if newFavorites.count < 8 {
                newFavorites.append(subject)
            }
        }
        
        // 변경된 리스트 저장
        settingsManager.saveFavoriteSubjects(uid: uid, newFavorites)
    }
}

#Preview {
    SubjectSelectView()
        .environmentObject(SettingsManager())
}
