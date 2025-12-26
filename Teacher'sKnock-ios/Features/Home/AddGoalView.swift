import SwiftUI
import SwiftData
import FirebaseAuth

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = GoalViewModel()
    
    // 기본 브랜드 컬러 (UI 장식용)
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 이름")) {
                    TextField("예: 2026학년도 초등 임용", text: $viewModel.title)
                }
                
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $viewModel.targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(GoalColorHelper.color(for: viewModel.selectedColorName)) // 선택한 색으로 달력 강조
                }
                
                // 캐릭터 육성 옵션 섹션
                Section {
                    Toggle(isOn: $viewModel.useCharacter) {
                        VStack(alignment: .leading) {
                            Text("티노 캐릭터 함께 키우기")
                                .font(.headline)
                            Text("목표 기간에 맞춰 캐릭터가 성장합니다.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(GoalColorHelper.color(for: viewModel.selectedColorName))
                    
                    // ✨ [NEW] 캐릭터 커스텀 (토글 켜졌을 때만)
                    if viewModel.useCharacter {
                        // 1. 별명 입력
                        TextField("캐릭터 별명 (예: 합격이, 꿈돌이)", text: $viewModel.characterName)
                            .padding(.vertical, 4)
                        
                        // 2. 색상 선택 팔레트
                        VStack(alignment: .leading, spacing: 10) {
                            Text("캐릭터 테마 색상")
                                .font(.caption).foregroundColor(.gray)
                            
                            HStack(spacing: 15) {
                                ForEach(viewModel.availableColors, id: \.self) { colorName in
                                    let color = GoalColorHelper.color(for: colorName)
                                    let isSelected = viewModel.selectedColorName == colorName
                                    
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.5), lineWidth: isSelected ? 3 : 0)
                                                .scaleEffect(1.3) // 선택 시 바깥 테두리 효과
                                        )
                                        .shadow(color: color.opacity(0.5), radius: 2, y: 1)
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                viewModel.selectedColorName = colorName
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
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
                        saveGoal()
                    }
                    .foregroundColor(GoalColorHelper.color(for: viewModel.selectedColorName))
                    .disabled(viewModel.title.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let user = Auth.auth().currentUser else { return }
        viewModel.addGoal(ownerID: user.uid, context: modelContext)
        dismiss()
    }
}

// ✨ [Helper] 색상 이름(String) -> SwiftUI Color 변환기
struct GoalColorHelper {
    static func color(for name: String) -> Color {
        switch name {
        case "Blue": return Color(red: 0.35, green: 0.65, blue: 0.95) // 브랜드 컬러
        case "Pink": return Color.pink
        case "Purple": return Color.purple
        case "Green": return Color.green
        case "Orange": return Color.orange
        case "Mint": return Color.mint
        default: return Color.blue
        }
    }
}
