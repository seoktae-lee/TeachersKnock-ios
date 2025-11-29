import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    
    @EnvironmentObject var authManager: AuthManager
    
    // 알림창 상태
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    // ✨ 웰컴 애니메이션 상태 변수
    @State private var showWelcomeScreen = false
    @State private var welcomeOpacity = 0.0
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)

    var body: some View {
        NavigationStack {
            ZStack {
                // --- 기존 로그인 UI ---
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    Text("Teacher's Knock")
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .foregroundColor(brandColor)
                        .padding(.bottom, 5)
                    
                    Text("당신의 합격 순간까지 함께할")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 50)

                    VStack(spacing: 15) {
                        TextField("이메일 주소", text: $email)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("비밀번호", text: $password)
                            .padding()
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.horizontal, 25)
                    
                    // 비밀번호 찾기
                    HStack {
                        Spacer()
                        Button("비밀번호를 잊으셨나요?") {
                            resetPassword()
                        }
                        .font(.caption)
                        .foregroundColor(brandColor)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 10)
                    
                    // 로그인 버튼
                    Button("로그인") {
                        loginUser()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(brandColor)
                    .foregroundColor(.white)
                    .font(.headline)
                    .cornerRadius(8)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)

                    // 회원가입 버튼
                    NavigationLink(destination: SignUpView()) {
                        Text("계정이 없으신가요? 회원가입")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                .padding()
                
                // --- ✨ 웰컴 애니메이션 오버레이 (로그인 성공 시 등장) ---
                if showWelcomeScreen {
                    Color.white.ignoresSafeArea() // 배경 덮기
                    
                    VStack {
                        Text("Teacher's Knock")
                            .font(.system(size: 40, weight: .bold, design: .default))
                            .foregroundColor(brandColor)
                            .padding(.bottom, 10)
                        
                        // ✨ 추천 멘트 적용
                        Text("오늘도 합격에 한 걸음 더")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .opacity(welcomeOpacity) // 페이드 인 효과용
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                if alertTitle == "인증 필요" {
                    Button("인증 메일 재전송") { resendVerificationEmail() }
                    Button("확인", role: .cancel) { }
                } else {
                    Button("확인", role: .cancel) { }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    func loginUser() {
        guard !email.isEmpty, !password.isEmpty else {
            alertTitle = "알림"; alertMessage = "이메일과 비밀번호를 입력해주세요."; showAlert = true; return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertTitle = "로그인 실패"; alertMessage = "이메일이나 비밀번호를 확인해주세요."; showAlert = true
            } else {
                if let user = result?.user, !user.isEmailVerified {
                    // 이메일 인증 안된 경우 로그아웃 시키고 경고
                    try? Auth.auth().signOut()
                    alertTitle = "인증 필요"; alertMessage = "이메일 인증이 완료되지 않았습니다."; showAlert = true
                } else {
                    // ✨ 로그인 성공! -> 바로 넘기지 않고 웰컴 화면 보여줌
                    print("로그인 성공! 웰컴 애니메이션 시작")
                    withAnimation {
                        showWelcomeScreen = true // 흰 배경 덮기
                    }
                    
                    // 텍스트 페이드 인
                    withAnimation(.easeIn(duration: 1.0)) {
                        welcomeOpacity = 1.0
                    }
                    
                    // 2초 뒤에 메인 화면으로 전환
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        authManager.isLoggedIn = true
                    }
                }
            }
        }
    }
    
    func resendVerificationEmail() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                user.sendEmailVerification { error in
                    if let error = error {
                        alertTitle = "오류"; alertMessage = "전송 실패: \(error.localizedDescription)"
                    } else {
                        alertTitle = "전송 완료"; alertMessage = "인증 메일을 다시 보냈습니다."
                    }
                    try? Auth.auth().signOut()
                    showAlert = true
                }
            }
        }
    }
    
    func resetPassword() {
        guard !email.isEmpty else {
            alertTitle = "알림"; alertMessage = "이메일을 입력해주세요."; showAlert = true; return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertTitle = "전송 실패"; alertMessage = error.localizedDescription
            } else {
                alertTitle = "전송 완료"; alertMessage = "\(email)로 재설정 메일을 보냈습니다."
            }
            showAlert = true
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthManager())
}
