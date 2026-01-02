import SwiftUI

struct EvolutionView: View {
    @ObservedObject var characterManager = CharacterManager.shared
    @State private var isAnimating = false
    @State private var showFlash = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // 배경: 어두운 오버레이
            Color.black.opacity(0.85).ignoresSafeArea()
            
            // 빛 효과
            if isAnimating {
                RadialGradient(gradient: Gradient(colors: [.white, .clear]), center: .center, startRadius: 10, endRadius: 200)
                    .opacity(showFlash ? 0.8 : 0)
                    .scaleEffect(showFlash ? 2.0 : 0.5)
            }
            
            VStack(spacing: 40) {
                if let character = characterManager.equippedCharacter {
                    VStack(spacing: 20) {
                        Text("축하합니다!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(opacity)
                        
                        Text("\(character.name)이(가)\n진화했습니다!")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .opacity(opacity)
                    }
                    
                    // 캐릭터 연출
                    ZStack {
                        // 후광 효과
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 250, height: 250)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                        
                        // 캐릭터 이모지
                        let level = CharacterLevel(rawValue: character.level) ?? .lv1
                        Text(level.emoji(for: character.type))
                            .font(.system(size: 150))
                            .scaleEffect(scale)
                            .rotationEffect(.degrees(rotation))
                            .shadow(color: .yellow, radius: showFlash ? 50 : 0)
                    }
                    
                    // 레벨 배지
                    Text("Lv.\(character.level + 1)")
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                        .opacity(opacity)
                        .offset(y: opacity == 1 ? 0 : 20)
                    
                    Button(action: {
                        withAnimation {
                            characterManager.showEvolutionAnimation = false
                        }
                    }) {
                        Text("멋져요!")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.white))
                    }
                    .padding(.top, 40)
                    .opacity(opacity)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // 1. 초기 두근두근 연출
        withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
            scale = 0.6
            rotation = 5
        }
        
        // 2. 번쩍! (진화 순간)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                showFlash = true
                scale = 1.2 // 확 커짐
                rotation = 0
            }
            
            // 3. 진화 완료 및 UI 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showFlash = false
                    scale = 1.0
                    isAnimating = true // 후광 애니메이션 시작
                    opacity = 1.0 // 텍스트 등장
                }
            }
        }
    }
}
