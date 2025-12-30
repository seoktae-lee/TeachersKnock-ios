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
                    TextField("예: 2026학년도 초등 임용", text: $viewModel.title)
                }
                
                Section(header: Text("디데이 날짜")) {
                    DatePicker("날짜 선택", selection: $viewModel.targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(GoalColorHelper.color(for: viewModel.selectedColorName))
                }
                
                if dDay >= 200 {
                    Section {
                        Toggle(isOn: $viewModel.useCharacter) {
                            VStack(alignment: .leading) {
                                Text("티노 캐릭터 함께 키우기").font(.headline)
                                Text("목표 기간에 맞춰 캐릭터가 성장합니다.").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .tint(GoalColorHelper.color(for: viewModel.selectedColorName))
                        
                        if viewModel.useCharacter {
                            TextField("캐릭터 별명", text: $viewModel.characterName).padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("스타팅 캐릭터 선택").font(.caption).foregroundColor(.gray)
                                HStack(spacing: 15) {
                                    ForEach(characterOptions, id: \.type) { option in
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(viewModel.selectedCharacterType == option.type ?
                                                          GoalColorHelper.color(for: viewModel.selectedColorName).opacity(0.15) :
                                                          Color.gray.opacity(0.05))
                                                    .frame(width: 65, height: 65)
                                                Text(option.emoji).font(.system(size: 30))
                                            }
                                            .overlay(Circle().stroke(GoalColorHelper.color(for: viewModel.selectedColorName),
                                                                   lineWidth: viewModel.selectedCharacterType == option.type ? 3 : 0))
                                            
                                            Text(option.name).font(.system(size: 11, weight: .bold))
                                                .foregroundColor(viewModel.selectedCharacterType == option.type ? .primary : .gray)
                                        }
                                        .onTapGesture {
                                            withAnimation(.spring()) { viewModel.selectedCharacterType = option.type }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("캐릭터 테마 색상").font(.caption).foregroundColor(.gray)
                                HStack(spacing: 15) {
                                    // ✨ viewModel에서 직접 availableColors를 참조하여 오류 해결
                                    ForEach(viewModel.availableColors, id: \.self) { colorName in
                                        let color = GoalColorHelper.color(for: colorName)
                                        Circle()
                                            .fill(color)
                                            .frame(width: 30, height: 30)
                                            .overlay(Circle().stroke(Color.gray.opacity(0.5),
                                                                   lineWidth: viewModel.selectedColorName == colorName ? 3 : 0).scaleEffect(1.3))
                                            .onTapGesture {
                                                withAnimation(.spring()) { viewModel.selectedColorName = colorName }
                                            }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("새 목표 추가")
            .onChange(of: viewModel.targetDate) { newDate in
                let dDayCount = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: newDate)).day ?? 0
                withAnimation {
                    if dDayCount >= 200 {
                        viewModel.useCharacter = true
                    } else {
                        viewModel.useCharacter = false
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { saveGoal() }
                        .foregroundColor(GoalColorHelper.color(for: viewModel.selectedColorName))
                        .disabled(viewModel.title.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let user = Auth.auth().currentUser else { return }
        // goals.count를 넘겨주어 첫 목표 자동 대표 설정
        viewModel.addGoal(ownerID: user.uid, context: modelContext, goalsCount: goals.count)
        dismiss()
    }
}
