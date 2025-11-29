import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    
    // ✨ 변경점: @Binding을 제거하고, @EnvironmentObject로 AuthManager를 받습니다.
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)

    var body: some View {
        NavigationStack {
            ZStack {
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("비밀번호", text: $password)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 25)
                    
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
                    .padding(.top, 25)

                    NavigationLink(destination: SignUpView()) {
                        Text("계정이 없으신가요? 회원가입")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // Firebase 로그인 함수
    func loginUser() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = "로그인 실패: 이메일이나 비밀번호를 확인해주세요."
                showAlert = true
            } else {
                // ✨ 로그인 성공 시 AuthManager의 상태를 true로 변경
                authManager.isLoggedIn = true
            }
        }
    }
}

// 프리뷰는 수정된 LoginView 구조에 맞게 변경됩니다.
#Preview {
    LoginView()
        .environmentObject(AuthManager()) // 프리뷰를 위해 AuthManager 제공
}
