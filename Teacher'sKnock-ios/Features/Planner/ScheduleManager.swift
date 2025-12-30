import Foundation
import FirebaseFirestore
import UserNotifications
import UIKit

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
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // 1. 권한 요청
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("알림 권한 허용됨")
            } else if let error = error {
                print("알림 권한 요청 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. 알림 스케줄링 (정시 & 10분 전)
    func updateNotifications(for schedule: ScheduleItem) {
        // 기존 알림 취소 (업데이트 시 중복 방지)
        cancelNotifications(for: schedule)
        
        // 알림 설정이 꺼져있거나 완료된 일정이면 스케줄링 하지 않음
        guard schedule.hasReminder, !schedule.isCompleted, !schedule.isPostponed else { return }
        
        // 10분 전 알림
        scheduleNotification(
            for: schedule,
            triggerDate: schedule.startDate.addingTimeInterval(-600), // 10분 전
            identifier: "\(schedule.id.uuidString)_10min",
            body: "10분뒤 일정이 시작됩니다!(\(schedule.subject)):\(schedule.title)"
        )
        
        // 정시 알림
        scheduleNotification(
            for: schedule,
            triggerDate: schedule.startDate,
            identifier: "\(schedule.id.uuidString)_onTime",
            body: "일정 시작 시간입니다!(\(schedule.subject)):\(schedule.title)"
        )
    }
    
    // 3. 알림 취소
    func cancelNotifications(for schedule: ScheduleItem) {
        let identifiers = [
            "\(schedule.id.uuidString)_10min",
            "\(schedule.id.uuidString)_onTime"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("알림 취소 완료: \(schedule.title)")
    }
    
    // 내부 헬퍼: 실제 알림 등록
    private func scheduleNotification(for schedule: ScheduleItem, triggerDate: Date, identifier: String, body: String) {
        // 과거 시간은 알림 예약 불가
        guard triggerDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📅 일정 알림"
        content.body = body
        content.sound = .default
        // ✨ [추가] 알림 클릭 시 딥링크를 위해 ID 포함
        content.userInfo = ["scheduleID": schedule.id.uuidString]
        
        // 날짜 기반 트리거 생성
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // 요청 생성 및 등록
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 등록 실패 (\(identifier)): \(error.localizedDescription)")
            } else {
                print("알림 등록 성공 (\(identifier)): \(triggerDate)")
            }
        }
    }
}
