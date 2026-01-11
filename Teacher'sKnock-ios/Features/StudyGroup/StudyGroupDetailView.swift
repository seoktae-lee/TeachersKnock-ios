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
    
    // ✨ [New] 네비게이션 매니저 (자동 이동용)
    @EnvironmentObject var navManager: StudyNavigationManager
    
    @State private var showingInviteSheet = false
    @State private var showDeleteConfirmAlert = false
    @State private var showDeletedNoticeAlert = false
    // ✨ [New] 공지사항 수정용 -> NoticeSheet로 이동하여 삭제
    // ✨ [New] 공지사항 접기/펼치기 -> 삭제
    @State private var showNoticeSheet = false
    @State private var showCheerSheet = false
    @State private var showPairingSheet = false // ✨ [New] 짝 스터디 시트
    @State private var showTimerAlert = false // ✨ [New] 타이머 준비중 알림 (사용 안함, 하위 호환 위해 남겨둠)
    @State private var showConcurrentTimerAlert = false // ✨ [New] 중복 참여 방지 알림
    @State private var showCommonTimerSetup = false // ✨ [New] 공통 타이머 설정
    @State private var showCommonTimer = false // ✨ [New] 공통 타이머 화면
    
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
        applyModallyPresentedViews(to:
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    // Participation (Attendance)
                    if let membersData = studyManager.groupMembersData[liveGroup.id] {
                        ParticipationView(members: membersData)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    rankingSection
                    
                    memberListSection
                    
                    footerSection
                }
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("스터디 상세")
            .navigationBarTitleDisplayMode(.inline)
        )
        .toolbar {
            // 기존 아이콘 영역 삭제 (헤더로 이동)
        }
        .onAppear {
            observeGroupUpdates()
            // ✨ [New] 멤버 정보 실시간 구독
            studyManager.fetchGroupMembers(groupID: liveGroup.id, memberUIDs: liveGroup.members)
            
            // ✨ [New] 공통 타이머 참여자 감지 (알림용)
            studyManager.monitorCommonTimerParticipants(groupID: liveGroup.id)
            
            // ✨ [New] 시스템 알림 정리 및 읽음 처리
            studyManager.cleanupSystemNotice(groupID: liveGroup.id, notice: liveGroup.notice)
            
            // ✨ [New] 플래너에서 넘어온 경우 자동 처리
            if navManager.targetGroupID == liveGroup.id {
                // 타겟 클리어 (재진입 시 중복 트리거 방지)
                // 주의: 여기서 지우면 아래 로직 실행 전에 지워질 수 있으니 로직 실행 후 지움
                
                // 리더/멤버 구분 없이 공통 로직 적용 (최초 입장자 설정 권한)
                if let timer = liveGroup.commonTimer, timer.isActive, Date() < timer.endTime {
                    showCommonTimer = true
                } else {
                    showCommonTimerSetup = true
                }
                
                // 처리 완료 후 타겟 초기화 (약간의 딜레이를 주어 뷰 상태 반영 보장 권장)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if navManager.targetGroupID == liveGroup.id { // 여전히 같으면 클리어
                        navManager.clearTarget()
                    }
                }
            }
        }
        .onDisappear {
            studyManager.stopMonitoringParticipants()
        }
    }
    
    // 공지사항 업데이트 -> NoticeSheet로 이동하여 삭제
    // func updateNotice() ...
    
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

// MARK: - Subviews
extension StudyGroupDetailView {
    
    private var headerSection: some View {
        HStack(alignment: .top) {
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
            
            Spacer()
            
            // ✨ [Moved] 네비게이션 바 클리핑 방지를 위해 헤더 영역으로 이동
            VStack(spacing: 8) { // 2행 (간격 조금 넓힘)
                HStack(spacing: 8) { // 1행: 공지, 일정
                    Button(action: { showNoticeSheet = true }) {
                        headerIconButton(icon: "megaphone.fill", color: .orange, hasBadge: studyManager.hasUnreadNotice(group: liveGroup))
                    }
                    
                    NavigationLink(destination: GroupScheduleView(
                        groupID: liveGroup.id,
                        groupName: liveGroup.name,
                        isLeader: isLeader
                    )) {
                        headerIconButton(icon: "calendar", color: .blue, hasBadge: false)
                    }
                }
                
                HStack(spacing: 8) { // 2행: 짝, 타이머
                    Button(action: { showPairingSheet = true }) {
                        headerIconButton(icon: "arrow.triangle.2.circlepath", color: .green, hasBadge: false)
                    }
                    
                    Button(action: {
                        // ✨ [New] 중복 참여 방지
                        if studyManager.hasActiveTimerInOtherGroups(excluding: liveGroup.id) {
                            showConcurrentTimerAlert = true
                            return
                        }
                        
                        // ✨ [Updated] 누구나 타이머가 없으면 설정 가능 (최초 입장자)
                        if let timer = liveGroup.commonTimer, timer.isActive, Date() < timer.endTime {
                             showCommonTimer = true
                        } else {
                             showCommonTimerSetup = true
                        }
                    }) {
                        let isActive = (liveGroup.commonTimer?.isActive ?? false) && (Date() < (liveGroup.commonTimer?.endTime ?? Date()))
                        headerIconButton(icon: "stopwatch", color: isActive ? .red : .purple, hasBadge: isActive)
                    }
                }
            }
        }
        .padding()
    }
    
    private var rankingSection: some View {
        Group {
            if let membersData = studyManager.groupMembersData[liveGroup.id] {
                WeeklyRankingView(members: membersData)
                    .padding(.horizontal)
                Divider()
            }
        }
    }
    
    private var memberListSection: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 10)
            
            // Member List
            VStack(spacing: 0) {
                if let membersData = studyManager.groupMembersData[liveGroup.id] {
                    ForEach(sortMembers(members: membersData)) { user in
                        MemberRow(
                            user: user,
                            isLeader: user.id == liveGroup.leaderID,
                            isViewerLeader: isLeader,
                            groupID: liveGroup.id,
                            groupName: liveGroup.name, // ✨ [New] 그룹 이름 전달
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
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var footerSection: some View {
        Group {
            if isLeader {
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
    }
    
    // ✨ [New] 헤더 아이콘 버튼 스타일 (둥근 사각형)
    private func headerIconButton(icon: String, color: Color, hasBadge: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold)) // 아이콘 크기 조정
                .foregroundColor(color)
                .frame(width: 34, height: 34) // 터치 영역 및 배경 크기
                .background(color.opacity(0.1)) // 연한 배경색
                .cornerRadius(8) // 둥근 사각형 (Rounded Square)
            
            if hasBadge {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
            }
        }
    }
    
    // ✨ [New] 시트 및 알림 모디파이어 분리 (컴파일러 과부하 방지)
    @ViewBuilder
    func applyModallyPresentedViews<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $showingInviteSheet) {
                 MemberInviteView(studyManager: studyManager, group: liveGroup)
                    .presentationDetents([.medium, .large])
            }
            .alert("스터디 삭제", isPresented: $showDeleteConfirmAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("정말 스터디를 삭제하시겠습니까?\n모든 멤버가 탈퇴 처리되며, 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("스터디 종료", isPresented: $showDeletedNoticeAlert) {
                Button("확인") {
                    dismiss() // 확인 누르면 목록으로
                }
            } message: {
                Text("방장에 의해 스터디 그룹이 삭제되었습니다.")
            }
            .sheet(isPresented: $showNoticeSheet) {
                NoticeSheet(group: $liveGroup, isLeader: isLeader, studyManager: studyManager)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCheerSheet) {
                NavigationStack {
                    CheerBoardView(groupID: liveGroup.id, studyManager: studyManager)
                        .navigationTitle("한줄 응원")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("닫기") {
                                    showCheerSheet = false
                                }
                                .foregroundColor(.primary)
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .onAppear {
                    studyManager.markCheersAsRead(groupID: liveGroup.id)
                }
            }
            .sheet(isPresented: $showPairingSheet) {
                PairingSheet(group: liveGroup, isLeader: isLeader, studyManager: studyManager)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCommonTimerSetup) {
                // ✨ [New] 데이터 주입
                CommonTimerSetupView(
                    studyManager: studyManager, 
                    group: liveGroup, 
                    showCommonTimer: $showCommonTimer,
                    initialSubject: navManager.targetSubject,
                    initialPurpose: navManager.targetPurpose != nil ? StudyPurpose(rawValue: navManager.targetPurpose!) : nil
                )
            }
            .fullScreenCover(isPresented: $showCommonTimer) { // 타이머는 몰입을 위해 풀스크린 추천
                CommonTimerView(studyManager: studyManager, group: liveGroup)
            }
            .alert("입장 불가", isPresented: $showConcurrentTimerAlert) {
                Button("확인") {}
            } message: {
                Text("다른 스터디 그룹에서 이미 공유 타이머가 실행 중입니다.\n동시에 두 개의 타이머에 참여할 수 없습니다.")
            }
            .alert("준비 중", isPresented: $showTimerAlert) {
                Button("확인") {}
            } message: {
                Text("공통 타이머 기능은 추후 업데이트 예정입니다.")
            }
    }
}

// ✨ [New] 주간 랭킹 뷰
struct WeeklyRankingView: View {
    let members: [User]
    
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    struct RankedMember: Identifiable {
        let id: String
        let user: User
        let weeklySeconds: Int
        let rank: Int
    }
    
    private func calculateWeeklyTime(user: User) -> Int {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        // 이번 주 시작일 계산
        let today = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)
        let startOfWeek = weekInterval?.start ?? today
        
        // 1. 과거 기록 합산 (이번 주 내 기록만, 오늘 제외)
        let historicSum = user.dailyStudyRecords.filter { key, value in
            guard key != todayStr else { return false }
            if let date = dateFormatter.date(from: key) {
                return calendar.isDate(date, equalTo: startOfWeek, toGranularity: .weekOfYear)
            }
            return false
        }.reduce(0) { $0 + $1.value }
        
        // 2. 오늘 저장된 시간
        var total = historicSum + user.todayStudyTime
        
        // 3. 공부 중이라면 현재 세션 경과 시간 추가
        if user.isStudying, let startTime = user.currentStudyStartTime {
            let now = tick
            let isTodayStart = calendar.isDateInToday(startTime)
            
            if isTodayStart {
                let elapsed = Int(now.timeIntervalSince(startTime))
                total += max(0, elapsed)
            } else {
                if calendar.isDateInToday(now) {
                    let startOfToday = calendar.startOfDay(for: now)
                    let elapsedSinceMidnight = Int(now.timeIntervalSince(startOfToday))
                    total += max(0, elapsedSinceMidnight)
                }
            }
        }
        
        return total
    }
    
    var topMembers: [RankedMember] {
        let sorted = members.map { user in
            RankedMember(id: user.id, user: user, weeklySeconds: calculateWeeklyTime(user: user), rank: 0)
        }.sorted { $0.weeklySeconds > $1.weeklySeconds }
        
        var result: [RankedMember] = []
        for (index, item) in sorted.enumerated() {
            if index < 3 {
                result.append(RankedMember(id: item.id, user: item.user, weeklySeconds: item.weeklySeconds, rank: index + 1))
            }
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("이번 주 공부 랭킹 Top 3", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundColor(.yellow)
            
            if topMembers.isEmpty || topMembers.allSatisfy({ $0.weeklySeconds == 0 }) {
                Text("아직 이번 주 공부 기록이 없습니다.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)
            } else {
                // 랭킹 카드 영역
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(topMembers) { member in
                        VStack {
                            // 왕관 아이콘
                            if member.rank == 1 {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                    .scaleEffect(member.user.isStudying ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: member.user.isStudying)
                            }
                            
                            // 프로필
                            ProfileImageView(user: member.user, size: member.rank == 1 ? 60 : 45)
                                .overlay(
                                    Circle()
                                        .stroke(member.rank == 1 ? Color.yellow : Color.clear, lineWidth: 2)
                                )
                            
                            // 공부 중 표시
                            if member.user.isStudying {
                                Text("🔥")
                                    .font(.caption2)
                                    .offset(y: -5)
                            }
                            
                            Text(member.user.nickname)
                                .font(.caption.bold())
                                .lineLimit(1)
                            
                            Text(formatTime(member.weeklySeconds))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.yellow.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                .animation(.default, value: topMembers.map { $0.id })
                
                // 내 순위 표시
                if let myRank = calculateMyRank() {
                    HStack {
                        Spacer()
                        Text("회원님의 현재 순위는 ")
                            .foregroundColor(.secondary)
                        + Text("\(myRank)등")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        + Text("입니다! 🔥")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.top, 5)
                }
            }
        }
        .padding(.vertical, 5)
        .onReceive(timer) { t in
            self.tick = t
        }
    }
    
    func calculateMyRank() -> Int? {
        guard let myID = Auth.auth().currentUser?.uid else { return nil }
        
        let sorted = members.map { user in
            RankedMember(id: user.id, user: user, weeklySeconds: calculateWeeklyTime(user: user), rank: 0)
        }.sorted { $0.weeklySeconds > $1.weeklySeconds }
        
        if let index = sorted.firstIndex(where: { $0.id == myID }) {
            return index + 1
        }
        return nil
    }
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%d시간 %02d분 %02d초", h, m, s)
    }
}

struct MemberRow: View {
    let user: User
    let isLeader: Bool
    let isViewerLeader: Bool
    let groupID: String
    let groupName: String // ✨ [New]
    @ObservedObject var studyManager: StudyGroupManager
    
    @State private var showDelegateAlert = false
    @State private var showKnockAlert = false
    @State private var knockMessage = ""
    @State private var currentDisplayTime: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
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
            .onTapGesture {
                tryKnock()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.nickname)
                        .font(.body.bold())
                    if isLeader {
                        Image(systemName: "star.circle.fill")
                        .foregroundColor(.orange)
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
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(user.isStudying ? .blue : .gray)
            }
        }
        .padding()
        .background(user.id == Auth.auth().currentUser?.uid ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(10)
        .contextMenu {
            Button {
                tryKnock()
            } label: {
                Label("노크하기", systemImage: "hand.wave.fill")
            }
            
            if isViewerLeader && !isLeader {
                Button(role: .destructive) {
                    showDelegateAlert = true
                } label: {
                    Label("방장 위임하기", systemImage: "star.circle")
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
        .alert(knockMessage, isPresented: $showKnockAlert) {
            Button("확인") { }
        }
        .onAppear {
            updateTime()
        }
        .onReceive(timer) { _ in
            if user.isStudying {
                updateTime()
            }
        }
        .onChange(of: user.id) { _ in updateTime() }
        .onChange(of: user.isStudying) { _ in updateTime() }
        .onChange(of: user.todayStudyTime) { _ in updateTime() }
        .onChange(of: user.lastStudyDate) { _ in updateTime() }
    }
    
    func tryKnock() {
        guard user.id != Auth.auth().currentUser?.uid else { return }
        
        let key = "lastKnock_\(user.id)"
        let lastKnock = UserDefaults.standard.double(forKey: key)
        let now = Date().timeIntervalSince1970
        
        if now - lastKnock < 3600 {
            let remaining = 3600 - (now - lastKnock)
            let m = Int(remaining / 60)
            knockMessage = "이미 노크를 보냈습니다.\n\(m)분 뒤에 다시 보낼 수 있어요."
            showKnockAlert = true
            return
        }
        
        var myNickname = UserDefaults.standard.string(forKey: "userNickname") ?? Auth.auth().currentUser?.displayName ?? "스터디원"
        
        if let members = studyManager.groupMembersData[groupID],
           let me = members.first(where: { $0.id == Auth.auth().currentUser?.uid }) {
            myNickname = me.nickname
        }
        
        studyManager.sendKnock(fromNickname: myNickname, to: user.id, toNickname: user.nickname) { success in
            if success {
                UserDefaults.standard.set(now, forKey: key)
                knockMessage = "\(user.nickname)님을 노크했습니다!!"
                showKnockAlert = true
            } else {
                knockMessage = "노크 전송에 실패했습니다."
                showKnockAlert = true
            }
        }
    }
    
    func updateTime() {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(user.lastStudyDate)
        let baseTime = isToday ? user.todayStudyTime : 0
        
        if user.isStudying, let startTime = user.currentStudyStartTime {
            let now = Date()
            var addedTime = 0
            
            if isToday {
                let elapsed = Int(now.timeIntervalSince(startTime))
                addedTime = max(0, elapsed)
            } else {
                if calendar.isDateInToday(startTime) {
                    let elapsed = Int(now.timeIntervalSince(startTime))
                    addedTime = max(0, elapsed)
                } else {
                    let startOfToday = calendar.startOfDay(for: now)
                    let elapsedSinceMidnight = Int(now.timeIntervalSince(startOfToday))
                    addedTime = max(0, elapsedSinceMidnight)
                }
            }
            
            currentDisplayTime = baseTime + addedTime
        } else {
            currentDisplayTime = baseTime
        }
    }
    
    func delegateLeader() {
        var myNickname = UserDefaults.standard.string(forKey: "userNickname") ?? "전 방장"
        if let members = studyManager.groupMembersData[groupID],
           let me = members.first(where: { $0.id == Auth.auth().currentUser?.uid }) {
            myNickname = me.nickname
        }
        
        studyManager.delegateLeader(
            groupID: groupID,
            groupName: groupName,
            oldLeaderNickname: myNickname,
            newLeaderUID: user.id,
            newLeaderNickname: user.nickname
        ) { success in
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
