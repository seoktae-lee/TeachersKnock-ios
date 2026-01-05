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
                
                // ✨ [New] Weekly Ranking
                if let membersData = studyManager.groupMembersData[liveGroup.id] {
                    WeeklyRankingView(members: membersData)
                        .padding(.horizontal)
                    Divider()
                }
                
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

// ✨ [New] 주간 랭킹 뷰
struct WeeklyRankingView: View {
    let members: [User]
    
    // ✨ [New] 실시간 갱신을 위한 타이머 및 상태
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    struct RankedMember: Identifiable {
        let id: String
        let user: User
        let weeklySeconds: Int
        let rank: Int
    }
    
    // 로직 수정: 오늘 날짜 제외하고 합산 + 오늘 시간 + (공부중이라면) 현재 경과 시간
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
            guard key != todayStr else { return false } // 오늘은 제외 (중복 방지)
            if let date = dateFormatter.date(from: key) {
                return calendar.isDate(date, equalTo: startOfWeek, toGranularity: .weekOfYear)
            }
            return false
        }.reduce(0) { $0 + $1.value }
        
        // 2. 오늘 저장된 시간
        var total = historicSum + user.todayStudyTime
        
        // 3. ✨ [New] 공부 중이라면 현재 세션 경과 시간 추가
        if user.isStudying, let startTime = user.currentStudyStartTime {
            // 날짜가 바뀌었을 때 등을 고려해야 하지만, 
            // 단순화를 위해 현재 시각에서 시작 시간을 뺀 값을 더함.
            // (오늘자 todayStudyTime에는 아직 반영 안 된 시간이므로)
            
            // 단, 시작 시간이 어제인 경우? -> updateTime 로직과 유사하게 처리 필요
            // 여기서는 '오늘 00시 이후' 흐른 시간만 더하는 것이 정확함
            
            let now = tick // 타이머에 의해 갱신되는 현재 시간
            let isTodayStart = calendar.isDateInToday(startTime)
            
            if isTodayStart {
                let elapsed = Int(now.timeIntervalSince(startTime))
                total += max(0, elapsed)
            } else {
                // 어제 시작했으면 오늘 00시부터의 시간만
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
                .foregroundColor(.yellow) // 트로피 색상
            
            if topMembers.isEmpty || topMembers.allSatisfy({ $0.weeklySeconds == 0 }) {
                Text("아직 이번 주 공부 기록이 없습니다.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)
            } else {
                // ✨ [Modified] 1등이 가운데 오도록 하거나, 애니메이션 적용 가능 (여기선 리스트 순서 유지하되 값은 실시간)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(topMembers) { member in
                        VStack {
                            // 왕관 아이콘 (1등만)
                            if member.rank == 1 {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                    // ✨ [New] 1등 강조 애니메이션 (선택)
                                    .scaleEffect(member.user.isStudying ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: member.user.isStudying)
                            }
                            
                            // 프로필
                            ProfileImageView(user: member.user, size: member.rank == 1 ? 60 : 45)
                                .overlay(
                                    Circle()
                                        .stroke(member.rank == 1 ? Color.yellow : Color.clear, lineWidth: 2)
                                )
                            
                            // ✨ [New] 공부 중 표시
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
                                // ✨ [New] 숫자가 바뀔 때 살짝 깜빡이는 효과 (Monospaced라 덜 튐)
                                .contentTransition(.numericText()) 
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.05))
                .cornerRadius(12)
                .animation(.default, value: topMembers.map { $0.id }) // 순위 바뀌면 애니메이션
            }
        }
        .padding(.vertical, 5)
        .onReceive(timer) { t in
            self.tick = t // 시간 갱신 -> 뷰 리드로우 -> calculateWeeklyTime 재계산
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        // ✨ [Modified] 초 단위가 너무 정신없으면 분까지만, 하지만 "실시간" 요청이므로 초 필요 없어도 됨?
        // 사용자 요청: "생동감 있게" -> 초는 보여주는게 좋음. 랭킹용으로는 H:M만 있어도 되지만, 
        // 일단 H:M 형식 유지하되 값은 변함. (분이 바뀔때마다 갱신)
        // 만약 '초'단위 변화를 눈으로 보고 싶다면 포맷 변경 필요.
        // H:M 만 있으면 1분마다 바뀜 -> 덜 생동감.
        // H:M:S 로 변경 제안? 아니면 숫자만 내부적으론 변하고 UI는 분단위?
        // 사용자가 "생동감"을 원했으니 초 단위 추가가 나을 수 있음.
        let s = seconds % 60
        return String(format: "%d시간 %02d분 %02d초", h, m, s)
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
                        Image(systemName: "star.circle.fill") // ✨ [Modified] 방장 아이콘 변경 (왕관 -> 별)
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
                    Label("방장 위임하기", systemImage: "star.circle") // ✨ [Modified] 메뉴 아이콘도 일치
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
        .onChange(of: user.lastStudyDate) { _ in updateTime() } // ✨ [New] 날짜 변경 감지
    }
    
    func updateTime() {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(user.lastStudyDate)
        
        // 날짜가 지났으면 저장된 시간은 0으로 취급 (화면 표시용)
        let baseTime = isToday ? user.todayStudyTime : 0
        
        if user.isStudying, let startTime = user.currentStudyStartTime {
            // 현재 공부중인데 날짜가 바뀐 경우 처리:
            // (1) lastStudyDate가 오늘이면 -> 그냥 누적
            // (2) lastStudyDate가 어제면 -> 자정 넘어서 공부 중인 상황
            //     원칙적으로는 00시 기준으로 잘라야 하지만,
            //     간단히 '현재 날짜' 기준 경과 시간으로 처리하거나,
            //     FirestoreSyncManager의 로직에 따라 클라이언트에서는 단순 경과 시간만 더해줌.
            //     -> 여기서는 User 데이터가 아직 갱신 안 된 상태일 수 있으므로,
            //        startTime이 오늘 이전에 시작되었다면, 오늘 00:00부터의 시간만 보여주는게 맞음.
            //        그러나 복잡성을 줄이기 위해, "화면 갱신 시점" 기준으로 계산.
            
            // 만약 시작 시간이 어제고, 지금은 오늘이라면?
            // startTime ~ Now 전체가 아니라 Today 00:00 ~ Now 여야 함 (일일 공부시간이니까)
            // 하지만 User 모델의 todayStudyTime은 아직 리셋 안되었을 수도 있음 (서버 로직 의존).
            
            // 여기서 순수 클라이언트 로직:
            // "오늘 공부시간" = (오늘 저장된 시간) + (공부 중이라면 현재까지 추가 시간)
            // 만약 저장된 데이터(lastStudyDate)가 어제라면 -> 오늘 저장된 시간 = 0
            
            let now = Date()
            var addedTime = 0
            
            if isToday {
               // 같은 날 시작 -> 현재 - 시작
               let elapsed = Int(now.timeIntervalSince(startTime))
               addedTime = max(0, elapsed)
            } else {
               // 날짜가 다름 (어제 기록이거나, start가 어제)
               if calendar.isDateInToday(startTime) {
                   // 시작은 오늘인데 lastDate가 어제? (데이터 꼬임 or 00시 직후)
                   let elapsed = Int(now.timeIntervalSince(startTime))
                   addedTime = max(0, elapsed)
               } else {
                   // 시작도 어제, lastDate도 어제 -> 자정 넘어서 공부 중
                   // 오늘 00:00 부터 흐른 시간만 표시해야 함
                   let startOfToday = calendar.startOfDay(for: now)
                   let elapsedSinceMidnight = Int(now.timeIntervalSince(startOfToday))
                   addedTime = max(0, elapsedSinceMidnight)
               }
            }
            
            currentDisplayTime = baseTime + addedTime
        } else {
            // 공부 중 아님
            currentDisplayTime = baseTime
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
