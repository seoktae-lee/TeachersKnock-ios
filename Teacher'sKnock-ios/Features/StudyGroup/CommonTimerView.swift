import SwiftUI
import Combine
import FirebaseAuth
import SwiftData

struct CommonTimerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @ObservedObject var studyManager: StudyGroupManager
    let group: StudyGroup
    
    var state: StudyGroup.CommonTimerState? {
        group.commonTimer
    }
    
    @State private var currentTime = Date()
    @State private var remainingTime: TimeInterval = 0
    @State private var isFinished = false
    @State private var accumulatedTime: TimeInterval = 0 // ✨ [New] 누적 공부 시간
    @State private var lastTick: Date? // ✨ [New] 마지막 틱 시간
    
    // ✨ [New] Summary View State
    @State private var showSummary = false
    @State private var finalParticipants: [String] = [] // 요약 화면에 보여줄 참여자 목록
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Waiting Room State
    var isTimerRunning: Bool {
        guard let state = state else { return false }
        // ✨ [Updated] 정시 출발 로직: 멤버 참여 여부와 관계없이 시작 시간이 되면 무조건 실행
        return currentTime >= state.startTime
    }
    
    var isUserJoined: Bool {
        guard let state = state, let uid = Auth.auth().currentUser?.uid else { return false }
        return state.activeParticipants.contains(uid)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            if let state = state {
                VStack(spacing: 12) {
                    // ✨ [New] 상단 네비게이션 영역 (닫기 버튼)
                    // 공부 중일 때는 숨김 (종료하기 버튼 강제)
                    if !(isTimerRunning && isUserJoined) {
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 5)
                    } else {
                        // 공간 유지용 투명 뷰 or Spacer만
                        HStack { Spacer() }
                            .padding(.bottom, 5)
                    }
                    
                    // ✨ [New] 개설자 표시
                    if !state.creatorName.isEmpty {
                        Text("공유 타이머 개설자: \(state.creatorName)님")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text(state.goal)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 0) // 위쪽 간격 조정
                    
                    HStack(spacing: 8) {
                        Text(state.subject)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        
                        Text(StudyPurpose(rawValue: state.purpose)?.localizedName ?? state.purpose)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                    .font(.subheadline.bold())
                }
                .padding(.horizontal)
                
                Spacer()
                
                if isTimerRunning {
                    if isUserJoined {
                         // --- Case 1: Running & Joined (Studying) ---
                         RunningTimerView(currentTime: currentTime, startTime: state.startTime, endTime: state.endTime)
                         
                         Spacer()
                         
                         // Time Info
                         HStack {
                             VStack(alignment: .leading) {
                                 Text("시작")
                                     .font(.caption)
                                     .foregroundColor(.gray)
                                 Text(formatTime(state.startTime))
                                     .font(.headline)
                             }
                             Spacer()
                             VStack(alignment: .trailing) {
                                 Text("종료")
                                     .font(.caption)
                                     .foregroundColor(.gray)
                                 Text(formatTime(state.endTime))
                                     .font(.headline)
                             }
                         }
                         .padding(.horizontal, 40)
                         .padding(.bottom, 30)
                         
                         // Exit Button
                         Button(action: {
                             finishStudySession() // ✨ [New] 종료 및 저장 처리 -> Summary Show
                         }) {
                             Text("종료하기")
                                 .font(.headline)
                                 .foregroundColor(.white)
                                 .frame(maxWidth: .infinity)
                                 .padding()
                                 .background(Color.red)
                                 .cornerRadius(15)
                         }
                         .onAppear {
                             // ✨ [New] 타이머 시작 시 공부 상태 ON (지각생도 여기서 처리)
                             if let uid = Auth.auth().currentUser?.uid {
                                 FirestoreSyncManager.shared.updateUserStudyTime(uid: uid, isStudying: true)
                                 lastTick = Date()
                             }
                         }
                         .padding(.horizontal)
                         .padding(.bottom, 20)
                         
                    } else {
                        // --- Case 2: Running & Not Joined (Late Entry) ---
                        VStack(spacing: 20) {
                            Spacer()
                            
                            VStack(spacing: 12) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                                    .padding(.bottom, 10)
                                
                                Text("이미 스터디가 진행 중입니다! 🔥")
                                    .font(.title2.bold())
                                
                                Text("시작 시간: \(formatTime(state.startTime))")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                // 현재 참여중인 멤버 보여주기 (동기부여)
                                if !state.activeParticipants.isEmpty {
                                    Text("\(state.activeParticipants.count)명이 공부하고 있어요.")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.top, 5)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                studyManager.joinCommonTimer(groupID: group.id)
                            }) {
                                Text("지금 바로 참여하기")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                } else {
                    // --- Case 3: Waiting Room (Before Start) ---
                    // ✨ [Refactored] UI 균형 배치 (Top-Heavy 해소)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            if currentTime < state.startTime {
                                Text("시작 시간까지 대기 중...")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                // ✨ [New] 남은 시간 카운트다운 (크게 강조)
                                let diff = state.startTime.timeIntervalSince(currentTime)
                                if diff > 0 {
                                    Text("⏰ \(formatDuration(diff)) 남음")
                                        .font(.system(size: 32, weight: .bold)) // 폰트 키움
                                        .foregroundColor(.blue)
                                        .contentTransition(.numericText())
                                        .padding(.vertical, 10)
                                }
                            } else {
                                Text("곧 시작합니다...")
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        // Member Status Board (중앙 배치)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("참여 대기 멤버")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(state.activeParticipants.count) / \(state.targetMembers.count)명")
                                    .font(.subheadline.bold())
                            }
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 15) {
                                ForEach(state.targetMembers, id: \.self) { uid in
                                    MemberStatusCard(
                                        uid: uid,
                                        isJoined: state.activeParticipants.contains(uid),
                                        studyManager: studyManager,
                                        groupID: group.id
                                    )
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(15)
                        }
                        
                        Spacer()
                        Spacer() // 하단 여백 확보
                        
                        // Action Button (하단 고정)
                        if isUserJoined {
                            Button(action: {
                                studyManager.leaveCommonTimer(groupID: group.id)
                            }) {
                                Text("입장 취소")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(15)
                            }
                        } else {
                            Button(action: {
                                studyManager.joinCommonTimer(groupID: group.id)
                            }) {
                                Text("입장하기")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            } else {
                Text("타이머 정보를 불러올 수 없습니다.")
                    .onAppear { dismiss() }
            }
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
        .onAppear {
            studyManager.fetchGroupMembers(groupID: group.id, memberUIDs: group.members)
        }
        // ✨ [New] Summary Overlay
        .overlay {
            if showSummary, let state = state {
                summaryView(state: state)
            }
        }
    }
    
    // Member Status Card Component
    struct MemberStatusCard: View {
        let uid: String
        let isJoined: Bool
        @ObservedObject var studyManager: StudyGroupManager
        let groupID: String
        
        var nickname: String {
             studyManager.groupMembersData[groupID]?.first(where: { $0.id == uid })?.nickname ?? "알 수 없음"
        }
        
        var body: some View {
            VStack {
                ZStack {
                    Circle()
                        .fill(isJoined ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if isJoined {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(nickname)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
    
    // Analog Clock Component (Refined)
    struct RunningTimerView: View {
        var currentTime: Date
        var startTime: Date
        var endTime: Date
        
        var body: some View {
            ZStack {
                // Background Clock Face
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 20)
                
                // Active Pie Slice (Remaining duration relative to 1 hour or total duration?)
                // Analog clock usually represents 12 hours.
                // Let's visualize the session on the clock face.
                
                AnalogClockView(currentTime: currentTime, startTime: startTime, endTime: endTime)
                    .frame(maxWidth: 300, maxHeight: 300)
            }
            .padding()
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        return f.string(from: date)
    }
    
    // ✨ [New] 포맷팅 헬퍼
    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        if m > 60 {
             let h = m / 60
             let min = m % 60
             return "\(h)시간 \(min)분 전"
        }
        return String(format: "%02d분 %02d초", m, s)
    }
    
    func updateTimer() {
        // ✨ [New] 종료되었거나 요약 화면이 떠있으면 타이머 로직 중단 (시간 집계 정지)
        if isFinished || showSummary {
             lastTick = nil
             return
        }
        
        currentTime = Date()
        guard let state = state else { return }
        
        if isTimerRunning && isUserJoined {
            // ✨ [New] 공부 시간 누적 (종료 시간까지만 인정)
            if let last = lastTick {
                // 현재 시간이 종료 시간을 넘어가면, '종료 시간'까지만 공부한 것으로 계산
                let effectiveNow = min(currentTime, state.endTime)
                
                // 유효한 시간 차이가 있을 때만 누적 (백그라운드 복귀 등 고려)
                if effectiveNow > last {
                     let interval = effectiveNow.timeIntervalSince(last)
                     accumulatedTime += interval
                }
            }
             lastTick = currentTime
             
             // 종료 로직 체크
             if currentTime >= state.endTime {
                 // End
                 if !isFinished {
                     isFinished = true
                     // ✨ [New] 자동 종료 처리
                     finishStudySession(isAutoEnd: true)
                 }
             }
        } else {
            lastTick = nil // 대기 중 or 미참여 시간에는 리셋
        }
    }
    
    // ✨ [New] 공부 기록 저장 로직
    func finishStudySession(isAutoEnd: Bool = false) {
        guard let uid = Auth.auth().currentUser?.uid, let state = state else { return }
        
        // ✨ [New] 현재 참여자 캡쳐 (요약 화면용)
        finalParticipants = state.activeParticipants
        
        let duration = Int(accumulatedTime)
        
        // 1. & 2. 기록 저장 및 상태 업데이트
        if duration >= 10 {
            let record = StudyRecord(
                durationSeconds: duration,
                areaName: state.subject,
                date: Date(),
                ownerID: uid,
                studyPurpose: state.purpose,
                memo: state.goal,
                goal: nil
            )
            
            // 로컬 & 파이어스토어 저장
            // saveRecord 내부에서 updateUserStudyTime(isStudying: false)를 호출하여 시간 누적까지 처리함
            modelContext.insert(record)
            FirestoreSyncManager.shared.saveRecord(record)
            
            // 3. 경험치 지급
            CharacterManager.shared.addExpToEquippedCharacter()
            
            try? modelContext.save()
        } else {
            // 시간이 짧아서 기록 저장은 안 하지만, 공부 상태는 꺼야 함
            FirestoreSyncManager.shared.updateUserStudyTime(uid: uid, isStudying: false)
        }
        
        // ✨ [New] 총 누적 시간 및 이탈 횟수 계산
        calculateSessionStats(state: state, uid: uid, isAutoEnd: isAutoEnd)
    }
    
    // ✨ [New] 통계 계산 함수
    func calculateSessionStats(state: StudyGroup.CommonTimerState, uid: String, isAutoEnd: Bool) {
        // SwiftData Fetch Definition
        // 범위: 시작시간 ~ 종료시간 (약간의 오차 허용을 위해 앞뒤 버퍼를 둘 수도 있지만, 정확히 함)
        // 주의: record.date는 '저장 시점'임.
        let start = state.startTime
        // 종료 시간보다 조금 늦게 저장될 수 있으므로 현재시간(혹은 넉넉히)까지 포함
        let end = Date().addingTimeInterval(60)
        let subject = state.subject
        
        let descriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == uid &&
                record.areaName == subject &&
                record.date >= start &&
                record.date <= end
            }
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            
            // 1. 총 공부 시간 (이번 공유 타이머 세션 내)
            let totalSeconds = records.reduce(0) { $0 + $1.durationSeconds }
            self.accumulatedTime = TimeInterval(totalSeconds) // 요약 화면용 변수 업데이트
            
            // 2. 이탈 횟수
            // 기록의 개수가 곧 (이탈하거나 종료한) 횟수.
            // 자동 종료(isAutoEnd)인 경우, 마지막 기록은 '정상 종료'이므로 이탈이 아님 -> -1
            // 수동 종료(버튼 누름)인 경우, 사용자는 나가는 것이므로 이탈로 볼 수 있지만,
            // 요구사항: "총 몇번을 눌러 공유 타이머에서 이탈을 했는지"
            // 즉, 수동으로 [종료하기]를 누른 횟수 = 레코드 수.
            // 하지만 자동 종료된 마지막 순간은 [종료하기]를 누른게 아님.
            // 따라서 레코드 수 - (자동종료 ? 1 : 0) 이 정확함.
            // 단, 사용자가 마지막까지 있다가 자동종료되면 레코드 1개 (자동저장). 이탈 0. (1-1=0). 맞음.
            // 사용자가 중간에 1번 나가고(1개), 다시 들어와서 자동종료(1개). 총 2개. 이탈 1. (2-1=1). 맞음.
            // 사용자가 중간에 1번 나가고(1개), 다시 들어와서 수동 종료(1개). 총 2개. 이탈 2. (2-0=2). 맞음.
            
            var exitCount = records.count
            if isAutoEnd {
                exitCount = max(0, exitCount - 1)
            }
            
            // 요약 화면 표시를 위해 State 업데이트 필요 (여기서는 showSummary를 true로 하기 전에 변수를 쓸 곳이 마땅치 않음)
            // accumulatedTime은 이미 totalSeconds로 덮어썼고,
            // exitCount는 새로운 State 변수가 필요하거나, summaryView에 직접 전달.
            // 간단하게 State 하나 추가하거나, SummaryView 호출 시 전달.
            self.finalExitCount = exitCount
            
            print("✅ 세션 통계: 총 \(totalSeconds)초, 이탈 \(exitCount)회 (자동종료: \(isAutoEnd))")
            
        } catch {
            print("❌ 통계 계산 실패: \(error)")
        }
        
        showSummary = true
        
        // 자동 종료가 아닐때만 여기서 나가기 처리를 할지?
        // 아니면 요약 화면 닫을 때 나갈지?
        // 기획상: 요약 화면 보고 -> 닫기 누르면 나감.
        // 따라서 여기서는 UI만 띄움.
    }
    
    // ✨ [New] State for Exit Count
    @State private var finalExitCount: Int = 0
    
    // ✨ [New] Summary View Component
    func summaryView(state: StudyGroup.CommonTimerState) -> some View {
        ZStack {
            Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("공유 타이머 종료!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    // ✨ [Updated] 보여줄 값: 총 공부 시간 (계산된 값)
                    summaryRow(icon: "clock", title: "총 공부 시간", value: formatDuration(accumulatedTime))
                    summaryRow(icon: "book", title: "과목", value: state.subject)
                    
                    // ✨ [New] 이탈 횟수 표시
                    if finalExitCount > 0 {
                         summaryRow(icon: "figure.walk", title: "이탈 횟수", value: "\(finalExitCount)회")
                    }
                    
                    summaryRow(icon: "target", title: "목적", value: StudyPurpose(rawValue: state.purpose)?.localizedName ?? state.purpose)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                
                // 참여 멤버 표시
                VStack(alignment: .leading, spacing: 10) {
                    Text("함께한 멤버")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(finalParticipants, id: \.self) { uid in
                                MemberStatusCard(uid: uid, isJoined: true, studyManager: studyManager, groupID: group.id)
                                    .foregroundColor(.white) // 텍스트 컬러 조정
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    dismiss()
                    studyManager.leaveCommonTimer(groupID: group.id) // 닫기 누르면 퇴장 처리
                }) {
                    Text("확인")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                }
            }
            .padding(30)
        }
    }
    
    func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            // ✨ [Updated] 이탈 횟수 강조
            if title == "이탈 횟수" {
                Text(value)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            } else {
                Text(value)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}

// Reusing AnalogClockView from previous code, but refined
// Analog Clock Component (Refined)
struct AnalogClockView: View {
    var currentTime: Date
    var startTime: Date
    var endTime: Date
    
    // Timer Logic
    // We assume the timer is for a 12-hour period on the clock face
    
    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // 1. Clock Face Background
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color(UIColor.secondarySystemBackground)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // ✨ [Updated] Glow Effect Logic
                    .shadow(color: glowColor.opacity(0.6), radius: glowRadius, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowColor)
                
                // 2. Markers & Numbers
                ForEach(0..<60) { i in
                    let is5Min = i % 5 == 0
                    let angle = Angle.degrees(Double(i) * 6 - 90) // 12시 = -90도
                    
                    // Marker Line
                    Rectangle()
                        .fill(is5Min ? Color.primary : Color.gray.opacity(0.5))
                        .frame(width: is5Min ? 2 : 1, height: is5Min ? 12 : 6)
                        .offset(x: radius - (is5Min ? 15 : 10))
                        .rotationEffect(angle)
                        .position(center) // Center the rotation around view center
                    
                    // Numbers (Every 5 mins)
                    if is5Min {
                        let number = i == 0 ? 12 : i / 5
                        // Calculate position for number
                        // Angle is -90 (12), 0 (3), 90 (6)...
                        // cos, sin work with 0 at right (3 o'clock)
                        let numberRadius = radius - 35
                        let radian = Double(i) * 6 * .pi / 180 - .pi / 2
                        let x = center.x + numberRadius * cos(radian)
                        let y = center.y + numberRadius * sin(radian)
                        
                        Text("\(number)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .position(x: x, y: y)
                    }
                }
                
                // 3. Planned Session Sector (Pie Slice)
                ClockSector(start: startTime, end: endTime)
                    .fill(Color.blue.opacity(0.2))
                
                // 4. Current Time Hands
                // Hands Container (z-index above face)
                
                // Hour Hand
                ClockHand(length: radius * 0.55, thickness: 5, color: .primary, rounded: true)
                     .rotationEffect(angle(for: currentTime, component: .hour))
                     .shadow(radius: 2)
                
                // Minute Hand
                ClockHand(length: radius * 0.8, thickness: 3, color: .primary, rounded: true)
                     .rotationEffect(angle(for: currentTime, component: .minute))
                     .shadow(radius: 2)
                
                 // Second Hand
                 ZStack {
                     ClockHand(length: radius * 0.9, thickness: 1.5, color: .red, rounded: true)
                     Circle()
                         .fill(Color.red)
                         .frame(width: 8, height: 8)
                 }
                 .rotationEffect(angle(for: currentTime, component: .second))
                
                // Center Cap
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(Color.primary, lineWidth: 2))
            }
        }
    }
    
    // ✨ [New] Computed Glow Properites
    var remainingSeconds: TimeInterval {
        endTime.timeIntervalSince(currentTime)
    }
    
    var glowColor: Color {
        let min = remainingSeconds / 60
        if min <= 10 { return .red }
        if min <= 20 { return .orange }
        if min <= 30 { return .yellow }
        return .clear // 평소엔 없음 (또는 기본 그림자)
    }
    
    var glowRadius: CGFloat {
        let min = remainingSeconds / 60
        if min <= 10 { return 30 } // 강렬하게
        if min <= 30 { return 20 } // 은은하게
        return 0
    }
    
    // Hand starts pointing UP (12 o'clock) -> 0 degrees rotation means 12 o'clock
    // However, standard Angle(degrees: 0) typically points RIGHT in Shapes.
    // But rotationEffect rotates the VIEW. If view is a vertical bar, 0 deg = vertical.
    struct ClockHand: View {
        let length: CGFloat
        let thickness: CGFloat
        let color: Color
        let rounded: Bool
        
        var body: some View {
            // Anchor point needs to be bottom center of the hand usually?
            // Or simpler: Make a full length rectangle but offset it so it rotates around center
            VStack(spacing: 0) {
                 RoundedRectangle(cornerRadius: rounded ? thickness / 2 : 0)
                     .fill(color)
                     .frame(width: thickness, height: length)
                 Spacer(minLength: length) // Counter-balance to make center of rotation correct
            }
            .frame(height: length * 2) // Total height is 2 * length, rotating around center
            // Why length*2?
            // Center of VStack is (w/2, length).
            // Top half is the hand (length), Bottom half is Spacer (length).
            // So content is hand pointing UP from center.
        }
    }
    
    struct ClockSector: Shape {
        var start: Date
        var end: Date
        
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 20 // Slightly smaller than face
            
            // Angles: 0 is 3 o'clock (RIGHT) in addArc
            let startAngle = angleForArc(for: start)
            let endAngle = angleForArc(for: end)
            
            p.move(to: center)
            p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            p.closeSubpath()
            return p
        }
        
        func angleForArc(for date: Date) -> Angle {
            let cal = Calendar.current
            let h = Double(cal.component(.hour, from: date) % 12)
            let m = Double(cal.component(.minute, from: date))
            // 12 o'clock = -90 degrees
            // 3 o'clock = 0 degrees
            // Formula: (h + m/60) * 30 - 90
            let degrees = (h + m / 60.0) * 30.0 - 90.0
            return Angle(degrees: degrees)
        }
    }
    
    func angle(for date: Date, component: Calendar.Component) -> Angle {
        let cal = Calendar.current
        switch component {
        case .hour:
            let h = Double(cal.component(.hour, from: date) % 12)
            let m = Double(cal.component(.minute, from: date))
            // ClockHand points UP (12) by default.
            // 12h = 0 deg, 3h = 90 deg.
            return .degrees((h + m / 60.0) * 30.0)
        case .minute:
            let m = Double(cal.component(.minute, from: date))
            let s = Double(cal.component(.second, from: date))
             return .degrees((m + s / 60.0) * 6.0)
        case .second:
            let s = Double(cal.component(.second, from: date))
             return .degrees(s * 6.0)
        default:
            return .zero
        }
    }
}

