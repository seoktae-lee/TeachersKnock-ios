import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 학습 환경
                Section(header: Text("학습 환경")) {
                    // ✨ [수정됨] SubjectManagementView는 파라미터 없이 호출
                    NavigationLink(destination: SubjectManagementView()) {
                        Label("공부 과목 관리", systemImage: "books.vertical")
                    }
                    
                    HStack {
                        Label("알림 설정", systemImage: "bell")
                        Spacer()
                        Text("시스템 설정 이용").font(.caption).foregroundColor(.gray)
                    }
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
                        // ✨ [수정됨] AuthManager가 아니라 Firebase에서 직접 이메일 가져오기 (안전함)
                        Text(Auth.auth().currentUser?.email ?? "이메일 없음")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // ✨ [수정됨] 로그아웃 버튼 (문법 오류 해결)
                    Button("로그아웃") {
                        showingLogoutAlert = true
                    }
                    .foregroundColor(.red)
                    .alert("로그아웃", isPresented: $showingLogoutAlert) {
                        Button("취소", role: .cancel) {}
                        Button("로그아웃", role: .destructive) {
                            // AuthManager에 signOut이 없어도 직접 호출 가능
                            authManager.signOut()
                        }
                    } message: {
                        Text("정말 로그아웃 하시겠습니까?")
                    }
                    
                    // ✨ [수정됨] 회원 탈퇴 버튼
                    Button("회원 탈퇴") {
                        showingDeleteAccountAlert = true
                    }
                    .foregroundColor(.red)
                    .alert("회원 탈퇴", isPresented: $showingDeleteAccountAlert) {
                        Button("취소", role: .cancel) {}
                        Button("탈퇴하기", role: .destructive) {
                            authManager.deleteAccount()
                        }
                    } message: {
                        Text("모든 데이터가 삭제되며 되돌릴 수 없습니다.")
                    }
                }
            }
            .navigationTitle("설정")
            .listStyle(.insetGrouped)
        }
    }
}
