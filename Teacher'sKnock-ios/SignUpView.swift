import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    // 입력 상태 변수
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedUniversity = "서울교육대학교"
    // ✨ 닉네임 추가
    @State private var nickname = ""
    
    @State private var isAgreed = false
    
    @State private var isEmailVerified = false
    @State private var isVerificationSent = false
    @State private var timer: Timer?
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    let universities = [
        "서울교육대학교", "경인교육대학교", "공주교육대학교", "광주교육대학교",
        "대구교육대학교", "부산교육대학교", "전주교육대학교", "진주교육대학교",
        "청주교육대학교", "춘천교육대학교", "제주대학교 교육대학", "한국교원대학교"
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(brandColor)
                    .padding(.top, 30)
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // --- 1. 이메일 & 닉네임 입력 섹션 ---
                        VStack(alignment: .leading, spacing: 5) {
                            
                            // ✨ 닉네임 입력 필드 추가
                            Text("닉네임")
                                .font(.caption).foregroundColor(.gray).padding(.leading, 5)
                            
                            TextField("앱에서 사용할 이름 (예: 열공이)", text: $nickname)
                                .padding()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                .autocapitalization(.none)
                                .disabled(isVerificationSent) // 메일 보내면 수정 불가
                                .padding(.bottom, 10)
                            
                            Text("이메일 주소")
                                .font(.caption).foregroundColor(.gray).padding(.leading, 5)
                            
                            HStack {
                                ZStack(alignment: .leading) {
                                    if email.isEmpty {
                                        Text(verbatim: "예: teacher@example.com")
                                            .foregroundColor(Color.gray.opacity(0.6))
                                    }
                                    TextField("", text: $email)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .disabled(isVerificationSent)
                                }
                                .padding()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                
                                Button(action: sendVerificationEmail) {
                                    Text(isEmailVerified ? "완료" : (isVerificationSent ? "재전송" : "인증"))
                                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                                        .padding(.vertical, 13).padding(.horizontal, 15)
                                        .background(isEmailVerified ? Color.green : brandColor)
                                        .cornerRadius(8)
                                }
                                // ✨ 닉네임도 입력해야 인증 버튼 활성화
                                .disabled(isEmailVerified || email.isEmpty || nickname.isEmpty)
                            }
                            
                            if isVerificationSent && !isEmailVerified {
                                Text("📩 인증 메일이 발송되었습니다. 링크를 누른 후 잠시만 기다려주세요.")
                                    .font(.caption).foregroundColor(.orange).padding(.leading, 5)
                            } else if isEmailVerified {
                                Text("✅ 본인 인증이 완료되었습니다. 비밀번호를 설정해주세요.")
                                    .font(.caption).foregroundColor(.green).padding(.leading, 5)
                            }
                        }
                        .padding(.horizontal, 25)
                        
                        // --- 2. 비밀번호 & 대학 입력 (인증 후 표시) ---
                        if isEmailVerified {
                            VStack(spacing: 20) {
                                Divider().padding(.vertical, 10)
                                
                                secureInputField(title: "비밀번호 설정 (6자리 이상)", text: $password)
                                secureInputField(title: "비밀번호 확인", text: $confirmPassword)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("소속 대학교").font(.caption).foregroundColor(.gray).padding(.leading, 5)
                                    HStack {
                                        Image(systemName: "building.columns").foregroundColor(.gray)
                                        Picker("대학교 선택", selection: $selectedUniversity) {
                                            ForEach(universities, id: \.self) { uni in Text(uni).tag(uni) }
                                        }
                                        .pickerStyle(.menu).accentColor(.black)
                                        Spacer()
                                    }
                                    .padding()
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                }
                                .padding(.horizontal, 25)
                                
                                HStack(alignment: .top) {
                                    Button(action: { isAgreed.toggle() }) {
                                        Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isAgreed ? brandColor : .gray)
                                            .font(.title3)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("아래 약관에 동의합니다.").font(.subheadline).foregroundColor(.black)
                                        HStack(spacing: 0) {
                                            Link("이용약관", destination: URL(string: "https://www.google.com")!).foregroundColor(brandColor)
                                            Text(" 및 ").foregroundColor(.gray)
                                            Link("개인정보 처리방침", destination: URL(string: "https://www.google.com")!).foregroundColor(brandColor)
                                        }
                                        .font(.caption)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 30).padding(.top, 10)
                                
                                Button(action: finalizeSignup) {
                                    Text("합격의 문 두드리기")
                                        .frame(maxWidth: .infinity).padding()
                                        .background(isAgreed ? brandColor : Color.gray)
                                        .foregroundColor(.white).font(.headline).cornerRadius(8)
                                }
                                .disabled(!isAgreed)
                                .padding(.horizontal, 25).padding(.top, 10)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("확인") { if isSuccess { dismiss() } }
        } message: { Text(alertMessage) }
        .onDisappear { timer?.invalidate() }
    }
    
    // ... (이하 로직 함수는 동일하나 saveUserData만 수정됨)
    func sendVerificationEmail() { /* 기존 코드 */
        let tempPassword = UUID().uuidString
        Auth.auth().createUser(withEmail: email, password: tempPassword) { result, error in
            if let error = error {
                alertTitle = "오류"; alertMessage = "인증 메일 전송 실패: \(error.localizedDescription)"; showAlert = true
            } else {
                guard let user = result?.user else { return }
                user.sendEmailVerification { error in
                    if let error = error {
                        alertTitle = "오류"; alertMessage = "발송 실패: \(error.localizedDescription)"; showAlert = true
                    } else {
                        alertTitle = "알림"; alertMessage = "본인인증 메일이 발송되었습니다.\n메일함을 확인해주세요."; showAlert = true
                        withAnimation { isVerificationSent = true }
                        startVerificationTimer()
                    }
                }
            }
        }
    }
    
    func startVerificationTimer() { /* 기존 코드 */
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Auth.auth().currentUser?.reload(completion: { error in
                if error == nil {
                    if let user = Auth.auth().currentUser, user.isEmailVerified {
                        withAnimation { isEmailVerified = true }
                        timer?.invalidate(); timer = nil
                    }
                }
            })
        }
    }
    
    func finalizeSignup() { /* 기존 코드 */
        guard password.count >= 6 else {
            alertTitle="알림"; alertMessage="비밀번호는 6자리 이상이어야 합니다."; showAlert=true; return
        }
        guard password == confirmPassword else {
            alertTitle="알림"; alertMessage="비밀번호가 일치하지 않습니다."; showAlert=true; return
        }
        guard isAgreed else {
            alertTitle="알림"; alertMessage="약관에 동의해주세요."; showAlert=true; return
        }
        
        guard let user = Auth.auth().currentUser else { return }
        
        user.updatePassword(to: password) { error in
            if let error = error {
                alertTitle="오류"; alertMessage="비밀번호 설정 실패: \(error.localizedDescription)"; showAlert=true
            } else {
                saveUserData(uid: user.uid)
            }
        }
    }
    
    // ✨ 수정됨: 닉네임 저장 추가
    func saveUserData(uid: String) {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "uid": uid,
            "email": email,
            "nickname": nickname, // ✨ 닉네임 저장
            "university": selectedUniversity,
            "joinDate": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).setData(userData) { error in
            if let error = error {
                print("저장 실패: \(error.localizedDescription)")
            } else {
                try? Auth.auth().signOut()
                alertTitle = "가입 완료"; alertMessage = "회원가입이 완료되었습니다.\n로그인 화면에서 로그인해주세요."; isSuccess = true; showAlert = true
            }
        }
    }
    
    @ViewBuilder
    func secureInputField(title: String, text: Binding<String>) -> some View { /* 기존 코드 */
        VStack(alignment: .leading, spacing: 5) {
            SecureField(title, text: text)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                .textContentType(.oneTimeCode)
                .autocapitalization(.none)
        }
        .padding(.horizontal, 25)
    }
}

#Preview {
    SignUpView()
}
