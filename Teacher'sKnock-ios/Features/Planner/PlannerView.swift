import SwiftUI
import SwiftData
import FirebaseAuth

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var currentMonth = Date() // 달력에 표시되는 월
    
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
                .cornerRadius(24) // 모서리 조금 더 둥글게
                .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                .padding(.horizontal)
                .padding(.top, 15)
                
                // 2. ✨ [수정됨] 상세 플랜 보기 카드 (세련된 스타일)
                NavigationLink(destination: DailySwipeView(initialDate: selectedDate, userId: currentUserId)) {
                    HStack {
                        // 날짜 및 텍스트 정보
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedDate.formatted(date: .long, time: .omitted)) // 예: 2025년 12월 26일
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("오늘의 공부 계획 관리하기")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // 화살표 아이콘 (원형 배경)
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
                        // 브랜드 컬러 그라디언트 배경
                        LinearGradient(
                            colors: [brandColor, brandColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: brandColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    .overlay(
                        // 미세한 테두리 광택
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
        }
    }
}
