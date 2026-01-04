import SwiftUI
import FirebaseAuth

struct FriendListView: View {
    @StateObject private var friendManager = FriendManager()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingAddFriendSheet = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            if friendManager.friends.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(friendManager.friends) { friend in
                            FriendRow(friend: friend)
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
}

struct FriendRow: View {
    let friend: User
    
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
    }
}
