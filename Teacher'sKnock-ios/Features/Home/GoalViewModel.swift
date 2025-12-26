import Foundation
import SwiftData
import SwiftUI
import Combine

class GoalViewModel: ObservableObject {
    
    // 뷰에서 입력받을 데이터들
    @Published var title: String = ""
    @Published var targetDate: Date = Date()
    @Published var useCharacter: Bool = true
    
    // ✨ [NEW] 별명 & 색상 선택
    @Published var characterName: String = ""
    @Published var selectedColorName: String = "Blue" // 기본값 파랑
    
    // 제공할 색상 팔레트 (저장용 이름)
    let availableColors: [String] = ["Blue", "Pink", "Purple", "Green", "Orange", "Mint"]
    
    // 목표 저장 로직
    func addGoal(ownerID: String, context: ModelContext) {
        if title.isEmpty { return }
        
        // 별명 없으면 기본값
        let finalName = characterName.isEmpty ? "티노" : characterName
        
        // 모델 생성
        let newGoal = Goal(
            title: title,
            targetDate: targetDate,
            ownerID: ownerID,
            hasCharacter: useCharacter,
            characterName: finalName,      // ✨ 저장
            characterColor: selectedColorName // ✨ 저장
        )
        
        context.insert(newGoal)
        // FirestoreSyncManager.shared.saveGoal(newGoal)
        
        print("GoalVM: 목표 저장 완료 - \(title) (\(finalName), \(selectedColorName))")
    }
}
