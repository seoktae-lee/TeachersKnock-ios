import SwiftUI

struct NoticeSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            // 1. 소속 대학교 선택 (NoticeData.swift에 정의된 allList 사용)
            Section(header: Text("소속 대학교")) {
                Picker("대학교 선택", selection: $settingsManager.myUniversity) {
                    Text("선택 안 함").tag(nil as University?)
                    
                    // ✨ [수정됨] 하드코딩 대신 University.allList 사용
                    ForEach(University.allList, id: \.self) { univ in
                        Text(univ.name).tag(univ as University?)
                    }
                }
            }
            
            // 2. 응시 희망 교육청 선택
            Section(header: Text("응시 희망 교육청")) {
                Picker("교육청 선택", selection: $settingsManager.targetOffice) {
                    Text("선택 안 함").tag(nil as OfficeOfEducation?)
                    
                    ForEach(OfficeOfEducation.allCases) { office in
                        Text(office.rawValue).tag(office as OfficeOfEducation?)
                    }
                }
            }
            
            Section(footer: Text("선택한 정보에 맞춰 공지사항 바로가기가 제공됩니다.")) {
                Button("완료") {
                    dismiss()
                }
            }
        }
        .navigationTitle("맞춤 정보 설정")
    }
}
