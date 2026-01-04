import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

// 단계별 상태 관리
enum SignUpStep: Int, CaseIterable {
    case terms = 0
    case email = 1
    case password = 2
    case profile = 3
}

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // 상태 관리
    @State private var currentStep: SignUpStep = .terms
    @State private var isNextButtonEnabled = false
    
    // Data Binding
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""
    @State private var selectedUniversity = University.allList.first?.name ?? "서울교육대학교"
    @State private var isAgreed = false
    
    // Verification State
    @State private var isVerificationSent = false
    @State private var isEmailVerified = false
    @State private var verificationTimer: Timer?
    @State private var timerCount = 0
    
    // Check State
    @State private var nicknameCheckStatus: NicknameCheckStatus = .none
    
    // Alert
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    enum NicknameCheckStatus {
        case none, checking, available, duplicate, error
    }
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    private let tempAuthPassword = "TinoTempPassword123!"
    
    var body: some View {
        NavigationStack {
            VStack {
                // 상단 진행 바
                SignUpProgressBar(currentStep: currentStep)
                    .padding(.top, 20)
                
                // 메인 콘텐츠
                TabView(selection: $currentStep) {
                    termsView.tag(SignUpStep.terms)
                    emailAuthView.tag(SignUpStep.email)
                    passwordView.tag(SignUpStep.password)
                    profileView.tag(SignUpStep.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // 스와이프 방지는 아래에서 처리하거나 제스처 막기
                .animation(.easeInOut, value: currentStep)
                
                // 하단 내비게이션 버튼
                HStack {
                    if currentStep != .terms {
                        Button("이전") {
                            withAnimation {
                                currentStep = SignUpStep(rawValue: currentStep.rawValue - 1) ?? .terms
                            }
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: handleNextButton) {
                        Text(currentStep == .profile ? "가입 완료" : "다음")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 100, height: 44)
                            .background(isNextButtonEnabled ? brandColor : Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .disabled(!isNextButtonEnabled)
                }
                .padding()
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: currentStep) { _ in validateCurrentStep() }
            .onChange(of: isAgreed) { _ in validateCurrentStep() }
            .onChange(of: isEmailVerified) { _ in validateCurrentStep() }
            .onChange(of: password) { _ in validateCurrentStep() }
            .onChange(of: confirmPassword) { _ in validateCurrentStep() }
            .onChange(of: nicknameCheckStatus) { _ in validateCurrentStep() }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("확인") {
                if isSuccess { dismiss() }
            }
        } message: { Text(alertMessage) }
        .onDisappear { verificationTimer?.invalidate() }
    }
    
    var stepTitle: String {
        switch currentStep {
        case .terms: return "약관 동의"
        case .email: return "이메일 인증"
        case .password: return "비밀번호 설정"
        case .profile: return "프로필 설정"
        }
    }
    
    // MARK: - Step Views
    
    // 1. 약관 동의
    var termsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Teacher's Knock에\n오신 것을 환영합니다!")
                .font(.title).fontWeight(.bold)
                .padding(.top, 30)
            
            Text("원활한 서비스 이용을 위해 약관 동의가 필요합니다.")
                .foregroundColor(.gray)
            
            Spacer()
            
            HStack(alignment: .top) {
                Button(action: {
                    isAgreed.toggle()
                }) {
                    Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                        .foregroundColor(isAgreed ? brandColor : .gray)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("필수 약관에 동의합니다").font(.headline)
                    HStack(spacing: 0) {
                        Link("서비스 이용약관", destination: URL(string: "https://www.google.com")!).foregroundColor(brandColor)
                        Text(" 및 ").foregroundColor(.gray)
                        Link("개인정보 처리방침", destination: URL(string: "https://www.google.com")!).foregroundColor(brandColor)
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).stroke(isAgreed ? brandColor : Color.gray.opacity(0.3), lineWidth: 1))
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    // 2. 이메일 인증
    var emailAuthView: some View {
        VStack(spacing: 25) {
            VStack(alignment: .leading, spacing: 5) {
                Text("학교 이메일 또는 사용 중인 이메일").font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("example@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isVerificationSent)
                    
                    if isEmailVerified {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(brandColor, lineWidth: 1))
            }
            
            if !isEmailVerified {
                Button(action: requestEmailVerification) {
                    Text(isVerificationSent ? "인증 메일 재전송" : "인증 메일 보내기")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(email.isEmpty)
            }
            
            if isVerificationSent && !isEmailVerified {
                VStack(alignment: .leading, spacing: 10) {
                    Text("📩 인증 메일이 발송되었습니다!")
                        .font(.headline).foregroundColor(brandColor)
                    
                    Text("메일함에서 인증 링크를 클릭해주세요.\n인증이 완료되면 자동으로 다음 단계로 넘어갑니다.")
                        .font(.caption).foregroundColor(.gray)
                    
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("메일이 안 보이나요?\nGoogle(Gmail)의 경우 '스팸함'이나 '프로모션' 탭에 있을 수 있습니다.")
                            .font(.caption).foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding(30)
    }
    
    // 3. 비밀번호 설정
    var passwordView: some View {
        VStack(spacing: 20) {
            Text("로그인에 사용할\n비밀번호를 설정해주세요.")
                .font(.title2).fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
            
            SecureField("비밀번호 (6자리 이상)", text: $password)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            
            SecureField("비밀번호 확인", text: $confirmPassword)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            
            if !password.isEmpty && !confirmPassword.isEmpty {
                if password == confirmPassword && password.count >= 6 {
                    Text("✅ 사용 가능한 비밀번호입니다.").font(.caption).foregroundColor(.green)
                } else if password.count < 6 {
                    Text("❌ 비밀번호는 6자리 이상이어야 합니다.").font(.caption).foregroundColor(.red)
                } else {
                    Text("❌ 비밀번호가 일치하지 않습니다.").font(.caption).foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding(30)
    }
    
    // 4. 프로필 설정 (별명 + 대학교)
    var profileView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 별명
                VStack(alignment: .leading, spacing: 5) {
                    Text("별명 (스터디 그룹 ID로 사용됩니다)").font(.caption).foregroundColor(.gray)
                    
                    HStack {
                        TextField("예: 합격이", text: $nickname)
                            .autocapitalization(.none)
                            .onChange(of: nickname) { _ in
                                nicknameCheckStatus = .none // 변경 시 상태 초기화
                            }
                        
                        Button(action: checkNickname) {
                            Text("중복확인")
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(nickname.isEmpty ? Color.gray : brandColor)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                        .disabled(nickname.isEmpty)
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                        nicknameCheckStatus == .duplicate ? Color.red : (nicknameCheckStatus == .available ? Color.green : Color.gray.opacity(0.4)),
                        lineWidth: 1
                    ))
                    
                    // 상태 메시지
                    switch nicknameCheckStatus {
                    case .checking:
                        Text("확인 중...").font(.caption).foregroundColor(.gray)
                    case .available:
                        Text("✅ 사용 가능한 별명입니다.").font(.caption).foregroundColor(.green)
                    case .duplicate:
                        Text("❌ 이미 존재하는 별명입니다. 다른 별명을 사용해주세요.").font(.caption).foregroundColor(.red)
                    case .error:
                        Text("⚠️ 확인 중 오류가 발생했습니다.").font(.caption).foregroundColor(.red)
                    case .none:
                        EmptyView()
                    }
                }
                
                // 대학교
                VStack(alignment: .leading, spacing: 5) {
                    Text("소속 대학교").font(.caption).foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "building.columns").foregroundColor(.gray)
                        Picker("대학교 선택", selection: $selectedUniversity) {
                            ForEach(University.allList, id: \.name) { uni in
                                Text(uni.name).tag(uni.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(.black)
                        Spacer()
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
    
    // MARK: - Logic
    
    func validateCurrentStep() {
        switch currentStep {
        case .terms:
            isNextButtonEnabled = isAgreed
        case .email:
            isNextButtonEnabled = isEmailVerified
        case .password:
            isNextButtonEnabled = !password.isEmpty && password.count >= 6 && password == confirmPassword
        case .profile:
            // 별명 중복 확인 완료 + 닉네임 있음
            isNextButtonEnabled = !nickname.isEmpty && nicknameCheckStatus == .available
        }
    }
    
    func handleNextButton() {
        if currentStep == .profile {
            finalizeSignup()
        } else {
            withAnimation {
                currentStep = SignUpStep(rawValue: currentStep.rawValue + 1) ?? .profile
            }
        }
    }
    
    // 이메일 인증 요청
    func requestEmailVerification() {
        Auth.auth().createUser(withEmail: email, password: tempAuthPassword) { result, error in
            if let error = error as NSError? {
                if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    // 이미 가입된 경우 -> 임시 로그인 시도 후 메일 재전송
                    Auth.auth().signIn(withEmail: email, password: tempAuthPassword) { result, error in
                        if error == nil {
                            sendVerificationMail(user: result?.user)
                        } else {
                            alertTitle = "알림"; alertMessage = "이미 가입된 이메일입니다. 로그인해주세요."; showAlert = true
                        }
                    }
                } else {
                    alertTitle = "오류"; alertMessage = error.localizedDescription; showAlert = true
                }
            } else {
                sendVerificationMail(user: result?.user)
            }
        }
    }
    
    func sendVerificationMail(user: FirebaseAuth.User?) {
        guard let user = user else { return }
        user.sendEmailVerification { error in
            if let error = error {
                alertTitle = "오류"; alertMessage = "메일 발송 실패: \(error.localizedDescription)"; showAlert = true
            } else {
                withAnimation { isVerificationSent = true }
                startVerificationTimer()
            }
        }
    }
    
    func startVerificationTimer() {
        verificationTimer?.invalidate()
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Auth.auth().currentUser?.reload(completion: { error in
                if error == nil {
                    if let user = Auth.auth().currentUser, user.isEmailVerified {
                        withAnimation { isEmailVerified = true }
                        verificationTimer?.invalidate()
                        // 자동 다음 단계 이동 (선택사항)
                         if currentStep == .email {
                             handleNextButton()
                         }
                    }
                }
            })
        }
    }
    
    // 별명 중복 확인
    func checkNickname() {
        guard !nickname.isEmpty else { return }
        nicknameCheckStatus = .checking
        
        authManager.checkNicknameDuplicate(nickname: nickname) { isDuplicate in
            DispatchQueue.main.async {
                if isDuplicate {
                    nicknameCheckStatus = .duplicate
                } else {
                    nicknameCheckStatus = .available
                }
                validateCurrentStep() // 버튼 상태 갱신
            }
        }
    }
    
    // 최종 가입 완료
    func finalizeSignup() {
        guard let user = Auth.auth().currentUser else { return }
        
        user.updatePassword(to: password) { error in
            if let error = error {
                alertTitle = "오류"; alertMessage = "비밀번호 설정 실패: \(error.localizedDescription)"; showAlert = true
            } else {
                saveUserData(uid: user.uid)
            }
        }
    }
    
    func saveUserData(uid: String) {
        // ✨ [핵심] 저장 전에 티처스노크 ID 생성
        authManager.generateUniqueTeacherKnockID { generatedID in
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "uid": uid,
                "email": self.email,
                "nickname": self.nickname,
                "university": self.selectedUniversity,
                "teacherKnockID": generatedID, // [New] ID 추가
                "joinDate": Timestamp(date: Date())
            ]
            
            db.collection("users").document(uid).setData(userData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("저장 실패: \(error.localizedDescription)")
                    } else {
                        try? Auth.auth().signOut()
                        self.alertTitle = "가입 완료"
                        self.alertMessage = "회원가입이 완료되었습니다!\n(ID: \(generatedID))\n로그인 화면으로 이동합니다."
                        self.isSuccess = true
                        self.showAlert = true
                    }
                }
            }
        }
    }
}

// 상단 진행 바
struct SignUpProgressBar: View {
    var currentStep: SignUpStep
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(SignUpStep.allCases, id: \.self) { step in
                HStack(spacing: 0) {
                    Circle()
                        .fill(currentStep.rawValue >= step.rawValue ? Color(red: 0.35, green: 0.65, blue: 0.95) : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    
                    if step != .profile {
                        Rectangle()
                            .fill(currentStep.rawValue > step.rawValue ? Color(red: 0.35, green: 0.65, blue: 0.95) : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 50)
    }
}

#Preview {
    SignUpView()
}
