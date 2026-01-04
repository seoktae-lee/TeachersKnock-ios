import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MemberInviteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var studyManager: StudyGroupManager
    // ✨ [New] 친구 목록 관리자
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
        }
    }
    
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
                    // searchError = "이미 스터디에 참여 중인 멤버입니다." 
                    // 검색 결과는 보여주되 버튼을 비활성화하거나 알림을 주는게 나을 수 있음.
                    // 기존 로직 유지
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
        studyManager.addMember(groupID: group.id, newMemberUID: user.id) { success, message in
            if success {
                dismiss()
            } else {
                searchError = message ?? "초대에 실패했습니다."
            }
        }
    }
    
    func inviteFriend(friend: User) {
        studyManager.addMember(groupID: group.id, newMemberUID: friend.id) { success, message in
            if success {
                // 성공하면 토스트 메시지나 알림을 띄우고 창을 닫을 수도 있음
                // 여기선 간단히 닫기
                dismiss()
            } else {
                searchError = message ?? "초대에 실패했습니다."
            }
        }
    }
}
