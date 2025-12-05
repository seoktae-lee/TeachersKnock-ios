import SwiftUI

struct SubjectManagementView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var newSubjectName: String = ""
    @State private var isAdding: Bool = false
    
    var body: some View {
        List {
            Section(header: Text("등록된 과목")) {
                // ✨ id: \.self 추가로 에러 방지
                ForEach(settingsManager.favoriteSubjects, id: \.self) { subject in
                    HStack {
                        Circle()
                            .fill(SubjectName.color(for: subject.name)) // 색상은 이름 기반 자동 생성
                            .frame(width: 10, height: 10)
                        
                        Text(subject.name)
                            .font(.body)
                    }
                }
                .onDelete(perform: deleteSubject)
            }
            
            Section {
                if isAdding {
                    HStack {
                        TextField("새 과목 이름 (예: 영어)", text: $newSubjectName)
                            .onSubmit { addNewSubject() }
                        
                        Button("저장") { addNewSubject() }
                            .disabled(newSubjectName.isEmpty)
                    }
                } else {
                    Button(action: { isAdding = true }) {
                        Label("과목 추가하기", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("과목 관리")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addNewSubject() {
        guard !newSubjectName.isEmpty else { return }
        settingsManager.addSubject(newSubjectName)
        newSubjectName = ""
        isAdding = false
    }
    
    private func deleteSubject(at offsets: IndexSet) {
        settingsManager.removeSubject(at: offsets)
    }
}
