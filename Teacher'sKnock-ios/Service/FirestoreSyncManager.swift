import Foundation
import FirebaseFirestore
import SwiftData

class FirestoreSyncManager {
    static let shared = FirestoreSyncManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - 1. 데이터 저장 (백업)
    
    // 일정 저장
    func saveSchedule(_ item: ScheduleItem) {
        let docRef = db.collection("users").document(item.ownerID).collection("schedules").document(item.id.uuidString)
        docRef.setData(item.asDictionary) { error in
            if let error = error {
                print("❌ FirestoreSync: 일정 저장 실패 - \(error.localizedDescription)")
            } else {
                print("✅ FirestoreSync: 일정 저장 완료")
            }
        }
    }
    
    // ✨ [추가] 감정 일기 저장
    func saveNote(_ note: DailyNote) {
        let docRef = db.collection("users").document(note.ownerID).collection("notes").document(note.id.uuidString)
        docRef.setData(note.asDictionary) { error in
            if let error = error {
                print("❌ FirestoreSync: 일기 저장 실패 - \(error)")
            } else {
                print("✅ FirestoreSync: 일기 저장 완료")
            }
        }
    }
    
    // 공부 기록 저장
    func saveRecord(_ record: StudyRecord) {
        let data: [String: Any] = [
            "durationSeconds": record.durationSeconds,
            "areaName": record.areaName,
            "date": Timestamp(date: record.date),
            "ownerID": record.ownerID,
            "studyPurpose": record.studyPurpose
        ]
        
        db.collection("users").document(record.ownerID).collection("study_records").addDocument(data: data)
    }
    
    // MARK: - 2. 데이터 복구 (로그인 시 호출)
    
    @MainActor
    func restoreData(context: ModelContext, uid: String, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // (1) 일정 복구
        group.enter()
        db.collection("users").document(uid).collection("schedules").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                print("🔄 일정 복구 시작: 총 \(documents.count)개 발견")
                for doc in documents {
                    let data = doc.data()
                    
                    let idString = data["id"] as? String ?? UUID().uuidString
                    let id = UUID(uuidString: idString) ?? UUID()
                    
                    let title = data["title"] as? String ?? "제목 없음"
                    let details = data["details"] as? String ?? ""
                    
                    let startDate: Date
                    if let startTs = data["startDate"] as? Double {
                        startDate = Date(timeIntervalSince1970: startTs)
                    } else if let startTimestamp = data["startDate"] as? Timestamp {
                        startDate = startTimestamp.dateValue()
                    } else { startDate = Date() }
                    
                    let endDate: Date?
                    if let endTs = data["endDate"] as? Double {
                        endDate = Date(timeIntervalSince1970: endTs)
                    } else if let endTimestamp = data["endDate"] as? Timestamp {
                        endDate = endTimestamp.dateValue()
                    } else { endDate = startDate.addingTimeInterval(3600) }
                    
                    let subject = data["subject"] as? String ?? "교육학"
                    let isCompleted = data["isCompleted"] as? Bool ?? false
                    let isPostponed = data["isPostponed"] as? Bool ?? false
                    let hasReminder = data["hasReminder"] as? Bool ?? false
                    
                    let newItem = ScheduleItem(
                        id: id, title: title, details: details, startDate: startDate, endDate: endDate,
                        subject: subject, isCompleted: isCompleted, hasReminder: hasReminder,
                        ownerID: uid, isPostponed: isPostponed
                    )
                    context.insert(newItem)
                }
            }
            group.leave()
        }
        
        // (2) ✨ [추가] 감정 일기 복구
        group.enter()
        db.collection("users").document(uid).collection("notes").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                print("🔄 감정 일기 복구 시작: 총 \(documents.count)개 발견")
                for doc in documents {
                    let data = doc.data()
                    
                    let idString = data["id"] as? String ?? UUID().uuidString
                    let id = UUID(uuidString: idString) ?? UUID()
                    
                    let emotion = data["emotion"] as? String ?? "😐"
                    let content = data["content"] as? String ?? ""
                    
                    let date: Date
                    if let dateTs = data["date"] as? Double {
                        date = Date(timeIntervalSince1970: dateTs)
                    } else { date = Date() }
                    
                    let newNote = DailyNote(id: id, date: date, emotion: emotion, content: content, ownerID: uid)
                    context.insert(newNote)
                }
            }
            group.leave()
        }
        
        // (3) 공부 기록 복구
        group.enter()
        db.collection("users").document(uid).collection("study_records").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                print("🔄 공부 기록 복구 시작: 총 \(documents.count)개 발견")
                for doc in documents {
                    let data = doc.data()
                    
                    let duration = data["durationSeconds"] as? Int ?? 0
                    let areaName = data["areaName"] as? String ?? "기타"
                    let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    let purpose = data["studyPurpose"] as? String ?? "자습"
                    
                    let newRecord = StudyRecord(
                        durationSeconds: duration, areaName: areaName, date: date,
                        ownerID: uid, studyPurpose: purpose
                    )
                    context.insert(newRecord)
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("✅ FirestoreSyncManager: 모든 데이터 복구 및 동기화 완료")
            completion()
        }
    }
}
