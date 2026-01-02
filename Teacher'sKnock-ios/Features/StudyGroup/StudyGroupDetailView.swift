import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct StudyGroupDetailView: View {
    let group: StudyGroup
    @ObservedObject var studyManager: StudyGroupManager
    @State private var showingInviteSheet = false
    
    // Check if current user is leader
    var isLeader: Bool {
        group.leaderID == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.name)
                        .font(.largeTitle.bold())
                    
                    if !group.description.isEmpty {
                        Text(group.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                }
                .padding()
                
                Divider()
                
                // Members
                HStack {
                    Text("멤버")
                        .font(.headline)
                    Spacer()
                    Text("\(group.memberCount)/\(group.maxMembers)명")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(group.members, id: \.self) { memberID in
                        MemberRow(uid: memberID, isLeader: memberID == group.leaderID)
                        Divider()
                            .padding(.leading, 60)
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)
                
                if isLeader {
                    Button(action: { showingInviteSheet = true }) {
                        Label("멤버 초대하기", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(group.memberCount >= group.maxMembers ? Color.gray : Color(red: 0.35, green: 0.65, blue: 0.95))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(group.memberCount >= group.maxMembers)
                } else {
                    Button(action: {
                        // Leave group logic (To be implemented)
                    }) {
                        Text("스터디 나가기")
                            .foregroundColor(.red)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("스터디 상세")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInviteSheet) {
             MemberInviteView(studyManager: studyManager, group: group)
                .presentationDetents([.medium, .large])
        }
    }
}

struct MemberRow: View {
    let uid: String
    let isLeader: Bool
    
    @State private var nickname: String = "로딩 중..."
    @State private var university: String = ""
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(nickname)
                        .font(.body.bold())
                    if isLeader {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                if !university.isEmpty {
                    Text(university)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            fetchUserProfile()
        }
    }
    
    func fetchUserProfile() {
        Firestore.firestore().collection("users").document(uid).getDocument { doc, error in
            if let data = doc?.data() {
                self.nickname = data["nickname"] as? String ?? "알 수 없음"
                self.university = data["university"] as? String ?? ""
            }
        }
    }
}
