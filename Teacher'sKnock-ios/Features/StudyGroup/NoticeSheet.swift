import SwiftUI

struct NoticeSheet: View {
    let group: StudyGroup
    let isLeader: Bool
    @ObservedObject var studyManager: StudyGroupManager
    @Environment(\.dismiss) var dismiss
    
    @State private var noticeText: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    Text("공지사항 수정")
                        .font(.headline)
                        .padding(.top)
                    
                    TextEditor(text: $noticeText)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    ScrollView {
                        Text(group.notice.isEmpty ? "등록된 공지사항이 없습니다." : group.notice)
                            .font(.body)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("공지사항")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                if isLeader {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isEditing ? "저장" : "수정") {
                            if isEditing {
                                saveNotice()
                            } else {
                                isEditing = true
                            }
                        }
                    }
                }
            }
            .onAppear {
                noticeText = group.notice
                // 읽음 처리
                studyManager.markNoticeAsRead(groupID: group.id)
            }
        }
    }
    
    func saveNotice() {
        studyManager.updateNotice(groupID: group.id, notice: noticeText)
        isEditing = false
    }
}
