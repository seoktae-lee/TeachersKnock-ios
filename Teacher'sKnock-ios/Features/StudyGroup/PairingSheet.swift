import SwiftUI
import FirebaseAuth

struct PairingSheet: View {
    @Environment(\.dismiss) var dismiss
    let group: StudyGroup
    let isLeader: Bool // 방장 여부
    @ObservedObject var studyManager: StudyGroupManager
    
    // 매칭 결과 (ID 배열의 배열)
    // view load 시 group.pairs에서 가져오거나, 새로 생성된 결과
    @State private var currentPairs: [[String]] = []
    
    // 매칭 상태
    @State private var hasMatchedToday = false
    @State private var selectedSplitType: StudyGroupManager.PairSplitType = .twoTwoTwo // 기본값
    
    // UI
    @State private var showingSplitSelection = false // 6명일 때 분기 선택
    
    var body: some View {
        NavigationStack {
            VStack {
                if hasMatchedToday && !currentPairs.isEmpty {
                    // MARK: - 매칭 결과 표시
                    ScrollView {
                        VStack(spacing: 20) {
                            Text(dateString(for: group.lastPairingDate ?? Date()))
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top)
                            
                            Text("오늘의 짝 스터디 그룹을 확인하세요!")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            // 결과 리스트
                            ForEach(0..<currentPairs.count, id: \.self) { index in
                                let pairIDs = currentPairs[index]
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .foregroundColor(.blue)
                                        Text("Group \(index + 1)")
                                            .font(.headline)
                                    }
                                    
                                    // 멤버 표시
                                    HStack(spacing: 15) {
                                        ForEach(pairIDs, id: \.self) { uid in
                                            if let user = studyManager.groupMembersData[group.id]?.first(where: { $0.id == uid }) {
                                                VStack {
                                                    ProfileImageView(user: user, size: 50)
                                                    Text(user.nickname)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                }
                                            } else {
                                                // 로딩 안된 경우 (그럴 일은 드물지만)
                                                VStack {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 50, height: 50)
                                                    Text("로딩중")
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    // MARK: - 매칭 전 (방장만 가능)
                    VStack(spacing: 30) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.top, 50)
                        
                        Text("오늘의 짝 스터디 매칭")
                            .font(.title.bold())
                        
                        Text("랜덤으로 스터디 짝을 지어드려요.\n스터디 시작 전, 오늘의 파트너를 확인해보세요!")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if isLeader {
                            Button(action: {
                                if group.memberCount == 6 {
                                    showingSplitSelection = true
                                } else {
                                    startMatching(splitType: .standard)
                                }
                            }) {
                                Text("지금 매칭하기")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal)
                            
                            Text("매칭은 하루에 한 번만 가능하며, 결과는 모든 멤버에게 공유됩니다.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)
                        } else {
                            Text("아직 방장님이 오늘의 매칭을 진행하지 않았습니다.")
                                .font(.body)
                                .foregroundColor(.gray)
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("짝 스터디")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkTodayMatching()
            }
            // 6명일 때 선택 시트
            .confirmationDialog("팀 구성 방식을 선택해주세요", isPresented: $showingSplitSelection, titleVisibility: .visible) {
                Button("2명 / 2명 / 2명") {
                    startMatching(splitType: .twoTwoTwo)
                }
                Button("3명 / 3명") {
                    startMatching(splitType: .threeThree)
                }
                Button("취소", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Logic
    
    func checkTodayMatching() {
        if let lastDate = group.lastPairingDate, Calendar.current.isDateInToday(lastDate), let pairs = group.pairs {
            self.hasMatchedToday = true
            self.currentPairs = pairs
        } else {
            self.hasMatchedToday = false
            self.currentPairs = []
        }
    }
    
    func startMatching(splitType: StudyGroupManager.PairSplitType) {
        let members = group.members
        // 1. 매칭 생성
        let newPairs = studyManager.generatePairs(members: members, splitType: splitType)
        
        // 2. 서버 업데이트
        studyManager.updatePairs(groupID: group.id, pairs: newPairs) { success in
            if success {
                self.hasMatchedToday = true
                self.currentPairs = newPairs
            }
        }
    }
    
    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}
