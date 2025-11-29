import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0.0
    @Binding var isSplashFinished: Bool
    
    // LoginView와 동일한 색상 정의
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack {
                // 1. 메인 타이틀
                Text("Teacher's Knock")
                    .font(.system(size: 40, weight: .bold, design: .default))
                    .foregroundColor(brandColor) // 수정된 색상 적용
                    .padding(.bottom, 10)
                
                // 2. 캐치프레이즈
                Text("당신의 합격 순간까지 함께할")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) {
                    opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        opacity = 0.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isSplashFinished = true
                    }
                }
            }
        }
    }
}
