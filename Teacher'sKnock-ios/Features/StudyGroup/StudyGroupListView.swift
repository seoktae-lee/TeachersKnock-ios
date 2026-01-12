import SwiftUI
import FirebaseAuth

struct StudyGroupListView: View {
    @StateObject private var studyManager = StudyGroupManager()
    // ✨ [Modified] MainTabView로부터 주입받음 (Badge 연동을 위해 상위에서 관리)
    @ObservedObject var invitationManager: InvitationManager
    // ✨ [New] 친구 신청 매니저 주입
    @ObservedObject var friendRequestManager: FriendRequestManager
    
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingCreateSheet = false
    @State private var selectedTab: StudyTabMode = .group
    @State private var navigationPath = NavigationPath() // ✨ [New] 네비게이션 경로 관리
    
    // ✨ [New] 네비게이션 매니저 (경로 제어용) -> MainTabView와 공유된 인스턴스 사용
    @ObservedObject var navManager = StudyNavigationManager.shared
    
    enum StudyTabMode: String, CaseIterable {
        case group = "스터디 그룹"
        case friend = "친구 목록"
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Custom Segmented Control or Picker
                Picker("모드", selection: $selectedTab) {
                    ForEach(StudyTabMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                
                // Content View
                if selectedTab == .group {
                    groupListView
                } else {
                    FriendListView(requestManager: friendRequestManager)
                }
            }
            .navigationTitle("공유 스터디")
            .navigationDestination(for: StudyGroup.self) { group in
                StudyGroupDetailView(group: group, studyManager: studyManager)
            }
// ToolbarItem removed
        }
        // ✨ [New] 외부(일정 탭 등)에서 요청된 그룹으로 이동
        .onChange(of: navManager.targetGroupID) { groupID in
            guard let groupID = groupID else { return }
            
            // 그룹 찾기
            if let group = studyManager.myGroups.first(where: { $0.id == groupID }) {
                // 경로 초기화 및 이동
                navigationPath = NavigationPath()
                navigationPath.append(group)
                
                // 타겟 초기화
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                   navManager.clearTarget()
                }
            }
        }
        // ✨ [New] 그룹 목록 지연 로드 대응
        .onChange(of: studyManager.myGroups) { groups in
            guard let targetID = navManager.targetGroupID else { return }
            if let group = groups.first(where: { $0.id == targetID }) {
                 navigationPath = NavigationPath()
                 navigationPath.append(group)
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navManager.clearTarget()
                 }
            }
        }
    }
    
    var groupListView: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    // ✨ [New] 받은 초대 목록 섹션
                    if !invitationManager.receivedInvitations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("받은 초대")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                            
                            ForEach(invitationManager.receivedInvitations) { invitation in
                                InvitationRow(invitation: invitation, invitationManager: invitationManager, studyManager: studyManager)
                            }
                        }
                        .padding()
                    }
                    
                    // 내 스터디 그룹 목록
                    if studyManager.myGroups.isEmpty {
                         // 초대가 있을 때는 빈 화면 문구를 조금 다르게 보여주거나, 초대만 보여줘도 됨.
                         // 여기서는 그룹이 없고 초대도 없을 때만 EmptyState를 보여주는게 자연스라울듯 하다만,
                         // 일단 studyManager.myGroups isEmpty 기준으로 처리하고, 초대가 있으면 위에 뜨게 둠.
                         // 만약 초대가 있는데 그룹이 없으면? -> 초대 목록 + EmptyView(그룹없음) 뜸. 괜찮음.
                         if invitationManager.receivedInvitations.isEmpty {
                             emptyStateView
                                 .padding(.top, 50)
                         }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("내 스터디")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                            
                            ForEach(studyManager.myGroups) { group in
                                NavigationLink(value: group) {
                                    StudyGroupRow(group: group, studyManager: studyManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
                .padding(.bottom, 100) // FAB 공간 확보
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // ✨ [New] 전체 스터디 일정 FAB
                        NavigationLink(destination: GlobalScheduleView(
                            myGroupIDs: studyManager.myGroups.map { $0.id },
                            groupNameMap: Dictionary(uniqueKeysWithValues: studyManager.myGroups.map { ($0.id, $0.name) })
                        )) {
                            Image(systemName: "calendar")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.orange) // 구분되게 주황색 사용 혹은 메인 컬러 사용
                                .clipShape(Circle())
                                .shadow(radius: 4, y: 4)
                        }
                        
                        // 기존 스터디 만들기 FAB
                        Button(action: { showingCreateSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                                .clipShape(Circle())
                                .shadow(radius: 4, y: 4)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                studyManager.fetchMyGroups(uid: uid)
                
                // ✨ [New] 화면 진입 시 타겟 그룹이 있으면 이동 시도 (이미 로딩된 경우)
                if let targetID = navManager.targetGroupID,
                   let group = studyManager.myGroups.first(where: { $0.id == targetID }) {
                     print("🚀 [StudyGroupList] onAppear에서 타겟 그룹 발견, 이동 시도")
                     navigationPath = NavigationPath()
                     navigationPath.append(group)
                     
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navManager.clearTarget()
                     }
                }
            }
        }
        .onDisappear {
            // 뷰가 사라질 때 리스너 해제 여부는 앱 구조에 따라 결정.
            // 탭바 이동시 유지하고 싶으면 여기서 해제 안함.
        }

        .sheet(isPresented: $showingCreateSheet) {
            StudyGroupCreationView(studyManager: studyManager)
                .presentationDetents([.medium, .large])
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("아직 가입한 스터디가 없어요")
                .font(.title3.bold())
                .foregroundColor(.gray)
            
            Text("새로운 스터디를 만들고\n친구들을 초대해보세요!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .font(.caption)
            
            Button(action: { showingCreateSheet = true }) {
                Text("스터디 만들기")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .cornerRadius(20)
            }
        }
    }
}

// ✨ [New] 초대 행 UI Component
struct InvitationRow: View {
    let invitation: StudyInvitation
    @ObservedObject var invitationManager: InvitationManager
    @ObservedObject var studyManager: StudyGroupManager
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                
                Text("스터디 초대장")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(timeString(from: invitation.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text("\(invitation.inviterName)님이 '\(invitation.groupName)' 스터디에 초대했어요!")
                .font(.body.bold())
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 10) {
                Button(action: {
                    isProcessing = true
                    invitationManager.declineInvitation(invitation)
                }) {
                    Text("거절")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    invitationManager.acceptInvitation(invitation, studyManager: studyManager) { success in
                        isProcessing = false
                        // 성공 시 리스트에서 자동 사라짐 (Firestore 리스너가 업데이트 해줌)
                    }
                }) {
                    Text("수락")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    func timeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StudyGroupRow: View {
    let group: StudyGroup
    // ✨ [New] 읽지 않은 알림 확인용
    @ObservedObject var studyManager: StudyGroupManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // ✨ [New] 업데이트 알림 (빨간 점)
                if studyManager.hasUnreadUpdates(group: group) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(group.memberCount)/\(group.maxMembers)")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
