import Foundation
import SwiftData
import SwiftUI
import Combine

class GoalViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var targetDate: Date = Date()
    @Published var useCharacter: Bool = true
    @Published var characterName: String = ""
    @Published var selectedColorName: String = "Blue"
    @Published var selectedCharacterType: String = "bird"
    
    // ✨ [추가] View에서 참조할 수 있도록 컬러 리스트 정의
    let availableColors = ["Blue", "Pink", "Purple", "Green", "Orange", "Mint"]
    
    func addGoal(ownerID: String, context: ModelContext, goalsCount: Int) {
        // 첫 번째 목표라면 자동으로 대표 목표로 설정
        let isFirstGoal = (goalsCount == 0)
        
        let newGoal = Goal(
            title: self.title,
            targetDate: self.targetDate,
            ownerID: ownerID,
            hasCharacter: self.useCharacter,
            startDate: Date(), // 생성 시점 저장하여 LV.1부터 계산 보장
            characterName: self.characterName,
            characterColor: self.selectedColorName,
            isPrimaryGoal: isFirstGoal,
            characterType: self.selectedCharacterType
        )
        
        context.insert(newGoal)
        resetForm()
    }
    
    private func resetForm() {
        title = ""
        targetDate = Date()
        useCharacter = true
        characterName = ""
        selectedColorName = "Blue"
        selectedCharacterType = "bird"
    }
}
