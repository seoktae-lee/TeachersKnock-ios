import SwiftUI

struct CheerBoardView: View {
    let groupID: String
    @ObservedObject var studyManager: StudyGroupManager
    @State private var newCheerText: String = ""
    @AppStorage("lastCheerDate") private var lastCheerDate: Double = 0
    
    // 오늘의 한마디 (최신 3개만 표시)
    var recentCheers: [Cheer] {
        let all = studyManager.cheers[groupID] ?? []
        return Array(all.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("오늘의 한마디", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            // 입력창
            HStack {
                TextField("멤버들에게 응원의 한마디! (50자 이내)", text: $newCheerText)
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .submitLabel(.send)
                    .onSubmit {
                        submitCheer()
                    }
                
                Button(action: submitCheer) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .padding(8)
                }
                .disabled(newCheerText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 5)
            
            if recentCheers.isEmpty {
                Text("아직 등록된 응원이 없습니다. 첫 번째 응원을 남겨보세요!")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentCheers) { cheer in
                        HStack(alignment: .top, spacing: 8) {
                            Text(cheer.userNickname)
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            
                            Text(cheer.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Text(timeAgo(date: cheer.createdAt))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .onAppear {
            studyManager.listenToCheers(groupID: groupID)
        }
        .onDisappear {
            studyManager.removeCheerListener(groupID: groupID)
        }
    }
    
    func submitCheer() {
        let text = newCheerText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        // 간단한 닉네임 가져오기 (UserDefault 등에서 캐시된 닉네임 사용하거나 Auth에서)
        // 여기서는 StudyGroupDetailView에서 넘겨받지 않았으므로, 
        // Manager가 내부적으로 Auth.currentUser를 쓰지만 닉네임은 DB에서 가져와야 함.
        // 편의상 임시 닉네임 처리 혹은 Manager가 User 정보를 알고 있어야 함.
        
        // 하지만 StudyGroupDetailView는 User 정보를 가지고 있지 않을 수 있음 (Leader가 아닌 경우)
        // -> StudyManager에서 fetchMyProfile을 하거나, 호출하는 쪽에서 닉네임 전달 필요.
        // 현재 구조상 User 객체가 View에 없을 수 있음.
        // 개선: StudyGroupDetailView가 내 User 정보를 가지고 있어야 함.
        
        // 임시: "나"
        // 실제로는 닉네임이 필요하므로, 호출부에서 주입받는게 좋음. 
        // -> StudyGroupDetailView에 'me' 프로퍼티 추가 예정.
        
        // 일단 empty string으로 보내면 Manager가 처리하거나, 여기서 처리?
        // Manager.addCheer는 nickname을 인자로 받음.
        // 닉네임 확보가 어려우니, 일단 "익명" 혹은 UserDefaults에서 가져옴
        let myNickname = UserDefaults.standard.string(forKey: "userNickname") ?? "알 수 없음"
        
        studyManager.addCheer(groupID: groupID, nickname: myNickname, text: text) { success in
            if success {
                newCheerText = ""
            }
        }
    }
    
    func timeAgo(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
