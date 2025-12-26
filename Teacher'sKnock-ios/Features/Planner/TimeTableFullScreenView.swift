import SwiftUI

struct TimeTableFullScreenView: View {
    @Environment(\.dismiss) var dismiss
    let date: Date
    let userId: String
    
    @State private var isCompactMode = false
    
    // Fit to Screen 계산을 위한 상수
    // 6시 ~ 26시 = 20시간
    // 전체 높이 / 20 = hourHeight
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // 헤더 (날짜 및 컨트롤)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(date.formatted(.dateTime.month().day()))
                                .font(.title2).fontWeight(.bold)
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // 모드 토글 (스크롤 vs 한눈에)
                        Picker("모드", selection: $isCompactMode) {
                            Text("스크롤").tag(false)
                            Text("한눈에").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        
                        // 닫기 버튼
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 10)
                    }
                    .padding()
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
                    .zIndex(1)
                    
                    // 타임테이블
                    if isCompactMode {
                        // 한눈에 보기 (Fit)
                        // SafeArea 등을 고려한 남은 높이 계산 필요하지만,
                        // GeometryReader로 대략 계산
                        let availableHeight = geo.size.height - 80 // 헤더 대략 80
                        let fitHeight = max(availableHeight / 20.0, 20) // 최소 20은 보장
                        
                        TimeTableView(date: date, userId: userId, hourHeight: fitHeight)
                    } else {
                        // 기본 스크롤 모드 (60pt)
                        TimeTableView(date: date, userId: userId, hourHeight: 60)
                    }
                }
            }
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
    }
}
