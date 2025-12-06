import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // ✨ [수정됨] 초기값을 'University.allList'의 첫 번째로 설정 (하드코딩 방지)
    @State private var selectedUniversity = University.allList.first?.name ?? "서울교육대학교"
    
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
    private let tempAuthPassword = "TinoTempPassword123!"
    
    // ⚠️ 기존 하드코딩 배열 삭제됨 (NoticeData.swift의 University.allList 사용)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("회원가입")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(brandColor).padding(.top, 30)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 1. 이메일 & 닉네임 입력 (기존 동일)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("닉네임").font(.caption).foregroundColor(.gray).padding(.leading, 5)
                            TextField("앱에서 사용할 이름 (예: 합격이)", text: $nickname)
                                .padding()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                .autocapitalization(.none)
                                .disabled(isVerificationSent)
                                .padding(.bottom, 10)
                            
                            Text("이메일 주소").font(.caption).foregroundColor(.gray).padding(.leading, 5)
                            
                            HStack {
                                ZStack(alignment: .leading) {
                                    if email.isEmpty { Text("예: teacher@example.com").foregroundColor(.gray.opacity(0.6)) }
                                    TextField("", text: $email)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .disabled(isVerificationSent)
                                }
                                .padding()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                
                                Button(action: handleVerificationRequest) {
                                    Text(isEmailVerified ? "완료" : (isVerificationSent ? "재전송" : "인증"))
                                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                                        .padding(.vertical, 13).padding(.horizontal, 15)
                                        .background(isEmailVerified ? Color.green : brandColor)
                                        .cornerRadius(8)
                                }
                                .disabled(isEmailVerified || email.isEmpty || nickname.isEmpty)
                            }
                            
                            if isVerificationSent && !isEmailVerified {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("📩 인증 메일이 발송되었습니다.")
                                        .font(.subheadline).fontWeight(.semibold).foregroundColor(brandColor).padding(.leading, 2)
                                    
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.bubble.fill").foregroundColor(.orange).font(.title3).padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("메일이 도착하지 않았나요?").font(.caption).fontWeight(.bold).foregroundColor(.black.opacity(0.8))
                                            Text("구글(Gmail)의 경우 스팸함으로 분류될 수 있습니다.\n스팸함을 꼭 확인해주세요!").font(.caption).foregroundColor(.gray).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.08)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                                }
                                .padding(.top, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            } else if isEmailVerified {
                                Text("✅ 본인 인증이 완료되었습니다. 비밀번호를 설정해주세요.")
                                    .font(.caption).foregroundColor(.green).padding(.leading, 5)
                            }
                        }
                        .padding(.horizontal, 25)
                        
                        // 2. 비밀번호 & 대학 입력 (인증 후)
                        if isEmailVerified {
                            VStack(spacing: 20) {
                                Divider().padding(.vertical, 10)
                                secureInputField(title: "비밀번호 설정 (6자리 이상)", text: $password)
                                secureInputField(title: "비밀번호 확인", text: $confirmPassword)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("소속 대학교").font(.caption).foregroundColor(.gray).padding(.leading, 5)
                                    HStack {
                                        Image(systemName: "building.columns").foregroundColor(.gray)
                                        
                                        // ✨ [수정됨] NoticeData의 University.allList 사용
                                        Picker("대학교 선택", selection: $selectedUniversity) {
                                            ForEach(University.allList, id: \.name) { uni in
                                                Text(uni.name).tag(uni.name)
                                            }
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
                                            .foregroundColor(isAgreed ? brandColor : .gray).font(.title3)
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
                                    Text("Teacher's Knock와 합격으로")
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
    
    // ... (이하 로직 함수들은 기존과 동일합니다. 그대로 두세요.) ...
    
    func handleVerificationRequest() {
        Auth.auth().createUser(withEmail: email, password: tempAuthPassword) { result, error in
            if let error = error as NSError? {
                if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    Auth.auth().signIn(withEmail: email, password: tempAuthPassword) { result, error in
                        if let _ = error {
                            alertTitle = "알림"; alertMessage = "이미 가입된 이메일입니다.\n로그인 화면에서 로그인해주세요."; showAlert = true
                        } else {
                            sendMail(user: result?.user)
                        }
                    }
                } else {
                    alertTitle = "오류"; alertMessage = error.localizedDescription; showAlert = true
                }
            } else {
                sendMail(user: result?.user)
            }
        }
    }
    
    func sendMail(user: User?) {
        guard let user = user else { return }
        user.sendEmailVerification { error in
            if let error = error {
                alertTitle = "오류"; alertMessage = "메일 발송 실패: \(error.localizedDescription)"; showAlert = true
            } else {
                alertTitle = "알림"; alertMessage = "인증 메일이 발송되었습니다.\n(스팸함을 꼭 확인해주세요!)"; showAlert = true
                withAnimation { isVerificationSent = true }
                startVerificationTimer()
            }
        }
    }
    
    func startVerificationTimer() {
        timer?.invalidate()
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
        let userData: [String: Any] = [
            "uid": uid,
            "email": email,
            "nickname": nickname,
            // ✨ 선택된 대학교 이름이 저장됨 (University.allList에 있는 정확한 이름)
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
