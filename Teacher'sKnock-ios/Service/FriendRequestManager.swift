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
        // 1. 이미 친구인지 확인 (서버 사이드 체크)
        db.collection("users").document(senderID).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            let friends = snapshot?.data()?["friends"] as? [String] ?? []
            if friends.contains(receiverID) {
                completion(false, "이미 친구인 사용자입니다.")
                return
            }
            
            // 2. 중복 신청 확인 (Pending 상태인 것만)
            self.db.collection("friend_requests")
                .whereField("senderID", isEqualTo: senderID)
                .whereField("receiverID", isEqualTo: receiverID)
                .whereField("status", isEqualTo: "pending")
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                        return
                    }
                    
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        completion(false, "이미 보낸 친구 신청이 대기 중입니다.")
                        return
                    }
                    
                    // 3. 새 신청 생성
                    let ref = self.db.collection("friend_requests").document()
                    let request = FriendRequest(
                        id: ref.documentID,
                        senderID: senderID,
                        senderName: senderName,
                        receiverID: receiverID
                    )
                    
                    ref.setData(request.toDictionary()) { error in
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            completion(true, nil)
                        }
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
        
        // ✨ [Modified] 해당 Sender가 보낸 '모든' pending 요청을 찾아서 처리
        // 트랜잭션 내에서 쿼리가 복잡해질 수 있으므로, 먼저 pending 요청들의 ID를 조회합니다.
        // 하지만 트랜잭션 원자성을 위해선 읽기/쓰기가 모두 트랜잭션 내에 있어야 완벽하지만,
        // 여기서는 "사용자 경험상 중복이 사라지는 것"이 중요하므로
        // 1. 친구 추가 트랜잭션 성공 후
        // 2. Batch write로 나머지 요청들을 정리하는 방식이 효율적입니다.
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // 1. Sender의 친구 목록에 Receiver 추가
            transaction.updateData(["friends": FieldValue.arrayUnion([request.receiverID])], forDocument: senderRef)
            
            // 2. Receiver의 친구 목록에 Sender 추가
            transaction.updateData(["friends": FieldValue.arrayUnion([request.senderID])], forDocument: receiverRef)
            
            return nil
            
        }) { [weak self] (object, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error accepting friend request: \(error)")
                completion(false)
            } else {
                // 성공 시: 해당 Sender <-> Receiver 간의 모든 pending 요청을 accepted로 변경
                self.acceptAllPendingRequests(from: request.senderID, to: request.receiverID)
                
                // ✨ [Optimistic UI] 로컬 목록에서 즉시 제거
                DispatchQueue.main.async {
                    self.receivedRequests.removeAll { $0.senderID == request.senderID }
                }
                completion(true)
            }
        }
    }
    
    // Helper: 모든 보류 중인 요청 일괄 수락 처리
    private func acceptAllPendingRequests(from senderID: String, to receiverID: String) {
        db.collection("friend_requests")
            .whereField("senderID", isEqualTo: senderID)
            .whereField("receiverID", isEqualTo: receiverID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                let batch = self.db.batch()
                for doc in documents {
                    batch.updateData(["status": "accepted"], forDocument: doc.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("Error batch updating requests: \(error)")
                    }
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
