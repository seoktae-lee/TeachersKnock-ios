import SwiftUI
import FirebaseAuth

struct SubjectSelectView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    // ✨ [수정 1] Enum의 'allCases' 대신, Struct에 정의한 'defaultList'를 사용
    let allSubjects = SubjectName.defaultList
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        List {
            Section(header: Text("공부할 과목을 선택해주세요."),
                    footer: Text("선택된 과목은 홈 화면과 타이머, 통계에 표시됩니다.")) {
                
                // ✨ [수정 2] 문자열 배열이므로 id: \.self를 추가해야 함
                ForEach(allSubjects, id: \.self) { subjectName in
                    
                    // ✨ [수정 3] 문자열(subjectName)을 바로 사용하여 객체 생성
                    let targetSubject = StudySubject(name: subjectName)
                    let isSelected = settingsManager.favoriteSubjects.contains(where: { $0.name == targetSubject.name })
                    
                    HStack {
                        Text(subjectName) // localizedName 필요 없이 바로 문자열 출력
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
                        toggleSubject(targetSubject)
                    }
                }
            }
        }
        .navigationTitle("과목 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func toggleSubject(_ subject: StudySubject) {
        guard let uid = currentUserId else { return }
        
        var newFavorites = settingsManager.favoriteSubjects
        
        // 이미 있는지 이름으로 확인
        if let index = newFavorites.firstIndex(where: { $0.name == subject.name }) {
            // 있으면 제거
            newFavorites.remove(at: index)
        } else {
            // 없으면 추가
            newFavorites.append(subject)
        }
        
        // 변경된 리스트 저장
        settingsManager.saveFavoriteSubjects(uid: uid, newFavorites)
    }
}

#Preview {
    SubjectSelectView()
        .environmentObject(SettingsManager())
}
