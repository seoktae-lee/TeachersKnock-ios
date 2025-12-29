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
    
    let availableColors: [String] = ["Blue", "Pink", "Purple", "Green", "Orange", "Mint"]
    
    func addGoal(ownerID: String, context: ModelContext) {
        if title.isEmpty { return }
        
        let finalName = characterName.isEmpty ? "티노" : characterName
        
        let newGoal = Goal(
            title: title,
            targetDate: targetDate,
            ownerID: ownerID,
            hasCharacter: useCharacter,
            characterName: finalName,
            characterColor: selectedColorName
        )
        
        // 1. 로컬 저장 (폰)
        context.insert(newGoal)
        
        // ✨ 2. 서버 저장 (Firebase) - 이제 앱 지워도 안 사라짐!
        GoalManager.shared.saveGoal(newGoal)
        
        print("GoalVM: 목표 저장 완료 (로컬+서버)")
    }
}
