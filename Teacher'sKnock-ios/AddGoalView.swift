import SwiftUI
import SwiftData

struct AddGoalView: View {
    // 1. 데이터 저장을 위한 환경 변수 (SwiftData)
    @Environment(\.modelContext) private var modelContext
    
    // 2. 화면을 닫기 위한 환경 변수
    @Environment(\.dismiss) private var dismiss
    
    // 3. 사용자 입력 상태 변수
    @State private var title = ""
    @State private var targetDate = Date()
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                // 목표 이름 입력 섹션
                Section(header: Text("목표 이름")) {
                    TextField("예: 2026학년도 초등 임용", text: $title)
                }
                
                // 날짜 선택 섹션
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical) // 달력 형태로 예쁘게 표시
                        .accentColor(brandColor)
                }
            }
            .navigationTitle("새 목표 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 취소 버튼
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                // 저장 버튼
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        addGoal()
                    }
                    .foregroundColor(brandColor)
                    // 제목을 입력하지 않으면 저장 버튼 비활성화
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    // ✨ 목표 저장 함수
    private func addGoal() {
        // 1. 새로운 Goal 객체 생성
        let newGoal = Goal(title: title, targetDate: targetDate)
        
        // 2. SwiftData 컨테이너에 추가 (자동 저장됨)
        modelContext.insert(newGoal)
        
        // 3. 화면 닫기
        dismiss()
    }
}

#Preview {
    AddGoalView()
}
