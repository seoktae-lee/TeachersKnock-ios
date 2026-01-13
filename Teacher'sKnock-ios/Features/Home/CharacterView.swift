import SwiftUI

import SwiftUI

// ✨ 9가지 진화 테마 정의
enum EvolutionTheme: CaseIterable {
    case fog        // 1. 안개 (기존)
    case flash      // 2. 섬광 (심플 화이트아웃)
    case spin       // 3. 회전 (3D Spin)
    case bounce     // 4. 통통 (Bounce)
    case slide      // 5. 슬라이드 (Slide In/Out)
    case zoom       // 6. 줌 (Zoom In)
    case blur       // 7. 블러 (Blur Fade)
    case curtain    // 8. 커튼 (Curtain Call)
    case skyDrop    // 9. 낙하 (Sky Drop)
}

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
        if currentLevel.isMaxLevel(for: characterType) { return 1.0 }
        let start = Double(currentLevel.daysRequiredForCurrentLevel)
        let end = Double(currentLevel.daysRequiredForNextLevel)
        let current = Double(uniqueDays)
        
        let diff = end - start
        return diff > 0 ? (current - start) / diff : 0
    }
    
    // 다음 레벨까지 남은 일수
    private var daysToNextLevel: Int {
        if currentLevel.isMaxLevel(for: characterType) { return 0 }
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
                
                if let imageName = currentLevel.imageName(for: characterType) {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .scaleEffect(isWiggling ? 1.1 : 1.0)
                        .onTapGesture { triggerInteraction() }
                } else {
                    Text(currentLevel.emoji(for: characterType))
                        .font(.system(size: 60)) // 80 -> 60
                        .scaleEffect(isWiggling ? 1.1 : 1.0)
                        .onTapGesture { triggerInteraction() }
                }
            }
            
            // --- 하단 정보 및 경험치 시스템 ---
            VStack(spacing: 8) { // 12 -> 8
                // 이름 및 레벨 텍스트
                VStack(spacing: 2) { // 4 -> 2
                    Text(characterName)
                        .font(.subheadline) // headline -> subheadline
                        .bold()
                    
                    Text("LV.\(currentLevel.rawValue + 1) \(currentLevel.title(for: characterType))")
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
                        if !currentLevel.isMaxLevel(for: characterType) {
                            Text("다음 진화까지 \(daysToNextLevel)일")
                        } else {
                            Text("최종 진화 완료")
                        }
                        Spacer()
                        // 만렙일 때는 다음 레벨 표시 안 함
                        Text(currentLevel.isMaxLevel(for: characterType) ? "" : "LV.\(currentLevel.rawValue + 2)")
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
                characterName: characterName,
                themeColorName: themeColorName,
                oldLevel: oldLevelForEvolution,
                newLevel: currentLevel,
                theme: evolutionTheme,
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
    @State private var evolutionTheme: EvolutionTheme = .fog // ✨ 랜덤 테마 저장용
    
    // 이 뷰가 나타나거나 데이터가 변경될 때 체크
    private func checkEvolution() {
        let key = "lastViewedLevel_\(goalTitle)" // 간단히 목표 제목을 키로 사용 (혹은 ID가 있다면 더 좋음)
        let lastLevelRaw = UserDefaults.standard.integer(forKey: key)
        
        let savedLevel = CharacterLevel(rawValue: lastLevelRaw) ?? .lv1
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(currentLevel.rawValue, forKey: key)
            return
        }
        
        if savedLevel.rawValue < currentLevel.rawValue {
            oldLevelForEvolution = savedLevel
            // ✨ 진화 시 랜덤 테마 선택
            evolutionTheme = EvolutionTheme.allCases.randomElement() ?? .fog
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
    let characterName: String
    let themeColorName: String
    let oldLevel: CharacterLevel
    let newLevel: CharacterLevel
    let theme: EvolutionTheme // ✨ Injected Theme
    let onCompletion: () -> Void
    
    @State private var animationState: AnimationPhase = .start
    @State private var flashOpacity: Double = 0.0
    @State private var particles: [Particle] = []
    
    // ✨ Fog Animation State
    @State private var fogOpacity: Double = 0.0
    @State private var fogScale: CGFloat = 1.0
    
    // ✨ Additional Animation States
    @State private var rotationY: Double = 0.0      // for Spin
    @State private var bounceOffset: CGFloat = 0.0  // for Bounce, SkyDrop
    @State private var slideOffsetOld: CGFloat = 0.0   // for Slide (Old)
    @State private var slideOffsetNew: CGFloat = 0.0   // for Slide (New)
    @State private var zoomScale: CGFloat = 1.0     // for Zoom
    @State private var blurRadius: CGFloat = 0.0    // for Blur
    @State private var curtainWidth: CGFloat = 0.0  // for Curtain
    
    // ✨ Share Logic
    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?
    
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
    
    init(characterType: String, characterName: String, themeColorName: String, oldLevel: CharacterLevel, newLevel: CharacterLevel, theme: EvolutionTheme, onCompletion: @escaping () -> Void) {
        self.characterType = characterType
        self.characterName = characterName
        self.themeColorName = themeColorName
        self.oldLevel = oldLevel
        self.newLevel = newLevel
        self.theme = theme
        self.onCompletion = onCompletion
        self.themeColor = GoalColorHelper.color(for: themeColorName)
    }
    
    var body: some View {
        ZStack {
            // Background (Darkness)
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // ✨ Fog Effect (Behind character)
            if theme == .fog {
                FogView(color: .white.opacity(0.3))
                    .opacity(fogOpacity)
                    .scaleEffect(fogScale)
                    .ignoresSafeArea()
            }
            
            // ✨ Layer 1: Character (Centered & Independent)
            ZStack {
                // Old Character
                if animationState == .start || animationState == .evolving || animationState == .reveal {
                    Group {
                        if let imageName = oldLevel.imageName(for: characterType) {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200) // Fixed size (Reverted to original small size)
                                .padding(20)
                        } else {
                            Text(oldLevel.emoji(for: characterType))
                                .font(.system(size: 100))
                        }
                    }
                    .modifier(EvolutionOldEffect(theme: theme, state: animationState, rotationY: rotationY, slideOffset: slideOffsetOld, blurRadius: blurRadius))
                    .opacity(animationState == .reveal && theme != .slide ? 0 : 1)
                    .animation(theme == .slide ? nil : .easeOut(duration: 0.5), value: animationState)
                }
                
                // New Character
                if animationState == .reveal || animationState == .celebration {
                    Group {
                        // ✨ [수정] 레벨 5-6(300), 레벨 3-4(250), 레벨 1-2(200)
                        let baseSize: CGFloat = newLevel.rawValue >= 4 ? 300 : (newLevel.rawValue >= 2 ? 250 : 200)
                        
                        if let imageName = newLevel.imageName(for: characterType) {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: baseSize, height: baseSize)
                        } else {
                            Text(newLevel.emoji(for: characterType))
                                .font(.system(size: 150))
                        }
                    }
                    .modifier(EvolutionNewEffect(theme: theme, state: animationState, rotationY: rotationY, bounceOffset: bounceOffset, slideOffset: slideOffsetNew, zoomScale: zoomScale, blurRadius: blurRadius))
                }
                
                // ✨ [이동] 레벨 & 칭호 표시 (캐릭터 바로 아래 동적 위치)
                if animationState == .celebration {
                    VStack(spacing: 8) {
                        // 1. 레벨 표시 (깔끔하고 크게)
                        Text("LV.\(newLevel.rawValue + 1)")
                            .font(.system(size: 40, weight: .black, design: .rounded)) // 크기 32 -> 40 확대
                            .foregroundColor(.white)
                            .shadow(color: themeColor, radius: 15, x: 0, y: 0) // Glow 강화
                        
                        // 2. 최종 진화 칭호 (Sophisticated Style: Elegant Font Only)
                        if newLevel.isMaxLevel(for: characterType) {
                            Text(newLevel.title(for: characterType))
                                .font(.system(size: 26, weight: .bold, design: .serif)) // 명조 계열(Serif)로 고급스러움 강조
                                .italic()
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .multilineTextAlignment(.center) // ✨ 텍스트 중앙 정렬 명시
                                .padding(.top, 4)
                                .transition(.scale.combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.6)))
                        }
                    }
                    .offset(y: characterSize / 2 + 50) // ✨ 캐릭터 크기에 따라 동적으로 위치 조정
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
                }
            }
            .zIndex(0) // Behind text
            
            // ✨ Layer 2: Header (Fixed Top)
            VStack {
                Text(headerText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(animationState == .start || animationState == .celebration ? 1 : 0)
                    .animation(.easeInOut, value: animationState)
                    .padding(.top, 60) // Safe top margin
                
                Spacer()
            }
            .zIndex(1) // On top of character
            
            // ✨ Front Fog (More density in front)
            if theme == .fog {
                FogView(color: .white.opacity(0.2))
                    .opacity(fogOpacity * 0.5)
                    .scaleEffect(fogScale * 1.2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // ✨ Curtain Theme Elements
            if theme == .curtain {
                HStack(spacing: 0) {
                    Color.black
                        .frame(width: curtainWidth)
                    Spacer()
                    Color.black
                        .frame(width: curtainWidth)
                }
                .ignoresSafeArea()
            }
            
            // Flash Effect (Bright Light)
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
                    

                    // ✨ Buttons Row (Restyled for Sophistication)
                    HStack(spacing: 12) {
                        Button(action: renderAndShare) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                Text("자랑하기")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                        }
                        
                        Button(action: onCompletion) {
                            Text("완료")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule()
                                        .fill(themeColor)
                                        .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                )
                        }
                    }
                    .padding(.horizontal, 30) // 버튼 너비 확보를 위해 여백 조정
                    .padding(.bottom, 30)
                    
                    // ✨ 공식적이고 딱딱한 저작권 경고 문구 (화면 최하단)
                    Text("© Teacher's Knock. 본 캐릭터 이미지는 저작권법의 보호를 받으며,\n무단 캡처 및 배포 시 불이익을 받을 수 있습니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startEvolutionSequence()
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                EvolutionActivityView(activityItems: [image])
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private var headerText: String {
        switch animationState {
        case .start, .evolving:
            return "오잉? \(characterName)의 상태가...?"
        case .flash:
            return ""
        case .reveal, .celebration:
            return "축하합니다!\n진화에 성공했어요!"
        }
    }
    
    // ✨ 캐릭터 크기 계산 (레벨별 차등)
    private var characterSize: CGFloat {
        // Lv 1-2(0,1): 200, Lv 3-4(2,3): 250, Lv 5-6(4,5): 300
        return newLevel.rawValue >= 4 ? 300 : (newLevel.rawValue >= 2 ? 250 : 200)
    }
    
    private func startEvolutionSequence() {
        // ✨ Common Start Delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { animationState = .evolving }
            
            // ✨ Theme Specific Preparation
            prepareThemeAnimation()
            
            // ✨ Wait for evolution duration (varies slightly or fixed 2s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Flash Effect for some themes
                if shouldFlash() {
                    withAnimation(.easeIn(duration: 0.2)) { flashOpacity = 1.0 }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    animationState = .reveal
                    
                    // ✨ Execute Reveal Animation
                    runRevealAnimation()
                    
                    createParticles()
                    
                    // 3. Celebration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation { animationState = .celebration }
                    }
                }
            }
        }
    }
    
    // ✨ Animation Logic Breakdown
    private func prepareThemeAnimation() {
        switch theme {
        case .fog:
            withAnimation(.easeIn(duration: 2.0)) { fogOpacity = 1.0; fogScale = 1.0 }
        case .spin:
            withAnimation(.linear(duration: 2.0)) { rotationY = 720 } // Spin 2 times
        case .slide:
            withAnimation(.easeInOut(duration: 2.0)) { slideOffsetOld = -50 } // Slight anticipate
        case .zoom:
            withAnimation(.easeInOut(duration: 2.0)) { zoomScale = 0.1 }
        case .blur:
             withAnimation(.easeInOut(duration: 2.0)) { blurRadius = 20 }
        case .curtain:
             withAnimation(.easeInOut(duration: 1.5)) { curtainWidth = UIScreen.main.bounds.width / 2 }
        default: break
        }
    }
    
    private func shouldFlash() -> Bool {
        return [.fog, .flash, .spin, .zoom].contains(theme)
    }
    
    private func runRevealAnimation() {
        switch theme {
        case .fog:
            withAnimation(.easeOut(duration: 1.5)) { flashOpacity = 0.0; fogOpacity = 0.0; fogScale = 2.5 }
        case .flash:
             withAnimation(.easeOut(duration: 1.0)) { flashOpacity = 0.0 }
        case .spin:
             rotationY = 0 // Reset doesn't affect old char if it fades out
             withAnimation(.easeOut(duration: 1.0)) { flashOpacity = 0.0 }
        case .bounce:
            bounceOffset = 300
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { bounceOffset = 0 }
        case .slide:
            // ✨ Slide: Old moves out Left, New moves in from Right
            slideOffsetNew = 300 // Start New from Right
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { 
                slideOffsetOld = -300 // Old exits Left
                slideOffsetNew = 0    // New Enters Center
            }
        case .zoom:
            zoomScale = 0.01
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { zoomScale = 1.0; flashOpacity = 0.0 }
        case .blur:
            blurRadius = 20
            withAnimation(.easeOut(duration: 1.0)) { blurRadius = 0 }
        case .curtain:
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) { curtainWidth = 0 }
        case .skyDrop:
            bounceOffset = -500 // Start from top
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) { bounceOffset = 0 }
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
    
    // ✨ Share Logic Wrapper
    @MainActor
    private func renderAndShare() {
        let width: CGFloat = 375
        let height: CGFloat = 667
        
        // 공유용 뷰 생성
        let renderView = EvolutionShareView(
            characterType: characterType,
            characterEmoji: newLevel.emoji(for: characterType),
            characterImageName: newLevel.imageName(for: characterType),
            levelTitle: newLevel.title(for: characterType),
            levelRaw: newLevel.rawValue + 1,
            themeColor: themeColor
        )
        .frame(width: width, height: height)
        
        // ✨ [Fix] Use explicitly sized rendering
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0 // High resolution
        
        if let image = renderer.uiImage {
            // print("✅ Image generated successfully")
            self.shareImage = image
            self.isShareSheetPresented = true
        } else {
            // print("❌ Failed to generate image")
        }
    }
}

// ✨ Dedicated Share View
struct EvolutionShareView: View {
    let characterType: String
    let characterEmoji: String
    let characterImageName: String? // ✨ [Add] Optional image name
    let levelTitle: String
    let levelRaw: Int
    let themeColor: Color
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [themeColor.opacity(0.8), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Particles Decoration
            ForEach(0..<15) { _ in
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: CGFloat.random(in: 10...30))
                    .position(
                        x: CGFloat.random(in: 0...375),
                        y: CGFloat.random(in: 0...667)
                    )
            }
            
            VStack(spacing: 30) {
                // Header
                Text("LEVEL UP!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    .padding(.top, 60)
                
                Spacer()
                
                // Character Card
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 250, height: 250)
                        .shadow(radius: 20)
                    
                    if let imageName = characterImageName {
                        // ✨ [수정] 스포일러 방지를 위한 실루엣(그림자) 처리
                        Image(imageName)
                            .resizable()
                            .renderingMode(.template) // 템플릿 모드로 변경하여 색상 적용 가능하게 함
                            .foregroundColor(.black.opacity(0.85)) // 진한 검은색 실루엣 적용
                            .scaledToFit()
                            .padding(30)
                            .blur(radius: 6) // ✨ 윤곽을 흐리게 하여 궁금증 유발 강화
                    } else {
                        Text(characterEmoji)
                            .font(.system(size: 140))
                    }
                }
                
                // Info
                VStack(spacing: 8) {
                    Text("LV.\(levelRaw)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                        .shadow(radius: 2)
                    
                    Text(levelTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Footer
                HStack(spacing: 8) {
                    Image("TeachersKnockLogo")
                        .resizable()
                        .renderingMode(.template) // 흰색 틴트 적용을 위해 템플릿 모드 사용
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Teacher's Knock")
                }
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 40)
            }
        }
        .frame(width: 375, height: 667)
    }
}

// ✨ Dedicated Local Share Sheet Wrapper
fileprivate struct EvolutionActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<EvolutionActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // iPad Support: Set popover source implicitly if possible, or leave to UIKit default behavior which often centers.
        // For a robust implementation, we might need to inject sourceView via context, but .sheet usually handles this.
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<EvolutionActivityView>) {}
}

// Shake Effect Modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 10 * sin(animatableData * .pi * 8)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// ✨ Fog Effect View instead of Sunburst
struct FogView: View {
    let color: Color
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Create multiple randomly placed blurred circles
                ForEach(0..<8) { i in
                    Circle()
                        .fill(color)
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.width * 0.8)
                        .position(
                            x: CGFloat.random(in: 0...proxy.size.width),
                            y: CGFloat.random(in: 0...proxy.size.height)
                        )
                        .blur(radius: 50)
                }
            }
        }
    }
}

// ✨ Custom Modifiers for Themes

struct EvolutionOldEffect: ViewModifier {
    let theme: EvolutionTheme
    let state: EvolutionView.AnimationPhase
    let rotationY: Double
    let slideOffset: CGFloat
    let blurRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: state == .evolving && theme != .spin ? 1.0 : 0.0)) // Default Shake
            .rotation3DEffect(.degrees(theme == .spin ? rotationY : 0), axis: (x: 0, y: 1, z: 0))
            .offset(x: theme == .slide ? slideOffset : 0) // Uses slideOffsetOld
            .blur(radius: theme == .blur ? blurRadius : 0)
            .scaleEffect(theme == .zoom && state == .evolving ? 0.1 : 1.0)
            .opacity(theme == .flash && state == .evolving ? (Double.random(in: 0.5...1)) : 1.0) // Flicker
    }
}

struct EvolutionNewEffect: ViewModifier {
    let theme: EvolutionTheme
    let state: EvolutionView.AnimationPhase
    let rotationY: Double
    let bounceOffset: CGFloat
    let slideOffset: CGFloat
    let zoomScale: CGFloat
    let blurRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect((theme == .zoom || theme == .fog) && state == .reveal ? zoomScale : 1.0)
            .scaleEffect(state == .reveal && theme != .zoom && theme != .fog ? 1.0 : (theme == .fog ? (state == .reveal ? 0.1 : 1.0) : zoomScale))
            
            .rotation3DEffect(.degrees(theme == .spin ? 0 : 0), axis: (x: 0, y: 1, z: 0))
            
            .offset(y: (theme == .bounce || theme == .skyDrop) ? bounceOffset : 0)
            .offset(x: theme == .slide ? slideOffset : 0) // Uses slideOffsetNew
            .blur(radius: theme == .blur ? blurRadius : 0)
    }
}

// ✨ SunburstView removed (replaced by FogView)
