import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 학습 환경
                Section(header: Text("학습 환경")) {
                    NavigationLink(destination: SubjectManagementView()) {
                        Label("공부 과목 관리", systemImage: "books.vertical")
                    }
                    
                    // ✨ 알림 설정 버튼 (앱 설정 화면으로 바로 이동)
                    Button(action: {
                        // 아이폰의 설정 > 내 앱 화면으로 이동하는 URL
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }) {
                        HStack {
                            Label("알림 설정", systemImage: "bell")
                            Spacer()
                            Text("시스템 설정 이용")
                                .font(.caption)
                                .foregroundColor(.gray)
                            // 버튼임을 알리기 위한 화살표
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // 2. 앱 정보
                Section(header: Text("앱 정보")) {
                    HStack {
                        Label("현재 버전", systemImage: "info.circle")
                        Spacer()
                        Text("Ver \(appVersion)").foregroundColor(.gray)
                    }
                    
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Label("개인정보 처리방침", systemImage: "hand.raised")
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = "support@tnoapp.com"
                    }) {
                        Label("문의하기 (이메일 복사)", systemImage: "envelope")
                            .foregroundColor(.primary)
                    }
                }
                
                // 3. 계정
                Section(header: Text("계정")) {
                    HStack {
                        Label("로그인 계정", systemImage: "person.circle")
                        Spacer()
                        Text(Auth.auth().currentUser?.email ?? "이메일 없음")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // ✨ [New] 티처스노크 ID
                    HStack {
                        Label("티처스노크 ID", systemImage: "tag")
                        Spacer()
                        Text(authManager.userTeacherKnockID ?? "생성 중...")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let id = authManager.userTeacherKnockID {
                            Button(action: {
                                UIPasteboard.general.string = id
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless) // 리스트 내 버튼 동작 분리
                        }
                    }
                    
                    Button("로그아웃") { showingLogoutAlert = true }
                        .foregroundColor(.red)
                        .alert("로그아웃", isPresented: $showingLogoutAlert) {
                            Button("취소", role: .cancel) {}
                            Button("로그아웃", role: .destructive) {
                                authManager.signOut()
                            }
                        } message: { Text("정말 로그아웃 하시겠습니까?") }
                    
                    Button("회원 탈퇴") { showingDeleteAccountAlert = true }
                        .foregroundColor(.red)
                        .alert("회원 탈퇴", isPresented: $showingDeleteAccountAlert) {
                            Button("취소", role: .cancel) {}
                            Button("탈퇴하기", role: .destructive) {
                                authManager.deleteAccount { success, error in
                                    if !success {
                                        errorMessage = "탈퇴에 실패했습니다.\n보안을 위해 로그아웃 후 다시 로그인해서 시도해주세요."
                                        if let err = error {
                                            print("Error details: \(err)")
                                        }
                                        showingErrorAlert = true
                                    }
                                }
                            }
                        } message: {
                            Text("모든 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
                        }
                }
            }
            .navigationTitle("설정")
            .listStyle(.insetGrouped)
            .alert("알림", isPresented: $showingErrorAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}
