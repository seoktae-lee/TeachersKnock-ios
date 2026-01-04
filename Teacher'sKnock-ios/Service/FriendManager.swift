import Foundation
import FirebaseFirestore
import Combine

class FriendManager: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    private var db = Firestore.firestore()
    
    // 친구 목록 실시간 리스너
    func observeFriends(myUID: String) {
        // 1. 내 정보에서 friends 배열을 먼저 가져옴 (실시간)
        db.collection("users").document(myUID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data() else { return }
                
                let friendUIDs = data["friends"] as? [String] ?? []
                self.fetchFriendDetails(uids: friendUIDs)
            }
    }
    
    // 친구들의 상세 정보를 가져옴
    private func fetchFriendDetails(uids: [String]) {
        guard !uids.isEmpty else {
            self.friends = []
            return
        }
        
        // Firestore 'in' 쿼리는 최대 10개까지만 가능하므로, 
        // 친구가 많아질 경우를 대비해 청크로 나누거나 반복 요청해야 함.
        // 현재는 간단히 10개 제한 혹은 반복 로직 적용 (여기선 단순화하여 각각 fetch)
        // 더 좋은 방법: whereField("uid", in: uids) -> max 10.
        // 우선 안전하게 각 문서 fetch 후 병합 (N번 요청이지만 확실함, 친구 수가 적을 때 유효)
        
        // 개선: chunks of 10 for 'in' query
        let chunks = uids.chunked(into: 10)
        var newFriends: [User] = []
        let group = DispatchGroup()
        
        for chunk in chunks {
            group.enter()
            db.collection("users").whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        let users = documents.compactMap { User(document: $0) }
                        newFriends.append(contentsOf: users)
                    }
                    group.leave()
                }
        }
        
        group.notify(queue: .main) {
            self.friends = newFriends.sorted(by: { $0.nickname < $1.nickname })
        }
    }
    
    // ID로 친구 추가
    func addFriend(myUID: String, friendTKID: String, completion: @escaping (Bool, String?) -> Void) {
        // 1. 해당 TKID를 가진 유저 찾기
        db.collection("users")
            .whereField("teacherKnockID", isEqualTo: friendTKID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(false, "검색 중 오류가 발생했습니다.")
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(false, "해당 ID의 유저를 찾을 수 없습니다.")
                    return
                }
                
                let friendUID = document.documentID
                
                if friendUID == myUID {
                    completion(false, "자기 자신은 친구로 추가할 수 없습니다.")
                    return
                }
                
                // 2. 이미 친구인지 확인 (로컬 friends 배열 활용 가능하지만 서버 정합성 위해 여기서 체크 or arrayUnion 사용)
                // Firestore arrayUnion은 중복 자동 방지
                
                self.db.collection("users").document(myUID).updateData([
                    "friends": FieldValue.arrayUnion([friendUID])
                ]) { error in
                    if let error = error {
                        print("Error adding friend: \(error)")
                        completion(false, "친구 추가에 실패했습니다.")
                    } else {
                        completion(true, nil)
                    }
                }
            }
    }
    
    // 친구 삭제
    func removeFriend(myUID: String, friendUID: String) {
        db.collection("users").document(myUID).updateData([
            "friends": FieldValue.arrayRemove([friendUID])
        ])
    }
}

// Helper for chunking array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
