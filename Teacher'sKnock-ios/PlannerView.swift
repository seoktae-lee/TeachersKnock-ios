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
            VStack {
                // 1. 달력 (DatePicker)
                // 날짜를 선택하면 자동으로 아래 상세 버튼의 날짜가 바뀜
                DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accentColor(brandColor)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding()
                
                Spacer()
                
                // 2. 상세 보기 버튼 (가장 중요한 연결 고리!)
                // 사용자가 달력에서 날짜를 찍고 이 버튼을 누르거나, 바로 아래에 요약 뷰를 보여줄 수도 있습니다.
                NavigationLink(destination: DailyDetailView(date: selectedDate, userId: currentUserId)) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("\(selectedDate.formatted(date: .abbreviated, time: .omitted)) 상세 계획 보기")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(brandColor)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("스터디 플래너")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
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
