import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class FriendRequestManager: ObservableObject {
    @Published var receivedRequests: [FriendRequest] = []
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 친구 신청 보내기
    func sendRequest(senderID: String, senderName: String, receiverID: String, completion: @escaping (Bool, String?) -> Void) {
        // 이미 친구인지 확인은 UI나 상위 로직에서 체크 (AddFriendView 등)
        // 중복 신청 확인
        db.collection("friend_requests")
            .whereField("senderID", isEqualTo: senderID)
            .whereField("receiverID", isEqualTo: receiverID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(false, "이미 보낸 친구 신청이 대기 중입니다.")
                    return
                }
                
                // 새 신청 생성
                let ref = self?.db.collection("friend_requests").document()
                let request = FriendRequest(
                    id: ref?.documentID ?? UUID().uuidString,
                    senderID: senderID,
                    senderName: senderName,
                    receiverID: receiverID
                )
                
                ref?.setData(request.toDictionary()) { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }
    }
    
    // 받은 친구 신청 리스닝
    func listenReceivedRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        listener?.remove()
        
        listener = db.collection("friend_requests")
            .whereField("receiverID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                
                self.receivedRequests = documents.compactMap { FriendRequest(document: $0) }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        receivedRequests = []
    }
    
    // 친구 수락 (양방향 친구 추가 Transaction)
    func acceptRequest(_ request: FriendRequest, friendManager: FriendManager, completion: @escaping (Bool) -> Void) {
        let senderRef = db.collection("users").document(request.senderID)
        let receiverRef = db.collection("users").document(request.receiverID)
        let requestRef = db.collection("friend_requests").document(request.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // 1. 상태 업데이트
            transaction.updateData(["status": "accepted"], forDocument: requestRef)
            
            // 2. Sender의 친구 목록에 Receiver 추가
            transaction.updateData(["friends": FieldValue.arrayUnion([request.receiverID])], forDocument: senderRef)
            
            // 3. Receiver의 친구 목록에 Sender 추가
            transaction.updateData(["friends": FieldValue.arrayUnion([request.senderID])], forDocument: receiverRef)
            
            return nil
            
        }) { [weak self] (object, error) in
            if let error = error {
                print("Error accepting friend request: \(error)")
                completion(false)
            } else {
                // ✨ [Optimistic UI] 로컬 목록에서 즉시 제거
                DispatchQueue.main.async {
                    self?.receivedRequests.removeAll { $0.id == request.id }
                    // 친구 목록 갱신은 FriendManager 리스너가 처리하지만,
                    // 필요하다면 여기서 즉시 FriendManager에 fetch 요청을 트리거할 수도 있음.
                    // 실시간 리스너가 있으므로 자동 반영됨.
                }
                completion(true)
            }
        }
    }
    
    // 친구 거절
    func declineRequest(_ request: FriendRequest) {
        db.collection("friend_requests").document(request.id).updateData([
            "status": "rejected"
        ])
        
        // ✨ [Optimistic UI] 즉시 제거
        DispatchQueue.main.async {
            self.receivedRequests.removeAll { $0.id == request.id }
        }
    }
}
