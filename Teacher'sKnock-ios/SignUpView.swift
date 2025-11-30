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
    
    // ✨ 약관 동의 상태 변수 (추가됨)
    @State private var isAgreed = false
    
    // 인증 프로세스 상태 관리
    @State private var isEmailVerified = false
    @State private var isVerificationSent = false
    @State private var timer: Timer?
    
    // 알림창 상태
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
                        
                        // --- 1. 이메일 입력 및 인증 섹션 ---
                        VStack(alignment: .leading, spacing: 5) {
                            Text("이메일 주소")
                                .font(.caption).foregroundColor(.gray).padding(.leading, 5)
                            
                            HStack {
                                TextField("실제 사용 중인 이메일 입력", text: $email)
                                    .padding()
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .disabled(isVerificationSent)
                                
                                Button(action: sendVerificationEmail) {
                                    Text(isEmailVerified ? "완료" : (isVerificationSent ? "재전송" : "인증"))
                                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                                        .padding(.vertical, 13).padding(.horizontal, 15)
                                        .background(isEmailVerified ? Color.green : brandColor)
                                        .cornerRadius(8)
                                }
                                .disabled(isEmailVerified || email.isEmpty)
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
                        
                        // --- 2. 추가 정보 입력 (인증 후 표시) ---
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
                                
                                // ✨ 약관 동의 체크박스 (추가됨)
                                HStack(alignment: .top) {
                                    Button(action: { isAgreed.toggle() }) {
                                        Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isAgreed ? brandColor : .gray)
                                            .font(.title3)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("아래 약관에 동의합니다.")
                                            .font(.subheadline)
                                            .foregroundColor(.black)
                                        
                                        HStack(spacing: 0) {
                                            Link("이용약관", destination: URL(string: "https://www.google.com")!) // 나중에 노션 링크로 교체
                                                .foregroundColor(brandColor)
                                            Text(" 및 ")
                                                .foregroundColor(.gray)
                                            Link("개인정보 처리방침", destination: URL(string: "https://www.google.com")!) // 나중에 노션 링크로 교체
                                                .foregroundColor(brandColor)
                                        }
                                        .font(.caption)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 30)
                                .padding(.top, 10)
                                
                                // 최종 가입 버튼
                                Button(action: finalizeSignup) {
                                    Text("티노 시작하기")
                                        .frame(maxWidth: .infinity).padding()
                                        .background(isAgreed ? brandColor : Color.gray) // 동의 안 하면 회색
                                        .foregroundColor(.white).font(.headline).cornerRadius(8)
                                }
                                .disabled(!isAgreed) // 동의 안 하면 클릭 불가
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
            Button("확인") {
                if isSuccess { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // ... (이하 로직 함수들은 기존과 동일합니다. 편의를 위해 전체 포함)
    
    func sendVerificationEmail() {
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
    
    func startVerificationTimer() {
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
    
    func finalizeSignup() {
        guard password.count >= 6 else {
            alertTitle="알림"; alertMessage="비밀번호는 6자리 이상이어야 합니다."; showAlert=true; return
        }
        guard password == confirmPassword else {
            alertTitle="알림"; alertMessage="비밀번호가 일치하지 않습니다."; showAlert=true; return
        }
        // ✨ 약관 동의 체크 (한 번 더 확인)
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
    
    func saveUserData(uid: String) {
        let db = Firestore.firestore()
        let userData: [String: Any] = ["uid": uid, "email": email, "university": selectedUniversity, "joinDate": Timestamp(date: Date())]
        
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
    func inputField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField(title, text: text)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                .autocapitalization(.none)
        }
        .padding(.horizontal, 25)
    }
    
    @ViewBuilder
    func secureInputField(title: String, text: Binding<String>) -> some View {
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
