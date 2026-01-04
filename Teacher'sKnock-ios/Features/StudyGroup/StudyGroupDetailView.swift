import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct StudyGroupDetailView: View {
    let group: StudyGroup
    @ObservedObject var studyManager: StudyGroupManager
    // ✨ [New] 화면 닫기용
    @Environment(\.dismiss) var dismiss
    
    @State private var showingInviteSheet = false
    @State private var showDeleteConfirmAlert = false
    @State private var showDeletedNoticeAlert = false
    
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
                        .padding(.leading)
                    Spacer()
                    Text("\(group.memberCount)/\(group.maxMembers)명")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.trailing)
                }
                
                VStack(spacing: 0) {
                    ForEach(group.members, id: \.self) { memberID in
                        MemberRow(
                            uid: memberID,
                            isLeader: memberID == group.leaderID,
                            isViewerLeader: isLeader,
                            groupID: group.id,
                            studyManager: studyManager
                        )
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
                    .padding(.horizontal)
                    .disabled(group.memberCount >= group.maxMembers)
                    
                    // ✨ [New] 그룹 삭제 버튼
                    Button(action: {
                        showDeleteConfirmAlert = true
                    }) {
                        Text("스터디 그룹 삭제하기")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
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
        // ✨ [New] 삭제 확인 Alert (방장용)
        .alert("스터디 삭제", isPresented: $showDeleteConfirmAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("정말 스터디를 삭제하시겠습니까?\n모든 멤버가 탈퇴 처리되며, 이 작업은 되돌릴 수 없습니다.")
        }
        // ✨ [New] 삭제 알림 Alert (멤버용)
        .alert("스터디 종료", isPresented: $showDeletedNoticeAlert) {
            Button("확인") {
                dismiss() // 확인 누르면 목록으로
            }
        } message: {
            Text("방장에 의해 스터디 그룹이 삭제되었습니다.")
        }
        .onAppear {
            observeGroupDeletion()
        }
    }
    
    // 그룹 삭제 (방장)
    func deleteGroup() {
        studyManager.deleteGroup(groupID: group.id) { success in
            if success {
                dismiss()
            }
        }
    }
    
    // 실시간 삭제 감지 (리스너)
    func observeGroupDeletion() {
        Firestore.firestore().collection("study_groups").document(group.id)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                
                // 문서가 존재하지 않음 == 삭제됨
                if !snapshot.exists {
                    // 내가 방장이 아닌 경우(또는 방장이더라도 이미 삭제 후 dismiss가 안된 경우) 알림 띄움
                    // 방장의 경우 deleteGroup() 성공 시 dismiss() 하므로 이 알림을 볼 확률은 낮으나 안전장치
                     if !showDeleteConfirmAlert { // 삭제 버튼 누른 상태가 아닐 때만
                         showDeletedNoticeAlert = true
                     }
                }
            }
    }
}

struct MemberRow: View {
    let uid: String
    let isLeader: Bool
    // ✨ [New] 위임 기능용
    let isViewerLeader: Bool // 현재 보고 있는 사람이 리더인가?
    let groupID: String
    @ObservedObject var studyManager: StudyGroupManager
    // 성공 시 dismiss 위한 클로저나 바인딩이 있으면 좋겠지만, 여기선 NotificationCenter나 상위 뷰 리프레시 유도
    // 간단히 Alert & Action 처리
    
    @State private var nickname: String = "로딩 중..."
    @State private var university: String = ""
    @State private var showDelegateAlert = false
    
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
        // ✨ [New] Context Menu for Leader Delegation
        .contextMenu {
            if isViewerLeader && !isLeader { // 내가 리더인데 상대방이 리더가 아닌 경우
                Button(role: .destructive) {
                    showDelegateAlert = true
                } label: {
                    Label("방장 위임하기", systemImage: "crown")
                }
            }
        }
        .alert("방장 위임", isPresented: $showDelegateAlert) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                delegateLeader()
            }
        } message: {
            Text("'\(nickname)' 님에게 방장 권한을 넘기시겠습니까?\n방장은 스터디 관리 권한을 갖으며, 이 작업은 되돌릴 수 없습니다.")
        }
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
    
    func delegateLeader() {
        studyManager.delegateLeader(groupID: groupID, newLeaderUID: uid) { success in
            if success {
                // UI 갱신 (상위 뷰에서 리스너가 동작하므로 자동 갱신 기대, 
                // 하지만 DetailView는 static group을 들고 있어서 바로 반영 안될 수 있음.
                // UX: 토스트 띄우고 Back or Reload)
                // 현재 구조상 가장 깔끔한 건 Pop 하는 것.
                // 여기서는 일단 로그 찍고, 상위 뷰가 닫히게 하거나 해야 함.
                // SwiftUI 뷰 계층 구조 이슈로 dismiss를 직접 호출하긴 복잡하므로 
                // NotificationCenter로 'LeaderChanged' 노티를 보내 뷰를 닫거나 할 수 있음.
                // 우선은 성공 메시지만 콘솔에.
                print("방장 위임 성공")
            }
        }
    }
}
