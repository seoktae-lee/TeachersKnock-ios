import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class InvitationManager: ObservableObject {
    @Published var receivedInvitations: [StudyInvitation] = []
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 초대장 보내기
    func sendInvitation(groupID: String, groupName: String, inviterID: String, inviterName: String, receiverID: String, completion: @escaping (Bool, String?) -> Void) {
        // 중복 초대 확인
        db.collection("study_invitations")
            .whereField("groupID", isEqualTo: groupID)
            .whereField("receiverID", isEqualTo: receiverID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(false, "이미 대기 중인 초대가 있습니다.")
                    return
                }
                
                // 새 초대장 생성
                let ref = self?.db.collection("study_invitations").document()
                let invitation = StudyInvitation(
                    id: ref?.documentID ?? UUID().uuidString,
                    groupID: groupID,
                    groupName: groupName,
                    inviterID: inviterID,
                    inviterName: inviterName,
                    receiverID: receiverID
                )
                
                ref?.setData(invitation.toDictionary()) { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }
    }
    
    // 내가 받은 초대 목록 리스닝 (Pending 상태만)
    func listenReceivedInvitations() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 기존 리스너 제거
        listener?.remove()
        
        listener = db.collection("study_invitations")
            .whereField("receiverID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching invitations: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                self.receivedInvitations = documents.compactMap { StudyInvitation(document: $0) }
            }
    }
    
    // 리스너 중지
    func stopListening() {
        listener?.remove()
        listener = nil
        receivedInvitations = []
    }
    
    // 초대 수락
    func acceptInvitation(_ invitation: StudyInvitation, studyManager: StudyGroupManager, completion: @escaping (Bool) -> Void) {
        // 1. 그룹 멤버로 추가
        studyManager.addMember(groupID: invitation.groupID, newMemberUID: invitation.receiverID) { [weak self] success, message in
            if success {
                // 2. 초대장 상태를 'accepted'로 변경
                self?.updateInvitationStatus(invitationID: invitation.id, status: "accepted")
                
                // ✨ [Optimistic UI] 즉시 목록에서 제거하여 UI 반응성 향상
                DispatchQueue.main.async {
                    self?.receivedInvitations.removeAll { $0.id == invitation.id }
                }
                
                // ✨ [UX Improvement] 수락 즉시 해당 그룹 정보를 가져와서 로컬 목록에 추가 (리스너보다 빠르게)
                studyManager.fetchGroup(groupID: invitation.groupID) { group in
                    if let group = group {
                        DispatchQueue.main.async {
                            // 중복 방지 후 추가
                            if !studyManager.myGroups.contains(where: { $0.id == group.id }) {
                                studyManager.myGroups.insert(group, at: 0)
                            }
                        }
                    }
                }
                
                completion(true)
            } else {
                print("Failed to join group: \(message ?? "")")
                completion(false)
            }
        }
    }
    
    // 초대 거절
    func declineInvitation(_ invitation: StudyInvitation) {
        updateInvitationStatus(invitationID: invitation.id, status: "rejected")
        
        // ✨ [Optimistic UI] 즉시 목록에서 제거
        DispatchQueue.main.async {
            self.receivedInvitations.removeAll { $0.id == invitation.id }
        }
    }
    
    private func updateInvitationStatus(invitationID: String, status: String) {
        db.collection("study_invitations").document(invitationID).updateData([
            "status": status
        ]) { error in
            if let error = error {
                print("Error updating invitation status: \(error)")
            }
        }
    }
}
