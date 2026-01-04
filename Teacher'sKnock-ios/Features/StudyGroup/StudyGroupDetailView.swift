import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct StudyGroupDetailView: View {
    // Initial static group data passed from the list
    let initialGroup: StudyGroup
    // ✨ [New] Real-time group data
    @State private var liveGroup: StudyGroup
    
    @ObservedObject var studyManager: StudyGroupManager
    // ✨ [New] 화면 닫기용
    @Environment(\.dismiss) var dismiss
    
    @State private var showingInviteSheet = false
    @State private var showDeleteConfirmAlert = false
    @State private var showDeletedNoticeAlert = false
    // ✨ [New] 공지사항 수정용
    @State private var showNoticeEditAlert = false
    @State private var noticeText = ""
    
    // Custom Init to initialize State
    init(group: StudyGroup, studyManager: StudyGroupManager) {
        self.initialGroup = group
        self._liveGroup = State(initialValue: group)
        self.studyManager = studyManager
    }
    
    // Check if current user is leader
    var isLeader: Bool {
        liveGroup.leaderID == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text(liveGroup.name)
                        .font(.largeTitle.bold())
                    
                    if !liveGroup.description.isEmpty {
                        Text(liveGroup.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                }
                .padding()
                
                // Notice Board
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("공지사항", systemImage: "megaphone.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                        if isLeader {
                            Button("수정") {
                                noticeText = liveGroup.notice // 불러오기
                                showNoticeEditAlert = true
                            }
                            .font(.caption)
                        }
                    }
                    
                    Text(liveGroup.notice.isEmpty ? "등록된 공지사항이 없습니다." : liveGroup.notice)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Members
                HStack {
                    Text("멤버")
                        .font(.headline)
                        .padding(.leading)
                    
                    Spacer()
                    
                    if isLeader {
                        Button(action: { showingInviteSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("초대")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(liveGroup.memberCount >= liveGroup.maxMembers ? Color.gray : Color.blue)
                            .clipShape(Capsule())
                        }
                        .disabled(liveGroup.memberCount >= liveGroup.maxMembers)
                    }
                    
                    Text("\(liveGroup.memberCount)/\(liveGroup.maxMembers)명")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.trailing)
                }
                
                VStack(spacing: 0) {
                VStack(spacing: 0) {
                    if let membersData = studyManager.groupMembersData[liveGroup.id] {
                        ForEach(sortMembers(members: membersData)) { user in
                            MemberRow(
                                user: user,
                                isLeader: user.id == liveGroup.leaderID,
                                isViewerLeader: isLeader,
                                groupID: liveGroup.id,
                                studyManager: studyManager
                            )
                            Divider()
                                .padding(.leading, 60)
                        }
                    } else {
                        // 로딩 중 or 데이터 없음 -> 기존 방식 fallback
                         ForEach(liveGroup.members, id: \.self) { memberID in
                             Text("멤버 정보 로딩 중...") 
                                .padding()
                                .onAppear {
                                    studyManager.fetchGroupMembers(groupID: liveGroup.id, memberUIDs: liveGroup.members)
                                }
                         }
                    }
                }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)
                
                if isLeader {
                    // ✨ [New] 그룹 삭제 버튼 (심플한 텍스트 버튼으로 변경)
                    HStack {
                        Spacer()
                        Button(action: {
                            showDeleteConfirmAlert = true
                        }) {
                            Text("스터디 그룹 삭제하기")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .underline()
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                } else {
                    Button(action: {
                        // Leave group logic
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
             MemberInviteView(studyManager: studyManager, group: liveGroup)
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
        // ✨ [New] 공지사항 수정 Alert
        .alert("공지사항 수정", isPresented: $showNoticeEditAlert) {
            TextField("공지 내용", text: $noticeText)
            Button("취소", role: .cancel) { }
            Button("저장") {
                updateNotice()
            }
        } message: {
            Text("새로운 공지사항을 입력해주세요.")
        }
        .onAppear {
            observeGroupUpdates()
            // ✨ [New] 멤버 정보 실시간 구독
            studyManager.fetchGroupMembers(groupID: liveGroup.id, memberUIDs: liveGroup.members)
        }
    }
    
    // 공지사항 업데이트
    func updateNotice() {
        studyManager.updateNotice(groupID: liveGroup.id, notice: noticeText)
        // 로컬 업데이트 (Optimistic update)
        var newGroup = liveGroup
        newGroup.notice = noticeText
        liveGroup = newGroup
    }
    
    // 그룹 삭제 (방장)
    func deleteGroup() {
        studyManager.deleteGroup(groupID: liveGroup.id) { success in
            if success {
                dismiss()
            }
        }
    }
    
    // ✨ [New] 실시간 업데이트 및 삭제 감지
    func observeGroupUpdates() {
        Firestore.firestore().collection("study_groups").document(liveGroup.id)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                
                if !snapshot.exists {
                    // 삭제됨
                     if !showDeleteConfirmAlert {
                         showDeletedNoticeAlert = true
                     }
                } else {
                    // 변경됨 (공지사항, 위임, 멤버 변경 등)
                    if let updatedGroup = StudyGroup(document: snapshot) {
                        self.liveGroup = updatedGroup
                        // 멤버 구성이 바뀐 경우 다시 fetch
                        // (단순 이름 변경은 위임X, 멤버 배열 변경 시)
                        // 여기서는 간단히 리스너 다시 연결 (StudyManager 내부에서 중복 처리 함)
                        studyManager.fetchGroupMembers(groupID: updatedGroup.id, memberUIDs: updatedGroup.members)
                    }
                }
            }
    }
    
    // Helper: 멤버 정렬
    func sortMembers(members: [User]) -> [User] {
        return members.sorted { (u1, u2) -> Bool in
            if u1.isStudying != u2.isStudying {
                return u1.isStudying && !u2.isStudying // 공부중 우선
            }
            if u1.todayStudyTime != u2.todayStudyTime {
                return u1.todayStudyTime > u2.todayStudyTime // 공부시간 내림차순
            }
            return u1.nickname < u2.nickname
        }
    }
}

struct MemberRow: View {
    let user: User // ✨ [New] User 객체를 직접 받음 (정렬된 데이터)
    let isLeader: Bool
    let isViewerLeader: Bool // 현재 보고 있는 사람이 리더인가?
    let groupID: String
    @ObservedObject var studyManager: StudyGroupManager
    
    @State private var showDelegateAlert = false
    @State private var currentDisplayTime: Int = 0
    // 1초마다 갱신을 위한 타이머
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                // ✨ [New] 공통 컴포넌트 사용 (프로필 이미지)
                ProfileImageView(user: user, size: 40)
                
                if user.isStudying {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .offset(x: 5, y: 5)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.nickname)
                        .font(.body.bold())
                    if isLeader {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                if let uni = user.university, !uni.isEmpty {
                    Text(uni)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // ✨ [Modified] 오른쪽 빈 공간에 공부 시간 및 상태 표시
            VStack(alignment: .trailing, spacing: 4) {
                if user.isStudying {
                    Text("🔥 공부 중")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(formatTime(currentDisplayTime))
                    .font(.system(.body, design: .monospaced)) // 숫자 등폭 폰트 사용
                    .fontWeight(.bold)
                    .foregroundColor(user.isStudying ? .blue : .gray)
                
                // ✨ [Modified] 말하기 시간 표시 제거 (순공시간에 합산됨)
            }
        }
        .padding()
        // ✨ [New] 내 자신은 배경색 살짝 다르게 표시 (선택사항)
        .background(user.id == Auth.auth().currentUser?.uid ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(10)
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
            Text("'\(user.nickname)' 님에게 방장 권한을 넘기시겠습니까?\n방장은 스터디 관리 권한을 갖으며, 이 작업은 되돌릴 수 없습니다.")
        }
        .onAppear {
            updateTime()
        }
        .onReceive(timer) { _ in
            if user.isStudying {
                updateTime()
            }
        }
        // 사용자가 변경될 때 시간 초기화 (재사용 row 문제 방지)
        .onChange(of: user.id) { _ in updateTime() }
        .onChange(of: user.isStudying) { _ in updateTime() }
        .onChange(of: user.todayStudyTime) { _ in updateTime() }
    }
    
    func updateTime() {
        if user.isStudying, let startTime = user.currentStudyStartTime {
            let elapsed = Int(Date().timeIntervalSince(startTime))
            // 음수 방지 (시간 동기화 오차 등)
            let addedTime = max(0, elapsed)
            currentDisplayTime = user.todayStudyTime + addedTime
        } else {
            currentDisplayTime = user.todayStudyTime
        }
    }
    
    func delegateLeader() {
        studyManager.delegateLeader(groupID: groupID, newLeaderUID: user.id) { success in
            if success {
                print("방장 위임 성공")
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
