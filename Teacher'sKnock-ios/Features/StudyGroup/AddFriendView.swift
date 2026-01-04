import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var friendManager: FriendManager
    let myUID: String
    
    @State private var searchID = ""
    @State private var searchResult: User?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Search Bar
                HStack {
                    TextField("친구의 티처스노크 ID 입력 (예: A1B2C3)", text: $searchID)
                        .autocapitalization(.allCharacters)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .onSubmit { searchUser() }
                    
                    Button(action: searchUser) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(red: 0.35, green: 0.65, blue: 0.95)) // Primary Color
                            .cornerRadius(10)
                    }
                    .disabled(searchID.isEmpty || isSearching)
                }
                .padding()
                
                if isSearching {
                    ProgressView()
                } else if let error = searchError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                } else if let user = searchResult {
                    // Search Result Card
                    VStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(user.nickname)
                            .font(.title2.bold())
                        
                        if let univ = user.university {
                            Text(univ)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                            
                        Text("ID: \(user.teacherKnockID ?? "없음")")
                            .font(.caption)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button(action: { addFriend(user: user) }) {
                            Text("친구 추가")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("친구 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("친구 추가 완료", isPresented: $showSuccessAlert) {
                Button("확인") { dismiss() }
            } message: {
                Text("\(searchResult?.nickname ?? "")님을 친구로 추가했습니다.")
            }
        }
    }
    
    // 유저 검색 (FriendManager에는 없는 단순 조회 로직이라 여기서 구현 혹은 Manager로 이동)
    // FriendManager에 searchUser 추가하는 것이 깔끔함. 하지만 우선 여기서 Firestore 직접 호출 (기존 패턴 유지)
    // or better, use FriendManager to search? No, Manager is for managing friends list.
    // Let's adapt to use Firestore directly here for simplicity as per previous MemberInviteView pattern.
    func searchUser() {
        guard !searchID.isEmpty else { return }
        isSearching = true
        searchError = nil
        searchResult = nil
        
        let db = FirebaseFirestore.Firestore.firestore()
        db.collection("users")
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
                
                // 자신을 검색한 경우
                if document.documentID == myUID {
                    searchError = "자기 자신은 친구로 추가할 수 없습니다."
                    return
                }
                
                // 이미 친구인지 확인 (FriendManager의 목록에서 확인)
                if friendManager.friends.contains(where: { $0.id == document.documentID }) {
                    searchError = "이미 친구로 등록된 사용자입니다."
                    
                    // 그래도 결과는 보여주되 버튼을 비활성화? 
                    // 로직상 검색 결과 보여주고 버튼 누르면 '이미 친구입니다' 해도 됨.
                    // 여기선 Error 띄우고 결과 안 보여줌.
                    return
                }
                
                if let user = User(document: document) {
                    self.searchResult = user
                } else {
                    searchError = "유저 정보를 불러올 수 없습니다."
                }
            }
    }
    
    func addFriend(user: User) {
        friendManager.addFriend(myUID: myUID, friendTKID: user.teacherKnockID ?? "") { success, message in
            if success {
                showSuccessAlert = true
            } else {
                searchError = message ?? "친구 추가 실패"
            }
        }
    }
}
