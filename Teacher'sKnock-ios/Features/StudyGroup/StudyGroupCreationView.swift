import SwiftUI
import FirebaseAuth

struct StudyGroupCreationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var studyManager: StudyGroupManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("스터디 정보")) {
                    TextField("스터디 이름 (예: 임용 합격 반)", text: $name)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("스터디 소개 및 규칙을 입력해주세요.\n(예: 매일 아침 9시 기상 인증)")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                    }
                }
                
                Section(footer: Text("최대 6명까지 참여할 수 있습니다.")) {
                    HStack {
                        Text("최대 인원")
                        Spacer()
                        Text("6명") // 고정
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("새 스터디 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("생성") {
                        createStudyGroup()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }
    
    func createStudyGroup() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isCreating = true
        
        studyManager.createGroup(name: name, description: description, leaderID: uid) { success in
            isCreating = false
            if success {
                dismiss()
            } else {
                // 에러 처리 필요 시 추가
            }
        }
    }
}
