import SwiftUI
import SafariServices

struct NoticeListView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showSettings = false
    @State private var selectedUrl: URL?
    
    // ✨ 검색어 상태 변수
    @State private var searchText = ""
    
    // 내 대학교 (AuthManager 정보)
    var myUniversityLink: University? {
        if let univName = authManager.userUniversityName {
            return University.find(byName: univName)
        }
        return nil
    }
    
    var body: some View {
        List {
            // ✨ [분기 1] 검색어가 없을 때 -> 기존 "나의 맞춤 정보" 보여주기
            if searchText.isEmpty {
                // 1. 나의 대학교 (회원 정보)
                if let myUniv = myUniversityLink {
                    Section(header: Text("🏫 나의 대학교 (회원 정보)")) {
                        LinkButton(title: myUniv.name, icon: "graduationcap.fill", color: .indigo) {
                            openUrl(myUniv.urlString)
                        }
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
                
                // 3. 목표 교육청 (설정값)
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
            // ✨ [분기 2] 검색어가 있을 때 -> 전체 리스트에서 찾기
            else {
                // 대학교 검색 결과
                let filteredUnivs = University.allList.filter { $0.name.contains(searchText) }
                if !filteredUnivs.isEmpty {
                    Section(header: Text("🏫 대학교 검색 결과")) {
                        ForEach(filteredUnivs, id: \.self) { univ in
                            LinkButton(title: univ.name, icon: "graduationcap", color: .gray) {
                                openUrl(univ.urlString)
                            }
                        }
                    }
                }
                
                // 교육청 검색 결과
                let filteredOffices = OfficeOfEducation.allCases.filter { $0.rawValue.contains(searchText) }
                if !filteredOffices.isEmpty {
                    Section(header: Text("🎯 교육청 검색 결과")) {
                        ForEach(filteredOffices) { office in
                            LinkButton(title: office.rawValue, icon: "building.columns", color: .gray) {
                                openUrl(office.urlString)
                            }
                        }
                    }
                }
                
                // 검색 결과가 아예 없을 때
                if filteredUnivs.isEmpty && filteredOffices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .navigationTitle("임용 정보 모음")
        .navigationBarTitleDisplayMode(.inline)
        // ✨ 검색창 활성화
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "다른 학교나 교육청 검색")
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

// ... (하단 LinkButton, URL extension 등은 기존과 동일하므로 유지) ...

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
