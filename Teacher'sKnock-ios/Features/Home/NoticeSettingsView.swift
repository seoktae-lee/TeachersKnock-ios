import SwiftUI

struct NoticeSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var authManager: AuthManager // ✨ 추가
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            // 1. 소속 대학교 (AuthManager 정보 표시)
            Section(header: Text("소속 대학교 (회원가입 정보)"),
                    footer: Text("대학교 변경을 원하시면 재가입이 필요합니다.")) {
                
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.indigo)
                    
                    // ✨ AuthManager에 저장된 이름 표시
                    if let univName = authManager.userUniversityName {
                        Text(univName)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    } else {
                        Text("대학교 정보 없음")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            
            // 2. 응시 희망 교육청 (선택 가능)
            Section(header: Text("응시 희망 교육청")) {
                Picker("교육청 선택", selection: $settingsManager.targetOffice) {
                    Text("선택 안 함").tag(nil as OfficeOfEducation?)
                    
                    ForEach(OfficeOfEducation.allCases) { office in
                        Text(office.rawValue).tag(office as OfficeOfEducation?)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            
            Section {
                Button("완료") {
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("맞춤 정보 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}
