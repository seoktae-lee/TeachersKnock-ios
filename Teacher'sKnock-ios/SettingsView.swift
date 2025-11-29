import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // 알림창 상태 관리
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var alertMessage = ""
    @State private var showAlert = false // 일반 오류 메시지용
    
    var body: some View {
        NavigationStack {
            List {
                // 섹션 1: 계정 정보
                Section(header: Text("계정")) {
                    if let user = Auth.auth().currentUser {
                        HStack {
                            Text("이메일")
                            Spacer()
                            Text(user.email ?? "알 수 없음")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // 섹션 2: 로그아웃
                Section {
                    Button("로그아웃") {
                        showLogoutAlert = true
                    }
                    .foregroundColor(.blue)
                }
                .alert("로그아웃", isPresented: $showLogoutAlert) {
                    Button("취소", role: .cancel) { }
                    Button("로그아웃", role: .destructive) {
                        logout()
                    }
                } message: {
                    Text("정말 로그아웃 하시겠습니까?")
                }
                
                // 섹션 3: 회원 탈퇴 (심사 필수!)
                Section {
                    Button("회원 탈퇴") {
                        showDeleteAlert = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("위험 구역")
                } footer: {
                    Text("탈퇴 시 모든 데이터(목표, 일정, 기록)가 영구적으로 삭제됩니다.")
                }
                .alert("회원 탈퇴", isPresented: $showDeleteAlert) {
                    Button("취소", role: .cancel) { }
                    Button("탈퇴하기", role: .destructive) {
                        deleteAccount()
                    }
                } message: {
                    Text("정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
                }
            }
            .navigationTitle("설정")
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // 로그아웃 함수
    func logout() {
        do {
            try Auth.auth().signOut()
            authManager.isLoggedIn = false
        } catch let error {
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }
    
    // ✨ 회원 탈퇴 함수 (Firestore 데이터 + 계정 삭제)
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()
        
        // 1. Firestore 유저 데이터 삭제
        db.collection("users").document(uid).delete { error in
            if let error = error {
                alertMessage = "데이터 삭제 실패: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            // 2. Firebase Authentication 계정 삭제
            user.delete { error in
                if let error = error {
                    // 로그인한 지 오래되면 재인증이 필요할 수 있음 (보안 정책)
                    alertMessage = "계정 삭제 실패: 로그아웃 후 다시 로그인해서 시도해주세요.\n(\(error.localizedDescription))"
                    showAlert = true
                } else {
                    // 3. 성공 시 로그아웃 처리
                    print("회원 탈퇴 완료")
                    authManager.isLoggedIn = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}
