import SwiftUI
import SwiftData
import FirebaseAuth

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ✨ ObservedObject 래퍼 문제를 방지하기 위해 StateObject 사용
    @StateObject private var viewModel = GoalViewModel()
    @Query private var goals: [Goal]
    
    private let characterOptions = [
        (type: "bird", name: "열정의 티노", emoji: "🥚"),
        (type: "plant", name: "성실의 새싹", emoji: "🤎"),
        (type: "sea", name: "지혜의 바다", emoji: "🧊")
    ]
    
    private var dDay: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: viewModel.targetDate)).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("목표 이름")) {
                    TextField("예: 2027학년도 초등 임용 합격", text: $viewModel.title)
                }
                
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $viewModel.targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(GoalColorHelper.color(for: viewModel.selectedColorName))
                }
                
                // ✨ [수정] 첫 캐릭터 선택 UI (보유한 캐릭터가 없을 때만 표시)
                if CharacterManager.shared.characters.isEmpty {
                    Section {
                        Button(action: { showCharacterSelection = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("운명의 파트너 선택하기")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("당신과 함께할 첫 번째 친구를 만나보세요")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                // 선택된 캐릭터 미리보기
                                if !viewModel.selectedCharacterType.isEmpty {
                                    let emoji = characterOptions.first(where: { $0.type == viewModel.selectedCharacterType })?.emoji ?? "🥚"
                                    Text(emoji)
                                        .font(.system(size: 30))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // 선택 완료 후 이름 입력 확인 (선택 뷰에서 이름을 가져오므로 여기선 표시만)
                    if !viewModel.characterName.isEmpty {
                        Section(header: Text("선택된 파트너")) {
                            HStack {
                                Text("이름")
                                Spacer()
                                Text(viewModel.characterName)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                if dDay >= 200 {
                    // 메세지만 표시하고 캐릭터 설정 UI 제거 (캐릭터는 이제 전역 관리)
                    Section {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("장기 목표를 달성하고 캐릭터를 성장시켜 보세요!")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("새 목표 추가")
            // .onChange 관련 로직 제거
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { saveGoal() }
                        .foregroundColor(GoalColorHelper.color(for: viewModel.selectedColorName))
                        .disabled(viewModel.title.isEmpty || (CharacterManager.shared.characters.isEmpty && viewModel.characterName.isEmpty)) // 캐릭터 선택 필수
                }
            }
            .sheet(isPresented: $showCharacterSelection) {
                StartingCharacterSelectionView { type, name in
                    viewModel.selectedCharacterType = type
                    viewModel.characterName = name
                }
            }
        }
    }
    
    // ✨ [추가] 시트 제어 변수
    @State private var showCharacterSelection = false
    
    private func saveGoal() {
        guard let user = Auth.auth().currentUser else { return }
        
        // ✨ [추가] 캐릭터가 하나도 없다면 선택한 캐릭터 스타팅으로 지급
        if CharacterManager.shared.characters.isEmpty {
            CharacterManager.shared.unlockStartingCharacter(
                type: viewModel.selectedCharacterType,
                name: viewModel.characterName
            )
        }
        
        // goals.count를 넘겨주어 첫 목표 자동 대표 설정
        viewModel.addGoal(ownerID: user.uid, context: modelContext, goalsCount: goals.count)
        dismiss()
    }
}
