import SwiftUI
import SafariServices

struct NoticeListView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showSettings = false
    @State private var selectedUrl: URL?
    
    var body: some View {
        List {
            // 1. 소속 대학교
            if let myUniv = settingsManager.myUniversity {
                Section(header: Text("🏫 나의 대학교")) {
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
            
            // 3. 목표 교육청
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
            
            Section(footer: Text("설정에서 언제든 정보를 변경할 수 있습니다.")) {
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
            .presentationDetents([.medium, .large])
        }
        // ✨ SafariView 호출
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

// ✨ [중요] 이 코드가 있어야 URL 오류가 사라집니다!
extension URL: Identifiable {
    public var id: String { absoluteString }
}

// 리스트 버튼 디자인
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
