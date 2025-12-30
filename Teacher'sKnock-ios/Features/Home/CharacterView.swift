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
}
