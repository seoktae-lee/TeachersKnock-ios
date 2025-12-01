import SwiftUI
import SwiftData
import FirebaseAuth

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var targetDate = Date()
    // ✨ 캐릭터 육성 선택 변수
    @State private var useCharacter = true
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 이름")) {
                    TextField("예: 2026학년도 초등 임용", text: $title)
                }
                
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(brandColor)
                }
                
                // ✨ 캐릭터 육성 옵션 섹션
                Section {
                    Toggle(isOn: $useCharacter) {
                        VStack(alignment: .leading) {
                            Text("티노 캐릭터 함께 키우기")
                                .font(.headline)
                            Text("목표 기간에 맞춰 캐릭터가 성장합니다.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(brandColor)
                }
            }
            .navigationTitle("새 목표 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { addGoal() }
                        .foregroundColor(brandColor)
                        .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addGoal() {
        guard let user = Auth.auth().currentUser else { return }
        
        let newGoal = Goal(
            title: title,
            targetDate: targetDate,
            ownerID: user.uid,
            hasCharacter: useCharacter // 선택값 저장
        )
        
        modelContext.insert(newGoal)
        dismiss()
    }
}

#Preview {
    AddGoalView()
}
