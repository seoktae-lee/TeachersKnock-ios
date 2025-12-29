import Foundation
import FirebaseFirestore

class GoalManager {
    static let shared = GoalManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // 1. 목표 서버 저장
    func saveGoal(_ goal: Goal) {
        let docRef = db.collection("users").document(goal.ownerID).collection("goals").document(goal.id.uuidString)
        docRef.setData(goal.asDictionary) { error in
            if let error = error {
                print("❌ 목표 서버 저장 실패: \(error.localizedDescription)")
            } else {
                print("✅ 목표 서버 저장 완료: \(goal.title)")
            }
        }
    }
    
    // 2. 목표 서버 삭제
    func deleteGoal(goalId: String, userId: String) {
        db.collection("users").document(userId).collection("goals").document(goalId).delete()
    }
    
    // 3. 목표 불러오기 (앱 재설치 시)
    func fetchGoals(userId: String) async throws -> [GoalData] {
        let snapshot = try await db.collection("users").document(userId).collection("goals").getDocuments()
        return snapshot.documents.compactMap { doc -> GoalData? in
            let data = doc.data()
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = data["title"] as? String,
                  let targetTs = data["targetDate"] as? Double,
                  let startTs = data["startDate"] as? Double,
                  let ownerID = data["ownerID"] as? String else { return nil }
            
            return GoalData(
                id: id,
                title: title,
                targetDate: Date(timeIntervalSince1970: targetTs),
                startDate: Date(timeIntervalSince1970: startTs),
                ownerID: ownerID,
                hasCharacter: data["hasCharacter"] as? Bool ?? false,
                characterName: data["characterName"] as? String ?? "티노",
                characterColor: data["characterColor"] as? String ?? "Blue",
                isPrimaryGoal: data["isPrimaryGoal"] as? Bool ?? false
            )
        }
    }
}

// 데이터를 잠시 담아둘 구조체
struct GoalData {
    let id: UUID
    let title: String
    let targetDate: Date
    let startDate: Date
    let ownerID: String
    let hasCharacter: Bool
    let characterName: String
    let characterColor: String
    let isPrimaryGoal: Bool
}
