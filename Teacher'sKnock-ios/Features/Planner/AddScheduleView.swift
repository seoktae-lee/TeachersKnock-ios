import SwiftUI
import SwiftData
import FirebaseAuth

struct AddScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: AddScheduleViewModel
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    init() {
        let userId = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: AddScheduleViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. 일정 순서 미리보기 (삭제 기능 연결됨)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("일정 순서 미리보기")
                                .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                            Spacer()
                            Text("기존 일정 길게 눌러 삭제")
                                .font(.caption2).foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(.horizontal)
                        
                        SchedulePreviewView(
                            existingSchedules: viewModel.existingSchedules,
                            draftSchedule: viewModel.draftSchedule,
                            onDelete: { item in
                                // ✨ 삭제 요청 시 뷰모델 호출
                                withAnimation {
                                    viewModel.deleteSchedule(item)
                                }
                            }
                        )
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // 2. 입력 폼
                    VStack(spacing: 0) {
                        TextField("일정 제목 (예: 교육학 암기)", text: $viewModel.title)
                            .font(.headline)
                            .padding()
                            .background(Color.white)
                        
                        Divider().padding(.leading)
                        
                        TextField("상세 메모 (선택)", text: $viewModel.details)
                            .padding()
                            .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // 3. 시간 설정 및 겹침 알림
                    VStack(spacing: 0) {
                        DatePicker("시작", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                            .tint(brandColor)
                            .padding()
                            .onChange(of: viewModel.startDate) { _ in
                                viewModel.fetchExistingSchedules()
                                if viewModel.endDate <= viewModel.startDate {
                                    viewModel.endDate = viewModel.startDate.addingTimeInterval(3600)
                                }
                            }
                        
                        Divider().padding(.leading)
                        
                        DatePicker("종료", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: [.date, .hourAndMinute])
                            .tint(brandColor)
                            .padding()
                        
                        // ✨ [조건부 알림] 겹치는 일정이 있을 때만 표시
                        if let conflictName = viewModel.overlappingScheduleTitle {
                            Divider().padding(.horizontal)
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                VStack(alignment: .leading) {
                                    Text("시간이 겹치는 일정이 있습니다!")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Text("'\(conflictName)'")
                                        .font(.caption)
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // 4. 옵션
                    Toggle("시작 전 알림 받기", isOn: $viewModel.hasReminder)
                        .tint(brandColor)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
            .background(Color(.systemGray6))
            .navigationTitle("새 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        viewModel.saveSchedule { dismiss() }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(brandColor)
                    .disabled(viewModel.title.isEmpty)
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
            }
        }
    }
}
