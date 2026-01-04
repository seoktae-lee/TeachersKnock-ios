import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MemberInviteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var studyManager: StudyGroupManager
    // ✨ [New] 초대 관리자
    @StateObject private var invitationManager = InvitationManager()
    @StateObject private var friendManager = FriendManager()
    
    let group: StudyGroup
    
    @State private var searchID = ""
    @State private var searchResult: UserProfile?
    @State private var isSearching = false
    @State private var searchError: String?
    
    // 친구 검색용(필터링)
    @State private var friendSearchText = ""
    
    struct UserProfile: Identifiable {
        let id: String // uid
        let nickname: String
        let tkID: String
        let university: String
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. ID로 직접 검색 (기존 유지 확인)
                VStack(spacing: 12) {
                    Text("ID로 친구 찾기")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("티처스노크 ID 입력", text: $searchID)
                            .autocapitalization(.allCharacters)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onSubmit { searchUser() }
                        
                        Button(action: searchUser) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                
                // 검색 결과 표시
                if let error = searchError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                } else if let user = searchResult {
                    searchResultCard(user: user)
                }
                
                Divider().padding(.vertical)
                
                // 2. 내 친구 목록에서 초대
                VStack(alignment: .leading, spacing: 10) {
                    Text("내 친구 목록에서 초대")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if friendManager.friends.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Text("아직 친구가 없어요 🥲")
                                .foregroundColor(.gray)
                            Text("ID로 검색해서 친구를 초대해보세요!")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(friendManager.friends) { friend in
                                    // 이미 그룹 멤버인지 확인
                                    let isAlreadyMember = group.members.contains(friend.id)
                                    
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(friend.nickname)
                                                .font(.subheadline.bold())
                                            Text(friend.teacherKnockID ?? "-")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        if isAlreadyMember {
                                            Text("멤버")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(8)
                                        } else {
                                            Button("초대") {
                                                inviteFriend(friend: friend)
                                            }
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("멤버 초대")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                if let uid = Auth.auth().currentUser?.uid {
                    friendManager.observeFriends(myUID: uid)
                }
            }
            // ✨ [New] 알림 표시
            .alert(isPresented: $showAlert) {
                Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
            }
        }
    }
    
    // Alert State
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // UI Component: Search Result Card
    func searchResultCard(user: UserProfile) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.nickname).fontWeight(.bold)
                Text(user.university).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Button("초대") {
                inviteUser(user: user)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.35, green: 0.65, blue: 0.95))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    func searchUser() {
        guard !searchID.isEmpty else { return }
        isSearching = true
        searchError = nil
        searchResult = nil
        
        Firestore.firestore().collection("users")
            .whereField("teacherKnockID", isEqualTo: searchID)
            .getDocuments { snapshot, error in
                isSearching = false
                if let error = error {
                    searchError = "검색 중 오류가 발생했습니다."
                    print(error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    searchError = "해당 ID를 가진 사용자를 찾을 수 없습니다."
                    return
                }
                
                let data = document.data()
                let uid = document.documentID
                
                // 이미 멤버인지 확인
                if group.members.contains(uid) {
                    searchError = "이미 스터디에 참여 중인 멤버입니다."
                    return
                }
                
                self.searchResult = UserProfile(
                    id: uid,
                    nickname: data["nickname"] as? String ?? "알 수 없음",
                    tkID: data["teacherKnockID"] as? String ?? "",
                    university: data["university"] as? String ?? ""
                )
            }
    }
    
    func inviteUser(user: UserProfile) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        
        // 내 정보(초대자 이름) 가져오기 위함인데, 간단히 현재 Auth display name 사용하거나
        // 여기선 닉네임을 따로 fetch 안했으니 "초대자" 정도로 하거나, 이전 화면에서 넘겨받아야 좋음.
        // FriendManager나 AuthManager에서 내 닉네임을 알 수 있으면 좋음.
        // 현재 코드 문맥상 내 닉네임을 알기 어려우므로 일단 "익명" 처리 혹은 UserDefault 등 확인 필요.
        // 개선: StudyGroupDetailView -> MemberInviteView로 내 닉네임 전달 받는게 좋음.
        // 일단은 Firestore에서 내 정보를 잠깐 읽거나, MyPageViewModel 등을 활용해야 함.
        // 여기서는 빠르게 구현하기 위해 내 닉네임을 "스터디장" 등으로 하거나, 비동기로 내 정보 fetch.
        
        // 간단한 해결책: 초대자 이름을 "초대"로 하거나, 받는 사람이 누군지 알 수 있게...
        // FriendManager에 내 프로필 정보가 있다면 베스트.
        // 일단 비동기로 내 정보 가져와서 보냄.
        
        fetchMyNickname(uid: myUID) { myNickname in
            invitationManager.sendInvitation(
                groupID: group.id,
                groupName: group.name,
                inviterID: myUID,
                inviterName: myNickname,
                receiverID: user.id
            ) { success, message in
                if success {
                    alertMessage = "초대장을 보냈습니다!"
                    showAlert = true
                    searchResult = nil // 검색 결과 초기화
                    searchID = ""
                } else {
                    alertMessage = message ?? "초대 실패"
                    showAlert = true
                }
            }
        }
    }
    
    func inviteFriend(friend: User) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        
        fetchMyNickname(uid: myUID) { myNickname in
            invitationManager.sendInvitation(
                groupID: group.id,
                groupName: group.name,
                inviterID: myUID,
                inviterName: myNickname,
                receiverID: friend.id
            ) { success, message in
                if success {
                    alertMessage = "\(friend.nickname)님에게 초대장을 보냈습니다!"
                    showAlert = true
                } else {
                    alertMessage = message ?? "초대 실패"
                    showAlert = true
                }
            }
        }
    }
    
    // Helper to get my nickname
    func fetchMyNickname(uid: String, completion: @escaping (String) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), let nickname = data["nickname"] as? String {
                completion(nickname)
            } else {
                completion("알 수 없음")
            }
        }
    }
}
