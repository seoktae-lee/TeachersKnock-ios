import Foundation
import FirebaseFirestore
import Combine

class StudyGroupManager: ObservableObject {
    @Published var myGroups: [StudyGroup] = []
    private var db = Firestore.firestore()
    
    // 나의 스터디 그룹 실시간 리스너
    func fetchMyGroups(uid: String) {
        db.collection("study_groups")
            .whereField("members", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching groups: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                self.myGroups = documents.compactMap { StudyGroup(document: $0) }
            }
    }
    
    func createGroup(name: String, description: String, leaderID: String, completion: @escaping (Bool) -> Void) {
        // 미리 문서 레퍼런스를 생성하여 ID를 확보
        let ref = db.collection("study_groups").document()
        let newGroup = StudyGroup(id: ref.documentID, name: name, description: description, leaderID: leaderID, members: [leaderID])
        
        ref.setData(newGroup.toDictionary()) { error in
            if let error = error {
                print("Error creating group: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func addMember(groupID: String, newMemberUID: String, completion: @escaping (Bool, String?) -> Void) {
        let groupRef = db.collection("study_groups").document(groupID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let groupDoc: DocumentSnapshot
            do {
                try groupDoc = transaction.getDocument(groupRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            guard let data = groupDoc.data(),
                  let maxMembers = data["maxMembers"] as? Int,
                  let members = data["members"] as? [String] else {
                return nil
            }
            
            if members.count >= maxMembers {
                let error = NSError(domain: "StudyGroupError", code: 400, userInfo: [NSLocalizedDescriptionKey: "스터디 정원이 초과되었습니다."])
                errorPointer?.pointee = error
                return nil
            }
            
            if members.contains(newMemberUID) {
                let error = NSError(domain: "StudyGroupError", code: 401, userInfo: [NSLocalizedDescriptionKey: "이미 가입된 멤버입니다."])
                errorPointer?.pointee = error
                return nil
            }
            
            transaction.updateData(["members": FieldValue.arrayUnion([newMemberUID])], forDocument: groupRef)
            return nil
            
        }) { (object, error) in
            if let error = error as NSError? {
                print("멤버 추가 실패: \(error)")
                completion(false, error.userInfo[NSLocalizedDescriptionKey] as? String ?? "오류가 발생했습니다.")
            } else {
                completion(true, nil)
            }
        }
    }
    
    func leaveGroup(groupID: String, uid: String, completion: @escaping (Bool) -> Void) {
        db.collection("study_groups").document(groupID).updateData([
            "members": FieldValue.arrayRemove([uid])
        ]) { error in
            completion(error == nil)
        }
    }
}
