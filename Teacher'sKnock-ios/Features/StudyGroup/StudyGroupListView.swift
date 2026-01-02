import SwiftUI
import FirebaseAuth

struct StudyGroupListView: View {
    @StateObject private var studyManager = StudyGroupManager()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if studyManager.myGroups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(studyManager.myGroups) { group in
                                NavigationLink(destination: StudyGroupDetailView(group: group, studyManager: studyManager)) {
                                    StudyGroupRow(group: group)
                                }
                                .buttonStyle(PlainButtonStyle())
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
                        Button(action: { showingCreateSheet = true }) {
                            Image(systemName: "plus")
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
            .navigationTitle("스터디 그룹")
            .onAppear {
                if let uid = Auth.auth().currentUser?.uid {
                    studyManager.fetchMyGroups(uid: uid)
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                StudyGroupCreationView(studyManager: studyManager)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("아직 가입한 스터디가 없어요")
                .font(.title3.bold())
                .foregroundColor(.gray)
            
            Text("새로운 스터디를 만들고\n친구들을 초대해보세요!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .font(.caption)
            
            Button(action: { showingCreateSheet = true }) {
                Text("스터디 만들기")
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

struct StudyGroupRow: View {
    let group: StudyGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(group.memberCount)/\(group.maxMembers)")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
