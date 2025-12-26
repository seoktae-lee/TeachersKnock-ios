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
            VStack(spacing: 20) {
                // 1. 커스텀 달력 (분리된 파일 사용)
                CustomCalendarView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    userId: currentUserId,
                    brandColor: brandColor
                )
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 2. 선택된 날짜 상세 보기 버튼
                VStack(spacing: 15) {
                    Text(selectedDate.formatted(date: .long, time: .omitted))
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    NavigationLink(destination: DailySwipeView(initialDate: selectedDate, userId: currentUserId)) {
                        HStack {
                            Text("상세 플랜 보기")
                                .font(.title3)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(brandColor)
                        .cornerRadius(15)
                        .shadow(color: brandColor.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("스터디 플래너")
            .toolbar {
                // 우측 상단 일정 추가 버튼
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddScheduleView(selectedDate: selectedDate)) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
            }
        }
    }
}

#Preview {
    PlannerView()
}
