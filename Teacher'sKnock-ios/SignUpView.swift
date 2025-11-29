import SwiftUI
import Firebase
import FirebaseAuth

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedUniversity = "서울교육대학교" // 기본값
    
    // 뒤로가기 기능을 위한 환경 변수
    @Environment(\.dismiss) var dismiss
    
    // 브랜드 색상 (LoginView와 동일)
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 전국 교대 및 초등교육과 목록
    let universities = [
        "서울교육대학교", "경인교육대학교", "공주교육대학교", "광주교육대학교",
        "대구교육대학교", "부산교육대학교", "전주교육대학교", "진주교육대학교",
        "청주교육대학교", "춘천교육대학교", "제주대학교 교육대학", "한국교원대학교"
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // 1. 헤더 (뒤로가기 버튼 없음 - 네비게이션 바 사용 예정)
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(brandColor)
                    .padding(.top, 30)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // 2. 이메일 입력
                        inputField(title: "이메일", text: $email, icon: "envelope")
                        
                        // 3. 비밀번호 입력
                        secureInputField(title: "비밀번호 (6자리 이상)", text: $password)
                        secureInputField(title: "비밀번호 확인", text: $confirmPassword)
                        
                        // 4. 대학교 선택 (Picker)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("소속 대학교")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                            
                            HStack {
                                Image(systemName: "building.columns")
                                    .foregroundColor(.gray)
                                Picker("대학교 선택", selection: $selectedUniversity) {
                                    ForEach(universities, id: \.self) { uni in
                                        Text(uni).tag(uni)
                                    }
                                }
                                .pickerStyle(.menu) // 메뉴 스타일로 깔끔하게
                                .accentColor(.black)
                                Spacer()
                            }
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 25)

                        // 5. 회원가입 완료 버튼
                        Button(action: registerUser) {
                            Text("가입하기")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(brandColor)
                                .foregroundColor(.white)
                                .font(.headline)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // Firebase 회원가입 로직
    func registerUser() {
        // 간단한 유효성 검사
        guard !email.isEmpty, !password.isEmpty else { return }
        guard password == confirmPassword else {
            print("비밀번호가 일치하지 않습니다.")
            return
        }
        
        // Firebase 유저 생성
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("회원가입 실패: \(error.localizedDescription)")
            } else {
                print("회원가입 성공! ID: \(result?.user.uid ?? "")")
                print("선택한 대학: \(selectedUniversity)")
                // TODO: 대학 정보를 Firestore 등 DB에 저장하는 로직 필요 (Phase 2)
                dismiss() // 가입 성공 시 로그인 화면으로 복귀
            }
        }
    }
    
    // 입력 필드 디자인 컴포넌트
    @ViewBuilder
    func inputField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField(title, text: text)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .autocapitalization(.none)
        }
        .padding(.horizontal, 25)
    }
    
    // SignUpView.swift 파일의 맨 아래쪽 함수 수정

        @ViewBuilder
        func secureInputField(title: String, text: Binding<String>) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                SecureField(title, text: text)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    // 👇👇👇 이 코드를 추가하세요! 👇👇👇
                    .textContentType(.oneTimeCode)
                    .autocapitalization(.none)
                    // 👆👆👆 ----------------------- 👆👆👆
            }
            .padding(.horizontal, 25)
        }
}

#Preview {
    SignUpView()
}
