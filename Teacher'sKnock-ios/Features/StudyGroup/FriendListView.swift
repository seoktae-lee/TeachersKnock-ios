import SwiftUI
import FirebaseAuth

struct FriendListView: View {
    @StateObject private var friendManager = FriendManager()
    @EnvironmentObject var authManager: AuthManager
    // ✨ [New] 친구 신청 매니저 (MainTabView에서 주입받거나, 여기서 생성 후 상위 연결)
    // 친구 목록 내에서만 쓰이므로 여기서 생성해도 되지만, 뱃지 연동을 위해선 MainTabView에서 받아야 함.
    // 하지만 현재 구조상 StudyGroupListView -> Segmented Control -> FriendListView로 이어지므로
    // depth가 깊어질 수 있음. 우선 MainTabView에서 주입받는 구조로 변경.
    @ObservedObject var requestManager: FriendRequestManager
    
    @State private var showingAddFriendSheet = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // ✨ [Modified] 로딩 상태 처리
            if friendManager.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if friendManager.friends.isEmpty && requestManager.receivedRequests.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // ✨ [New] 받은 친구 신청 섹션
                        if !requestManager.receivedRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("받은 친구 신청")
                                    .font(.headline)
                                    .foregroundColor(.green) // 초록색으로 구분
                                    .padding(.leading, 5)
                                
                                ForEach(requestManager.receivedRequests) { request in
                                    FriendRequestRow(request: request, requestManager: requestManager, friendManager: friendManager)
                                }
                            }
                            .padding(.bottom, 10)
                        }
                        
                        // 친구 목록
                        ForEach(friendManager.friends) { friend in
                            FriendRow(friend: friend) {
                                deleteFriend(friend)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddFriendSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                            .clipShape(Circle())
                            .shadow(radius: 4, y: 4)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                friendManager.observeFriends(myUID: uid)
                // requestManager는 MainTabView에서 듣고 있을 것이므로 여기서 listen 호출 X
            }
        }
        .sheet(isPresented: $showingAddFriendSheet) {
            if let uid = Auth.auth().currentUser?.uid {
                AddFriendView(friendManager: friendManager, myUID: uid)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("아직 등록된 친구가 없어요")
                .font(.title3.bold())
                .foregroundColor(.gray)
            
            Text("함께 공부할 친구를 추가하고\n서로 노크해보세요!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .font(.caption)
            
            Button(action: { showingAddFriendSheet = true }) {
                Text("친구 추가하기")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .cornerRadius(20)
            }
        }
    }
    // ✨ [New] 친구 삭제 로직
    func deleteFriend(_ friend: User) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        friendManager.removeFriend(myUID: myUID, friendUID: friend.id) { success in
            // 성공 시 UI 자동 업데이트 됨 (FriendManager의 리스너 및 removeFriend 내부 로직)
        }
    }
}

// ✨ [New] 친구 신청 Row
struct FriendRequestRow: View {
    let request: FriendRequest
    @ObservedObject var requestManager: FriendRequestManager
    @ObservedObject var friendManager: FriendManager
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundColor(.green)
                
                Text("친구 신청")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(timeString(from: request.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text("\(request.senderName)님이 친구 신청을 보냈어요!")
                .font(.body.bold())
            
            HStack(spacing: 10) {
                Button(action: {
                    isProcessing = true
                    requestManager.declineRequest(request)
                }) {
                    Text("거절")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    requestManager.acceptRequest(request, friendManager: friendManager) { success in
                        isProcessing = false
                    }
                }) {
                    Text("수락")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green) // 초록색 버튼
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    func timeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FriendRow: View {
    let friend: User
    let onRemoveFriend: () -> Void // ✨ [New] 삭제 액션 전달
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Icon
            ZStack(alignment: .bottomTrailing) {
                // ✨ [New] 공통 컴포넌트 사용
                ProfileImageView(user: friend, size: 50)
                
                // 4. 공부 중 뱃지 (Overlay)
                if friend.isStudying {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.nickname)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let univ = friend.university {
                    Text(univ)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if friend.isStudying {
                Text("🔥 공부 중")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .cornerRadius(12)
            } else {
                Text("ID: \(friend.teacherKnockID ?? "-")")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        // ✨ [New] 친구 끊기 메뉴
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("친구 끊기", systemImage: "person.fill.xmark")
            }
        }
        .alert("친구 끊기", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("끊기", role: .destructive) {
                onRemoveFriend()
            }
        } message: {
            Text("'\(friend.nickname)'님과 친구를 끊으시겠습니까?\n서로의 친구 목록에서 사라집니다.")
        }
    }
}
