import Foundation
import FirebaseFirestore
import Combine

class GroupScheduleManager: ObservableObject {
    @Published var groupSchedules: [GroupSchedule] = []
    @Published var globalSchedules: [GroupSchedule] = []
    
    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        listeners.forEach { $0.remove() }
    }
    
    // MARK: - Fetch Single Group Schedules
    func listenToGroupSchedules(groupID: String) {
        // 기존 리스너 제거 (그룹 변경 시)
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        let listener = db.collection("study_groups").document(groupID).collection("schedules")
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching schedules: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.groupSchedules = documents.compactMap { GroupSchedule(document: $0) }
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Fetch Global Schedules (All Joined Groups)
    // Firestore 쿼리 한계로 인해, 내 그룹 ID 목록을 받아서 각각 쿼리하거나,
    // 클라이언트 사이드 조인이 필요할 수 있음.
    // 여기서는 내 그룹 목록을 순회하며 리스너를 붙이는 방식을 사용 (그룹 수가 많지 않다고 가정)
    func listenToGlobalSchedules(myGroupIDs: [String]) {
        // 기존 리스너 제거
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        self.globalSchedules = []
        
        for groupID in myGroupIDs {
            let listener = db.collection("study_groups").document(groupID).collection("schedules")
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    guard let documents = snapshot?.documents else { return }
                    
                    let newSchedules = documents.compactMap { GroupSchedule(document: $0) }
                    
                    // 기존 목록에서 해당 그룹의 스케줄을 제거하고 새로 받은걸 추가하여 업데이트
                    // (단순 append가 아니라 전체 재정렬 필요)
                    var current = self.globalSchedules.filter { $0.groupID != groupID }
                    current.append(contentsOf: newSchedules)
                    
                    self.globalSchedules = current.sorted { $0.date < $1.date }
                }
            listeners.append(listener)
        }
    }
    
    // MARK: - CRUD
    func addSchedule(schedule: GroupSchedule, completion: @escaping (Bool) -> Void) {
        let ref = db.collection("study_groups").document(schedule.groupID).collection("schedules").document()
        var data = schedule.toDictionary()
        
        // Batch write to update both Schedule and Group Notice
        let batch = db.batch()
        batch.setData(data, forDocument: ref)
        
        let groupRef = db.collection("study_groups").document(schedule.groupID)
        let noticeMsg = "📅 [일정 등록] \(schedule.title) (\(dateString(schedule.date)))"
        
        batch.updateData([
            "notice": noticeMsg,
            "noticeUpdatedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp() // To trigger list badge
        ], forDocument: groupRef)
        
        batch.commit { error in
            if let error = error {
                print("Error adding schedule: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func updateSchedule(schedule: GroupSchedule, completion: @escaping (Bool) -> Void) {
        let ref = db.collection("study_groups").document(schedule.groupID).collection("schedules").document(schedule.id)
        let data = schedule.toDictionary()
        
        let batch = db.batch()
        batch.updateData(data, forDocument: ref)
        
        let groupRef = db.collection("study_groups").document(schedule.groupID)
        let noticeMsg = "📅 [일정 수정] \(schedule.title) (\(dateString(schedule.date)))"
        
        batch.updateData([
            "notice": noticeMsg,
            "noticeUpdatedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)
        
        batch.commit { error in
            if let error = error {
                print("Error updating schedule: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d a h:mm"
        return f.string(from: date)
    }
    
    func deleteSchedule(groupID: String, scheduleID: String, completion: @escaping (Bool) -> Void) {
        db.collection("study_groups").document(groupID).collection("schedules").document(scheduleID).delete { error in
            if let error = error {
                print("Error deleting schedule: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - Helpers
    func schedules(at date: Date, from list: [GroupSchedule]) -> [GroupSchedule] {
        let calendar = Calendar.current
        return list.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
