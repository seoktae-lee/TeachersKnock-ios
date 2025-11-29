import SwiftUI
import SwiftData
import FirebaseAuth // ✨ 인증 정보 사용을 위해 추가

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var targetDate = Date()
    
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
            }
            .navigationTitle("새 목표 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        addGoal()
                    }
                    .foregroundColor(brandColor)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    // ✨ 목표 저장 함수 (수정됨)
    private func addGoal() {
        // 1. 현재 로그인한 사용자 정보 가져오기
        guard let user = Auth.auth().currentUser else {
            print("오류: 로그인된 사용자가 없습니다.")
            return
        }
        
        // 2. 사용자 ID(uid)를 포함하여 Goal 생성
        let newGoal = Goal(title: title, targetDate: targetDate, ownerID: user.uid)
        
        // 3. 저장
        modelContext.insert(newGoal)
        dismiss()
    }
}

#Preview {
    AddGoalView()
}
