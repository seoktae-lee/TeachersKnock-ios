import SwiftUI

struct DailySwipeView: View {
    let initialDate: Date
    let userId: String
    
    // TabView의 selection을 위한 정수 오프셋 (0 = initialDate)
    // 앞뒤로 1년(365일) 정도의 범위를 제공
    @State private var offset: Int = 0
    
    var body: some View {
        TabView(selection: $offset) {
            ForEach(-365...365, id: \.self) { dayOffset in
                DailyDetailView(date: date(for: dayOffset), userId: userId)
                    .tag(dayOffset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 인디케이터 숨김 (깔끔하게)
        // .ignoresSafeArea removed to prevent top overlap issues
        // 네비게이션 타이틀은 DailyDetailView 내부에서 관리하거나 여기서 오프셋에 따라 변경 가능
        // 하지만 DailyDetailView가 자체 헤더를 가지고 있으므로 여기선 inline으로 설정만 함
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func date(for offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: initialDate) ?? initialDate
    }
}
