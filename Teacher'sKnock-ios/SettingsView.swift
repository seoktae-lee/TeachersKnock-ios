import SwiftUI
import FirebaseAuth
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.modelContext) private var modelContext
    
    // 탈퇴 경고창 상태
    @State private var showDeleteAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 프로필
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable().frame(width: 50, height: 50)
                            .foregroundColor(.gray.opacity(0.5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userNickname).font(.headline)
                            if let email = Auth.auth().currentUser?.email {
                                Text(email).font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 2. 학습 설정
                Section(header: Text("학습 설정")) {
                    NavigationLink(destination: SubjectSelectView()) {
                        HStack {
                            Image(systemName: "book.closed.fill").foregroundColor(.blue)
                            Text("선호 과목 설정")
                        }
                    }
                    NavigationLink(destination: Text("준비 중인 기능입니다.")) {
                        HStack {
                            Image(systemName: "target").foregroundColor(.red)
                            Text("디데이/목표 관리")
                        }
                    }
                }
                
                // 3. 앱 정보
                Section(header: Text("앱 정보")) {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(appVersion).foregroundColor(.gray)
                    }
                    Link("이용약관", destination: URL(string: "https://www.google.com")!)
                    Link("개인정보 처리방침", destination: URL(string: "https://www.google.com")!)
                }
                
                // 4. 계정 관리
                Section {
                    Button("로그아웃") { try? Auth.auth().signOut() }
                        .foregroundColor(.primary)
                    
                    Button("회원탈퇴") { showDeleteAlert = true }
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("설정")
            .alert("정말 탈퇴하시겠습니까?", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("탈퇴하기", role: .destructive) { performDeleteAccount() }
            } message: {
                // ✨ [수정됨] 파이어베이스 언급 삭제 -> 더 깔끔한 문구로 변경
                Text("탈퇴 시 모든 학습 기록과 설정이 영구 삭제되며, 복구할 수 없습니다.")
            }
            .alert("오류", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func performDeleteAccount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            // 1. 내 ScheduleItem 삭제
            let scheduleDescriptor = FetchDescriptor<ScheduleItem>(predicate: #Predicate { $0.ownerID == uid })
            let schedules = try modelContext.fetch(scheduleDescriptor)
            for item in schedules { modelContext.delete(item) }
            
            // 2. 내 StudyRecord 삭제
            let recordDescriptor = FetchDescriptor<StudyRecord>(predicate: #Predicate { $0.ownerID == uid })
            let records = try modelContext.fetch(recordDescriptor)
            for record in records { modelContext.delete(record) }
            
            // 3. 내 Goal 삭제
            let goalDescriptor = FetchDescriptor<Goal>(predicate: #Predicate { $0.ownerID == uid })
            let goals = try modelContext.fetch(goalDescriptor)
            for goal in goals { modelContext.delete(goal) }
            
            print("로컬 데이터 삭제 완료")
        } catch {
            print("삭제 실패: \(error)")
        }
        
        // 4. 서버 계정 삭제
        authManager.deleteAccount { success, error in
            if !success {
                errorMessage = error?.localizedDescription ?? "알 수 없는 오류"
                showErrorAlert = true
            }
        }
    }
}
