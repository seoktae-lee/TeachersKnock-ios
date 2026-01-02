import SwiftUI
import FirebaseFirestore

struct MemberInviteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var studyManager: StudyGroupManager
    let group: StudyGroup
    
    @State private var searchID = ""
    @State private var searchResult: UserProfile?
    @State private var isSearching = false
    @State private var searchError: String?
    
    struct UserProfile: Identifiable {
        let id: String // uid
        let nickname: String
        let tkID: String
        let university: String
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Search Bar
                HStack {
                    TextField("티처스노크 ID 검색 (예: A1B2C3)", text: $searchID)
                        .autocapitalization(.allCharacters) // ID is usually uppercase/alphanumeric
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    Button(action: searchUser) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                            .cornerRadius(10)
                    }
                    .disabled(searchID.isEmpty || isSearching)
                }
                .padding()
                
                if isSearching {
                    ProgressView()
                } else if let error = searchError {
                    Text(error)
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
                        
                        Text(user.university)
                            .font(.caption)
                            .foregroundColor(.gray)
                            
                        Text("ID: \(user.tkID)")
                            .font(.caption)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button(action: { inviteUser(user: user) }) {
                            Text("그룹에 추가")
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
            .navigationTitle("스터디원 초대")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
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
        studyManager.addMember(groupID: group.id, newMemberUID: user.id) { success, message in
            if success {
                dismiss()
            } else {
                searchError = message ?? "초대에 실패했습니다."
            }
        }
    }
}
