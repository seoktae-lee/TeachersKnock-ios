import SwiftUI
import SwiftData
import FirebaseAuth

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    
    // 현재 로그인한 사용자 ID
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 1. 달력 (DatePicker)
                DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accentColor(brandColor)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20) // 모서리를 조금 더 둥글게
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5) // 그림자 부드럽게
                    .padding(.horizontal)
                    .padding(.top)
                
                Spacer()
                
                // 2. ✨ [디자인 개선] 상세 보기 버튼
                NavigationLink(destination: DailyDetailView(date: selectedDate, userId: currentUserId)) {
                    HStack(spacing: 12) {
                        // 아이콘을 채워진 형태로 변경하여 강조
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.title3)
                        
                        // 날짜 포맷을 조금 더 깔끔하게 다듬음
                        Text("\(selectedDate.formatted(.dateTime.month().day())) 상세 리포트 보기")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18) // 높이감을 주어 터치 영역 확보
                    // ✨ 핵심 디자인: 그라데이션 배경
                    .background(
                        LinearGradient(
                            colors: [brandColor.opacity(0.8), brandColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // ✨ 핵심 디자인: 캡슐 모양 (알약형)
                    .clipShape(Capsule())
                    // ✨ 핵심 디자인: 브랜드 컬러를 활용한 부드러운 그림자
                    .shadow(color: brandColor.opacity(0.4), radius: 10, x: 0, y: 8)
                    .padding(.horizontal, 30) // 양 옆 여백을 늘려 중앙 집중형으로
                }
                
                Spacer()
                Spacer() // 하단 여백 확보용
            }
            .background(Color(.systemGray6).ignoresSafeArea()) // 전체 배경색 지정
            .navigationTitle("스터디 플래너")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill") // 플러스 버튼도 채워진 형태로 통일감 부여
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddScheduleView()
            }
        }
    }
}

#Preview {
    PlannerView()
}
