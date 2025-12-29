import Foundation
import FirebaseFirestore

class ScheduleManager {
    static let shared = ScheduleManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // 1. 일정 저장
    func saveSchedule(_ item: ScheduleItem) {
        // ScheduleItem.asDictionary에 이미 studyPurpose가 포함되어 있으므로 그대로 저장됩니다.
        let docRef = db.collection("users").document(item.ownerID).collection("schedules").document(item.id.uuidString)
        docRef.setData(item.asDictionary) { error in
            if let error = error {
                print("❌ 일정 저장 실패: \(error.localizedDescription)")
            } else {
                print("✅ 일정 저장 완료: \(item.title) (\(item.subject))")
            }
        }
    }
    
    // 2. 일정 삭제
    func deleteSchedule(itemId: String, userId: String) {
        db.collection("users").document(userId).collection("schedules").document(itemId).delete() { error in
            if let error = error {
                print("❌ 서버 삭제 실패: \(error)")
            } else {
                print("🗑️ 서버 삭제 완료")
            }
        }
    }
    
    // 3. 일정 불러오기
    func fetchSchedules(userId: String) async throws -> [ScheduleData] {
        let snapshot = try await db.collection("users").document(userId).collection("schedules").getDocuments()
        
        return snapshot.documents.compactMap { doc -> ScheduleData? in
            let data = doc.data()
            
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = data["title"] as? String,
                  let ownerID = data["ownerID"] as? String else { return nil }
            
            // 날짜 처리 (Timestamp & Double 호환)
            let startDate: Date
            if let startTs = data["startDate"] as? Double {
                startDate = Date(timeIntervalSince1970: startTs)
            } else if let startTimestamp = data["startDate"] as? Timestamp {
                startDate = startTimestamp.dateValue()
            } else {
                startDate = Date()
            }
            
            let endDate: Date?
            if let endTs = data["endDate"] as? Double {
                endDate = Date(timeIntervalSince1970: endTs)
            } else if let endTimestamp = data["endDate"] as? Timestamp {
                endDate = endTimestamp.dateValue()
            } else {
                endDate = startDate
            }
            
            // 과목 정보 가져오기 (없으면 기본값 "교육학")
            let subject = data["subject"] as? String ?? "교육학"
            
            // ✨ [추가] 공부 목적 가져오기 (없으면 기본값 "인강시청")
            // 기존에 저장된 데이터에는 이 필드가 없을 수 있으므로 안전하게 기본값을 줍니다.
            let studyPurpose = data["studyPurpose"] as? String ?? "인강시청"
            
            return ScheduleData(
                id: id,
                title: title,
                details: data["details"] as? String ?? "",
                startDate: startDate,
                endDate: endDate,
                subject: subject,
                isCompleted: data["isCompleted"] as? Bool ?? false,
                hasReminder: data["hasReminder"] as? Bool ?? false,
                ownerID: ownerID,
                isPostponed: data["isPostponed"] as? Bool ?? false,
                studyPurpose: studyPurpose // ✨ 구조체 생성 시 값 전달
            )
        }
    }
}

// 데이터 전송용 구조체
struct ScheduleData {
    let id: UUID
    let title: String
    let details: String
    let startDate: Date
    let endDate: Date?
    let subject: String
    let isCompleted: Bool
    let hasReminder: Bool
    let ownerID: String
    let isPostponed: Bool
    // ✨ [추가] 오류 해결의 핵심!
    let studyPurpose: String
}
