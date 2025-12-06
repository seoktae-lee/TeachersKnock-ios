import SwiftUI
import SafariServices

struct NoticeListView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager // ✨ AuthManager 직접 사용
    
    @State private var showSettings = false
    @State private var selectedUrl: URL?
    
    // ✨ 내 대학교 버튼 자동 생성 로직
    var myUniversityLink: University? {
        // AuthManager가 들고 있는 이름으로 전체 리스트에서 찾기
        if let univName = authManager.userUniversityName {
            return University.find(byName: univName)
        }
        return nil
    }
    
    var body: some View {
        List {
            // 1. ✨ 내 대학교 (자동 매칭)
            if let myUniv = myUniversityLink {
                Section(header: Text("🏫 나의 대학교 (회원 정보)")) {
                    LinkButton(title: myUniv.name, icon: "graduationcap.fill", color: .indigo) {
                        openUrl(myUniv.urlString)
                    }
                }
            } else {
                // (혹시라도 매칭 실패 시)
                Section(header: Text("🏫 나의 대학교")) {
                    Text("소속 대학교 정보를 불러올 수 없습니다.")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            
            // 2. 공통 필수 사이트
            Section(header: Text("📢 필수 공지사항")) {
                ForEach(CommonSite.all) { site in
                    LinkButton(title: site.name, icon: site.iconName, color: site.color) {
                        openUrl(site.urlString)
                    }
                }
            }
            
            // 3. 목표 교육청 (이건 사용자가 바꿀 수 있게 기존 유지)
            if let office = settingsManager.targetOffice {
                Section(header: Text("🎯 목표 교육청 (\(office.rawValue))")) {
                    LinkButton(title: "\(office.rawValue) 시험공고", icon: "building.columns.circle.fill", color: .orange) {
                        openUrl(office.urlString)
                    }
                }
            } else {
                Section {
                    Button(action: { showSettings = true }) {
                        HStack {
                            Text("👉 목표 교육청 설정하러 가기")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Section(footer: Text("소속 대학교는 회원가입 정보에 따릅니다.")) {
                EmptyView()
            }
        }
        .navigationTitle("임용 정보 모음")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                NoticeSettingsView()
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $selectedUrl) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
    
    private func openUrl(_ string: String) {
        if let url = URL(string: string) {
            selectedUrl = url
        }
    }
}

// ... (LinkButton, URL extension 등 기존 하단 코드 유지) ...
// (혹시 잘렸다면 아래 코드를 그대로 붙여넣으세요)

struct LinkButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 4)
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
