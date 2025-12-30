import SwiftUI

// 1. 말풍선 꼬리 모양을 정의하는 Shape
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 15
        
        // 메인 사각형 (하단 꼬리 공간 10포인트 제외)
        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 10), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        // 하단 중앙 삼각형 꼬리
        path.move(to: CGPoint(x: rect.midX - 10, y: rect.height - 10))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.addLine(to: CGPoint(x: rect.midX + 10, y: rect.height - 10))
        path.closeSubpath()
        
        return path
    }
}

struct CharacterView: View {
    // 필수 데이터 프로퍼티
    let uniqueDays: Int
    let characterName: String
    let themeColorName: String
    let characterType: String
    let goalTitle: String
    
    // 상태 변수
    @State private var showMessage: Bool = false
    @State private var currentMessage: String = ""
    @State private var isWiggling: Bool = false
    
    // 캐릭터 응원 문구 리스트
    private let cheers = [
        "오늘도 합격에 한 걸음 더!",
        "교육과정 암기 파이팅!",
        "티노는 당신을 믿어요!",
        "조금만 더 힘내볼까요?",
        "지금의 노력이 결실을 맺을 거예요."
    ]
    
    // 레벨 계산 로직
    private var currentLevel: CharacterLevel {
        CharacterLevel.getLevel(uniqueDays: uniqueDays)
    }
    
    // 경험치 진행률 계산
    private var progress: Double {
        if currentLevel == .lv10 { return 1.0 }
        let start = Double(currentLevel.daysRequiredForCurrentLevel)
        let end = Double(currentLevel.daysRequiredForNextLevel)
        let current = Double(uniqueDays)
        
        let diff = end - start
        return diff > 0 ? (current - start) / diff : 0
    }
    
    // 다음 레벨까지 남은 일수
    private var daysToNextLevel: Int {
        if currentLevel == .lv10 { return 0 }
        return max(0, currentLevel.daysRequiredForNextLevel - uniqueDays)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- 상단 말풍선 영역 ---
            ZStack {
                if showMessage {
                    Text(currentMessage)
                        .font(.system(size: 13, weight: .bold)) // 14 -> 13
                        .padding(.horizontal, 12) // 16 -> 12
                        .padding(.vertical, 8) // 12 -> 8
                        .background(
                            BubbleShape()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3) // radius 8->6
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.6)),
                            removal: .opacity.animation(.easeOut(duration: 0.2))
                        ))
                } else {
                    // 말풍선이 없을 때도 높이를 유지하여 레이아웃 흔들림 방지
                    Color.clear.frame(height: 40) // 50 -> 40
                }
            }
            .frame(height: 55) // 65 -> 55
            .padding(.bottom, 4) // 10 -> 4
            
            // --- 캐릭터 본체 ---
            ZStack {
                Circle()
                    .fill(GoalColorHelper.color(for: themeColorName).opacity(0.1))
                    .frame(width: 100, height: 100) // 140 -> 100
                
                Text(currentLevel.emoji(for: characterType))
                    .font(.system(size: 60)) // 80 -> 60
                    .scaleEffect(isWiggling ? 1.1 : 1.0)
                    .onTapGesture { triggerInteraction() }
            }
            
            // --- 하단 정보 및 경험치 시스템 ---
            VStack(spacing: 8) { // 12 -> 8
                // 이름 및 레벨 텍스트
                VStack(spacing: 2) { // 4 -> 2
                    Text(characterName)
                        .font(.subheadline) // headline -> subheadline
                        .bold()
                    
                    Text("LV.\(currentLevel.rawValue + 1) \(currentLevel.title)")
                        .font(.caption) // subheadline -> caption
                        .fontWeight(.bold)
                        .foregroundColor(GoalColorHelper.color(for: themeColorName))
                }
                
                // 경험치 게이지 바 섹션
                VStack(spacing: 4) { // 6 -> 4
                    ProgressView(value: progress)
                        .tint(GoalColorHelper.color(for: themeColorName))
                        .background(GoalColorHelper.color(for: themeColorName).opacity(0.1))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center) // y: 2 -> 1.5
                        .clipShape(Capsule())
                    
                    HStack {
                        Text("LV.\(currentLevel.rawValue + 1)")
                        Spacer()
                        if currentLevel != .lv10 {
                            Text("다음 진화까지 \(daysToNextLevel)일")
                        } else {
                            Text("최고 레벨 달성!")
                        }
                        Spacer()
                        // 만렙일 때는 다음 레벨 표시 안 함
                        Text(currentLevel == .lv10 ? "" : "LV.\(currentLevel.rawValue + 2)")
                    }
                    .font(.system(size: 9, weight: .medium)) // 10 -> 9
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24) // 30 -> 24
                .padding(.top, 2) // 5 -> 2
                
                // 성장 방법 안내 가이드
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text("매일 공부 기록을 완료하면 출석 일수에 따라 캐릭터가 진화해요!")
                }
                .font(.system(size: 9)) // 10 -> 9
                .foregroundColor(.gray.opacity(0.8))
                .padding(.top, 2) // 4 -> 2
            }
            .padding(.top, 10) // 15 -> 10
        }
        .padding(.vertical, 16) // 25 -> 16
        .padding(.horizontal, 16) // 20 -> 16
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20) // 25 -> 20
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6) // radius 15 -> 10
        .onAppear { checkEvolution() }
        .onChange(of: uniqueDays) { _ in checkEvolution() }
        .fullScreenCover(isPresented: $isEvolving) {
            EvolutionView(
                characterType: characterType,
                themeColorName: themeColorName,
                oldLevel: oldLevelForEvolution,
                newLevel: currentLevel,
                onCompletion: completeEvolution
            )
        }
    }
    
    
    // 캐릭터 터치 상호작용 로직
    private func triggerInteraction() {
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // 랜덤 메시지 선택
        currentMessage = cheers.randomElement() ?? ""
        
        // 애니메이션 실행
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            isWiggling = true
            showMessage = true
        }
        
        // 캐릭터 흔들림 효과 원복 (0.2초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { isWiggling = false }
        }
        
        // 말풍선 자동 숨김 (2.5초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showMessage = false }
        }
    }
    
    // MARK: - 진화 시스템 로직
    @State private var isEvolving: Bool = false
    @State private var oldLevelForEvolution: CharacterLevel = .lv1
    
    // 이 뷰가 나타나거나 데이터가 변경될 때 체크
    private func checkEvolution() {
        let key = "lastViewedLevel_\(goalTitle)" // 간단히 목표 제목을 키로 사용 (혹은 ID가 있다면 더 좋음)
        
        // ✨ [테스트] 강제로 기억 지우기 (항상 레벨 1이었다고 착각하게 만듦)
        UserDefaults.standard.set(0, forKey: key)
        
        let lastLevelRaw = UserDefaults.standard.integer(forKey: key)
        
        // 데이터가 아예 없으면(0) 현재 레벨로 세팅 (첫 실행 시 진화 방지)
        // 하지만 레벨 1이 0이므로, 저장 여부를 확인해야 함.
        // 여기서는 편의상 UserDefaults.standard.object(forKey:)로 체크하거나,
        // 로직을 단순화하여: 현재 레벨이 저장된 레벨보다 높으면 진화!
        
        let savedLevel = CharacterLevel(rawValue: lastLevelRaw) ?? .lv1
        
        // 저장된 레벨이 현재 레벨보다 낮고, 초기화 상태(데이터 없음)가 아닐 때
        // (단, 키가 없으면 integer는 0반환. 1레벨(0) -> 2레벨(1) 시 정상 작동)
        // 저장이 안되어 있으면(최초), 현재 레벨 저장하고 종료
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(currentLevel.rawValue, forKey: key)
            return
        }
        
        if savedLevel.rawValue < currentLevel.rawValue {
            oldLevelForEvolution = savedLevel
            isEvolving = true
        }
    }
    
    private func completeEvolution() {
        // 진화 애니메이션 종료 후 현재 레벨 저장
        let key = "lastViewedLevel_\(goalTitle)"
        UserDefaults.standard.set(currentLevel.rawValue, forKey: key)
        withAnimation {
            isEvolving = false
        }
    }
}

// ✨ Modifiers 추가를 위해 Extension 또는 View 확장이 필요할 수 있으나,
// 여기서는 body의 마지막에 modifier를 붙이기 위해 View 자체를 감싸는 방식보다
// 상위 뷰에서 호출하거나 body 내부 ZStack 등에 붙이는게 좋으나, 
// 기존 body 구조상 가장 바깥쪽 VStack에 modifier를 붙입니다.
extension CharacterView {
    // 뷰 수정자 적용을 위한 헬퍼 (기존 body가 프로퍼티라 직접 수정이 어려우므로)
    // 리팩토링: body를 직접 수정하여 onAppear와 fullScreenCover를 추가합니다.
}

// MARK: - Evolution View (Merged due to Xcode linking issues)

struct EvolutionView: View {
    let characterType: String
    let themeColorName: String
    let oldLevel: CharacterLevel
    let newLevel: CharacterLevel
    let onCompletion: () -> Void
    
    @State private var animationState: AnimationPhase = .start
    @State private var flashOpacity: Double = 0.0
    @State private var particles: [Particle] = []
    
    private let themeColor: Color
    
    enum AnimationPhase {
        case start      // Show old character
        case evolving   // Shaking / preparing
        case flash      // White screen flash
        case reveal     // Show new character
        case celebration // Show text/buttons
    }
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var speedX: CGFloat
        var speedY: CGFloat
        var color: Color
        var opacity: Double = 1.0
    }
    
    init(characterType: String, themeColorName: String, oldLevel: CharacterLevel, newLevel: CharacterLevel, onCompletion: @escaping () -> Void) {
        self.characterType = characterType
        self.themeColorName = themeColorName
        self.oldLevel = oldLevel
        self.newLevel = newLevel
        self.onCompletion = onCompletion
        self.themeColor = GoalColorHelper.color(for: themeColorName)
    }
    
    var body: some View {
        ZStack {
            // Background Blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // Background Rays (Rotated)
            if animationState == .reveal || animationState == .celebration {
                SunburstView(color: themeColor)
                    .transition(.opacity)
            }
            
            VStack(spacing: 40) {
                // Header Text
                Text(headerText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(animationState == .start || animationState == .celebration ? 1 : 0)
                    .animation(.easeInOut, value: animationState)
                
                // Character Area
                ZStack {
                    // Old Character
                    if animationState == .start || animationState == .evolving {
                        Text(oldLevel.emoji(for: characterType))
                            .font(.system(size: 100))
                            .modifier(ShakeEffect(animatableData: animationState == .evolving ? 1.0 : 0.0))
                    }
                    
                    // New Character
                    if animationState == .reveal || animationState == .celebration {
                        Text(newLevel.emoji(for: characterType))
                            .font(.system(size: 150))
                            .scaleEffect(animationState == .reveal ? 0.1 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: animationState)
                    }
                }
                .frame(height: 200)
                
                // Level Info
                if animationState == .celebration {
                    VStack(spacing: 8) {
                        Text("LV.\(oldLevel.rawValue + 1) -> LV.\(newLevel.rawValue + 1)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(newLevel.title)
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            
            // Flash Effect
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
            
            // Particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8 * particle.scale, height: 8 * particle.scale)
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
            
            // Close Button / Tap to Close
            if animationState == .celebration {
                VStack {
                    Spacer()
                    Button(action: onCompletion) {
                        Text("멋져요!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(themeColor)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startEvolutionSequence()
        }
    }
    
    private var headerText: String {
        switch animationState {
        case .start, .evolving:
            return "오잉? \(characterType == "bird" ? "새" : characterType == "sea" ? "물고기" : "식물")의 상태가...?"
        case .flash:
            return ""
        case .reveal, .celebration:
            return "축하합니다!\n진화에 성공했어요!"
        }
    }
    
    private func startEvolutionSequence() {
        // 1. Start (Wait 1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { animationState = .evolving }
            
            // 2. Evolving (Shake for 2s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Flash Start
                withAnimation(.easeIn(duration: 0.2)) { flashOpacity = 1.0 }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    animationState = .reveal
                    withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0.0 }
                    createParticles()
                    
                    // 3. Celebration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { animationState = .celebration }
                    }
                }
            }
        }
    }
    
    private func createParticles() {
        for _ in 0..<50 {
            let particle = Particle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2,
                scale: CGFloat.random(in: 0.5...1.5),
                speedX: CGFloat.random(in: -5...5),
                speedY: CGFloat.random(in: -10...5),
                color: [themeColor, .white, .yellow].randomElement()!
            )
            particles.append(particle)
        }
        
        // Timer to move particles
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            guard animationState == .reveal || animationState == .celebration else {
                timer.invalidate()
                return
            }
            
            for i in particles.indices {
                particles[i].x += particles[i].speedX
                particles[i].y += particles[i].speedY
                particles[i].speedY += 0.2 // Gravity
                particles[i].opacity -= 0.01
            }
            if particles.allSatisfy({ $0.opacity <= 0 }) {
                timer.invalidate()
            }
        }
    }
}

// Shake Effect Modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 10 * sin(animatableData * .pi * 8)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// Sunburst Background Effect
struct SunburstView: View {
    let color: Color
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(width: 40, height: 800) // Long beams
                    .offset(y: -200)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}


