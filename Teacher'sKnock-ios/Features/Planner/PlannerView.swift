import SwiftUI
import SwiftData
import FirebaseAuth

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 일정이 있는지 확인하기 위해 쿼리
    @Query private var schedules: [ScheduleItem]
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                // 1. 커스텀 달력
                CustomCalendarView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    userId: currentUserId,
                    brandColor: brandColor
                )
                .padding()
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                .padding(.horizontal)
                .padding(.top, 15)
                
                // 2. 상세 플랜 보기 카드
                NavigationLink(destination: DailySwipeView(initialDate: selectedDate, userId: currentUserId)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("오늘의 공부 계획 관리하기")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [brandColor, brandColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: brandColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("스터디 플래너")
            .toolbar {
                // ✨ 임시 버튼은 삭제되었습니다. (우측 상단 플러스 버튼만 유지)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddScheduleView(selectedDate: selectedDate)) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(brandColor)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .onAppear {
                // 앱 재설치 시 서버에서 내 일정 복구
                if schedules.isEmpty {
                    restoreSchedulesFromServer()
                }
            }
        }
    }
    // PlannerView.swift 내부의 restoreSchedulesFromServer 함수
    private func restoreSchedulesFromServer() {
        guard !currentUserId.isEmpty else { return }
        
        Task {
            do {
                let fetchedData = try await ScheduleManager.shared.fetchSchedules(userId: currentUserId)
                
                if !fetchedData.isEmpty {
                    await MainActor.run {
                        for data in fetchedData {
                            // 이미 존재하는지 ID로 체크 (중복 방지 로직이 있다면 사용)
                            let newItem = ScheduleItem(
                                id: data.id,
                                title: data.title,
                                details: data.details,
                                startDate: data.startDate,
                                endDate: data.endDate,
                                subject: data.subject,
                                isCompleted: data.isCompleted,
                                hasReminder: data.hasReminder,
                                ownerID: data.ownerID,
                                isPostponed: data.isPostponed,
                                
                                // ✨ [수정] 서버 데이터에서 공부 목적을 가져와서 넣어줍니다.
                                // 만약 data(DTO)에 studyPurpose가 아직 없다면 ScheduleManager의 DTO도 확인이 필요합니다.
                                // 일단 DTO에 해당 필드가 있다고 가정하고 추가합니다.
                                studyPurpose: data.studyPurpose
                            )
                            modelContext.insert(newItem)
                        }
                        print("✅ 서버에서 일정 \(fetchedData.count)개 복구 완료")
                    }
                }
            } catch {
                print("❌ 일정 복구 실패: \(error)")
            }
        }
    }
}
