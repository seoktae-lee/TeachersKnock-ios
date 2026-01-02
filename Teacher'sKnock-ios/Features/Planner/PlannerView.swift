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
                
                // 1.5. 일정 관리 헤더 및 등록 버튼
                HStack {
                    Text("일정 관리")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    NavigationLink(destination: AddScheduleView(selectedDate: selectedDate)) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("일정 등록")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(brandColor)
                        .clipShape(Capsule())
                        .shadow(color: brandColor.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
                
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
            // ✨ [수정] onAppear 대신 task를 사용하여 비동기 작업 및 ID 변경 감지
            .task(id: currentUserId) {
                if !currentUserId.isEmpty && schedules.isEmpty {
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
                            
                            // ✨ [복구] 서버에서 불러온 일정에 대해 알림 다시 등록
                            NotificationManager.shared.updateNotifications(for: newItem)
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
