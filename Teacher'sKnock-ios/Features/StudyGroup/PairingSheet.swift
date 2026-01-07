import SwiftUI
import FirebaseAuth

struct PairingSheet: View {
    @Environment(\.dismiss) var dismiss
    // Testing을 위해 @State로 변경 -> Revert
    let group: StudyGroup
    let isLeader: Bool // 방장 여부
    @ObservedObject var studyManager: StudyGroupManager
    
    // 매칭 결과 (ID 배열의 배열 -> PairTeam 배열)
    // view load 시 group.pairs에서 가져오거나, 새로 생성된 결과
    @State private var currentPairs: [StudyGroup.PairTeam] = []
    
    // 매칭 상태
    @State private var hasMatchedToday = false
    @State private var selectedSplitType: StudyGroupManager.PairSplitType = .twoTwoTwo // 기본값
    
    // ✨ [New] 애니메이션 상태
    @State private var isAnimating = false
    
    // UI
    @State private var showingSplitSelection = false // 6명일 때 분기 선택
    
    var body: some View {
        NavigationStack {
            ZStack { // ✨ [New] 애니메이션 오버레이를 위해 ZStack 추가
                VStack {
                    if hasMatchedToday && !currentPairs.isEmpty {
                        // MARK: - 매칭 결과 표시
                        ScrollView {
                            VStack(spacing: 20) {
                                Text(dateString(for: group.lastPairingDate ?? Date()))
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.top)
                                
                                Text("오늘의 짝 스터디 그룹을 확인하세요!")
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                
                                // 결과 리스트 (애니메이션 적용)
                                ForEach(0..<currentPairs.count, id: \.self) { index in
                                    let team = currentPairs[index]
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Image(systemName: "person.2.fill")
                                                .foregroundColor(.blue)
                                            Text("Group \(index + 1)")
                                                .font(.headline)
                                        }
                                        
                                        // 멤버 표시
                                        HStack(spacing: 15) {
                                            ForEach(team.memberIDs, id: \.self) { uid in
                                                if let user = studyManager.groupMembersData[group.id]?.first(where: { $0.id == uid }) {
                                                    VStack {
                                                        ProfileImageView(user: user, size: 50)
                                                        Text(user.nickname)
                                                            .font(.caption)
                                                            .lineLimit(1)
                                                    }
                                                } else {
                                                    // 로딩 안된 경우 (그럴 일은 드물지만)
                                                    VStack {
                                                        Circle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 50, height: 50)
                                                        Text("로딩중")
                                                            .font(.caption)
                                                    }
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                    // ✨ [New] 결과 카드 등장 애니메이션 (순차적)
                                    .opacity(isAnimating ? 0 : 1)
                                    .offset(y: isAnimating ? 20 : 0)
                                    .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.2), value: isAnimating)
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    } else {
                        // MARK: - 매칭 전 (방장만 가능)
                        VStack(spacing: 30) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.top, 50)
                            
                            Text("오늘의 짝 스터디 매칭")
                                .font(.title.bold())
                            
                            Text("랜덤으로 스터디 짝을 지어드려요.\n스터디 시작 전, 오늘의 파트너를 확인해보세요!")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // ✨ [Updated] 2명일 경우 분기 처리
                            if group.memberCount <= 2 {
                                Text("짝 매칭이 필요하지 않습니다.")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.bottom, 20)
                                
                            } else if isLeader {
                                Button(action: {
                                    if group.memberCount == 6 {
                                        showingSplitSelection = true
                                    } else {
                                        startMatching(splitType: .standard)
                                    }
                                }) {
                                    Text("지금 매칭하기")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(14)
                                }
                                .padding(.horizontal)
                                
                                Text("매칭은 하루에 한 번만 가능하며, 결과는 모든 멤버에게 공유됩니다.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 20)
                            } else {
                                Text("아직 방장님이 오늘의 매칭을 진행하지 않았습니다.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                } // End of VStack
                
                // ✨ [New] 애니메이션 오버레이
                if isAnimating {
                    MatchingAnimationView(
                        members: group.members,
                        studyManager: studyManager,
                        groupID: group.id
                    ) {
                        // 애니메이션 종료 시
                        withAnimation {
                            isAnimating = false
                            // 본 것으로 처리
                            markAsSeen()
                        }
                    }
                    .zIndex(1) // 맨 위에 표시
                }
            } // End of ZStack
            .navigationTitle("짝 스터디")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkTodayMatching()
            }
            // 6명일 때 선택 시트
            .confirmationDialog("팀 구성 방식을 선택해주세요", isPresented: $showingSplitSelection, titleVisibility: .visible) {
                Button("2명 / 2명 / 2명") {
                    startMatching(splitType: .twoTwoTwo)
                }
                Button("3명 / 3명") {
                    startMatching(splitType: .threeThree)
                }
                Button("취소", role: .cancel) {}
            }
            
            
        }
    }
    
    // MARK: - Logic
    
    // MARK: - Logic
    
    // ✨ [New] 매칭 결과 확인 키 생성
    private func getSeenKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateKey = formatter.string(from: date)
        return "hasSeenPairing_\(group.id)_\(dateKey)"
    }
    
    func checkTodayMatching() {
        if let lastDate = group.lastPairingDate, Calendar.current.isDateInToday(lastDate), let pairs = group.pairs {
            
            // ✨ [Validation] 유효성 검사: 현재 멤버 리스트에 없는 '더미' 유저가 포함되어 있는지 확인
            // (테스트 시뮬레이션 데이터가 남아있는 경우를 방지)
            let allPairedIDs = pairs.flatMap { $0.memberIDs }
            let currentMemberIDs = Set(group.members)
            let isValid = allPairedIDs.allSatisfy { currentMemberIDs.contains($0) }
            
            if isValid {
                self.hasMatchedToday = true
                self.currentPairs = pairs
                
                // 아직 안 봤으면 애니메이션 시작
                let key = getSeenKey(date: lastDate)
                if !UserDefaults.standard.bool(forKey: key) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isAnimating = true
                    }
                }
            } else {
                // 유효하지 않은 데이터(테스트 잔재)라면 무시 -> 매칭 전 상태로 표시
                print("⚠️ Invalid pairing data detected (likely verification leftovers). Ignoring.")
                self.hasMatchedToday = false
                self.currentPairs = []
            }
        } else {
            self.hasMatchedToday = false
            self.currentPairs = []
        }
    }
    
    func markAsSeen() {
        // 현재 날짜(마지막 매칭 날짜) 기준으로 봤다고 표시
        if let lastDate = group.lastPairingDate {
            let key = getSeenKey(date: lastDate)
            UserDefaults.standard.set(true, forKey: key)
        }
    }
    
    func startMatching(splitType: StudyGroupManager.PairSplitType) {
        let members = group.members
        // 1. 매칭 생성
        let newPairs = studyManager.generatePairs(members: members, splitType: splitType)
        
        // 2. 서버 업데이트 (공지사항도 함께 업데이트하여 알림 발송)
        studyManager.updatePairs(groupID: group.id, currentNotice: group.notice ?? "", pairs: newPairs) { success in
            if success {
                self.hasMatchedToday = true
                self.currentPairs = newPairs
                
                // 방장은 직접 눌렀으니 무조건 애니메이션
                self.isAnimating = true
                
                // ✨ [New] 일정 자동 등록
                let nickname = UserDefaults.standard.string(forKey: "userNickname") ?? Auth.auth().currentUser?.displayName ?? "알 수 없음"
                let schedule = GroupSchedule(
                    groupID: self.group.id,
                    title: "짝 스터디 매칭 완료",
                    content: "오늘의 짝 스터디가 매칭되었습니다. 파트너와 함께 공부를 시작해보세요!",
                    date: Date(),
                    type: .pairing,
                    authorID: Auth.auth().currentUser?.uid ?? "",
                    authorName: nickname
                )
                GroupScheduleManager().addSchedule(schedule: schedule) { _ in }
            }
        }
    }
    
    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}
    
    
    
    
    
    // ✨ [New] 매칭 애니메이션 뷰 (Sophisticated Orbital Mixing)
    struct MatchingAnimationView: View {
        let members: [String]
        @ObservedObject var studyManager: StudyGroupManager
        let groupID: String
        let onFinished: () -> Void
        
        // 표시할 멤버 목록
        @State private var displayedUsers: [User] = []
        
        // 애니메이션 상태
        @State private var isAnimating = false
        @State private var flashOpacity: Double = 0.0
        
        var body: some View {
            ZStack {
                // 1. 고급스러운 블러 배경 (Glassmorphism)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("운명의 짝을 찾는 중...")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.bottom, 50)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: isAnimating)
                }
                
                // 2. 유기적 궤도 믹싱
                ZStack {
                    ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { index, user in
                        OrbitalProfileView(user: user, index: index, total: displayedUsers.count, isAnimating: isAnimating)
                    }
                }
                .frame(width: 300, height: 300)
                
                // 3. 피날레 플래시 효과
                Color.white
                    .ignoresSafeArea()
                    .opacity(flashOpacity)
            }
            .onAppear {
                initializeMembers()
                // 햅틱 준비
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                
                // 애니메이션 시작
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        isAnimating = true
                    }
                    generator.impactOccurred()
                }
                
                // 종료 시퀀스 (3초 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    finishSequence()
                }
            }
        }
        
        func initializeMembers() {
            if let data = studyManager.groupMembersData[groupID] {
                displayedUsers = data
            }
        }
        
        func finishSequence() {
            // 강한 햅틱
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 플래시 효과
            withAnimation(.easeOut(duration: 0.2)) {
                flashOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onFinished()
            }
        }
    }
    
    // 개별 프로필의 궤도 운동 뷰
    struct OrbitalProfileView: View {
        let user: User
        let index: Int
        let total: Int
        let isAnimating: Bool
        
        // 각자 다른 랜덤 궤도 속성
        @State private var randomPhaseX: Double = Double.random(in: 0...2 * .pi)
        @State private var randomPhaseY: Double = Double.random(in: 0...2 * .pi)
        @State private var randomSpeed: Double = Double.random(in: 0.8...1.5)
        
        // 움직임 상태
        @State private var progress: Double = 0.0
        
        var body: some View {
            ProfileImageView(user: user, size: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .white.opacity(0.3), radius: 10)
            // 3D 깊이감 (크기 변화)
                .scaleEffect(scaleValue)
            // 위치 이동 (Lissajous curve 느낌의 유기적 움직임)
                .offset(x: xOffset, y: yOffset)
                .opacity(isAnimating ? 1 : 0)
                .onAppear {
                    if isAnimating { startOrbit() }
                }
                .onChange(of: isAnimating) { animating in
                    if animating { startOrbit() }
                }
        }
        
        var xOffset: CGFloat {
            // 복잡한 삼각함수 조합으로 예측 불가능한 궤도 생성
            let baseRadius: Double = 100
            return CGFloat(cos(progress * randomSpeed + randomPhaseX) * baseRadius)
        }
        
        var yOffset: CGFloat {
            let baseRadius: Double = 100
            return CGFloat(sin(progress * randomSpeed * 1.3 + randomPhaseY) * baseRadius)
        }
        
        var scaleValue: CGFloat {
            // Y축 위치(깊이)에 따라 크기 조절 (앞에 있으면 크고, 뒤에 있으면 작게)
            let depth = sin(progress * randomSpeed * 1.3 + randomPhaseY) // -1 ~ 1
            return CGFloat(1.0 + depth * 0.2) // 0.8 ~ 1.2
        }
        
        func startOrbit() {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                progress = 20 * .pi // 충분히 긴 시간동안 회전
            }
        }
    }
    
    // 안전한 배열 접근을 위한 익스텐션 (이미 프로젝트에 있을 수 있지만 확인 불가하므로 로컬 정의)
    fileprivate extension Array {
        subscript(safe index: Int) -> Element? {
            return indices.contains(index) ? self[index] : nil
        }
    }

