import SwiftUI
import SwiftData
import FirebaseAuth

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ✨ 캐릭터 매니저 상태 감지
    @ObservedObject private var characterManager = CharacterManager.shared
    
    // ✨ ObservedObject 래퍼 문제를 방지하기 위해 StateObject 사용
    @StateObject private var viewModel = GoalViewModel()
    @Query private var goals: [Goal]
    
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
                
        // ✨ [수정] 캐릭터 관련 UI 표시 로직 개선
        // 캐릭터가 없거나, 이미 캐릭터가 있는 경우 모두 표시 (조건문 제거)
        Section {
            // 캐릭터가 없는 경우에만 선택 버튼 활성화
            if characterManager.characters.isEmpty {
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
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // 이미 캐릭터가 존재하는 경우 (선택 완료됨) -> 잠금 표시 (선택된 캐릭터 보여주기)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("운명의 파트너 선택 완료")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("함께할 친구가 정해졌습니다")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // 선택된 캐릭터 미리보기
                    if let startChar = characterManager.characters.first, // 스타팅 캐릭터
                       let imageName = CharacterLevel.lv1.imageName(for: startChar.type) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                    } else {
                        let emoji = characterManager.characters.first?.emoji ?? "✨"
                        Text(emoji)
                            .font(.system(size: 30))
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
                    // ✨ 선택 즉시 캐릭터 해금 (저장)
                    CharacterManager.shared.unlockStartingCharacter(type: type, name: name)
                    
                    viewModel.selectedCharacterType = type
                    viewModel.characterName = name
                }
            }
            .onAppear {
                // 캐릭터가 없는 경우, 초기 선택값을 비워서 강제 선택 유도
                if CharacterManager.shared.characters.isEmpty {
                    viewModel.selectedCharacterType = ""
                } else if let existingChar = CharacterManager.shared.characters.first {
                    // 이미 캐릭터가 있는 경우 (나갔다 들어온 경우 등), 해당 정보 로드
                    viewModel.selectedCharacterType = existingChar.type
                    viewModel.characterName = existingChar.name
                }
            }
        }
    }
    
    // ✨ [추가] 시트 제어 변수
    @State private var showCharacterSelection = false
    
    private func saveGoal() {
        guard let user = Auth.auth().currentUser else { return }
        
        // 캐릭터는 이미 선택 시점에 저장되었으므로 별도 저장 로직 불필요
        // 혹시 모를 예외 처리 (UI 등에서 직접 호출 시)
        if CharacterManager.shared.characters.isEmpty && !viewModel.selectedCharacterType.isEmpty {
             CharacterManager.shared.unlockStartingCharacter(
                type: viewModel.selectedCharacterType,
                name: viewModel.characterName
            )
        }
        
        // 삭제되지 않은 활성 목표 개수 계산
        let activeGoalsCount = goals.filter { !$0.isDeleted }.count
        
        // goals.count 대신 activeGoalsCount를 넘겨주어 첫 목표 자동 대표 설정
        viewModel.addGoal(ownerID: user.uid, context: modelContext, goalsCount: activeGoalsCount)
        dismiss()
    }
}
