import SwiftUI
import SwiftData

// MARK: - 커스텀 달력 뷰 (잔디 심기 로직 포함)
struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let userId: String
    let brandColor: Color
    
    @Environment(\.modelContext) private var modelContext
    @State private var attendedDays: Set<Int> = [] // 출석(공부/완료)한 날짜 모음
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["일", "월", "화", "수", "목", "금", "토"]
    
    var body: some View {
        VStack(spacing: 15) {
            // [상단] 년월 표시 & 달 이동 버튼
            HStack {
                Text(currentMonth.formatted(.dateTime.year().month()))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left").font(.title3).foregroundColor(.gray)
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right").font(.title3).foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 5)
            
            // [중단] 요일 헤더
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(day == "일" ? .red.opacity(0.7) : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // [하단] 날짜 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // 1. ✨ [ID 충돌 해결] 빈 칸 채우기
                // 0부터 시작하면 날짜(1, 2...)와 ID가 겹칠 수 있으므로 음수 사용
                ForEach(-startOffset..<0, id: \.self) { _ in
                    Color.clear
                        .frame(height: 40)
                }
                
                // 2. 날짜들
                ForEach(1...daysInMonth, id: \.self) { day in
                    let date = getDate(for: day)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let isAttended = attendedDays.contains(day)
                    
                    Button(action: {
                        withAnimation { selectedDate = date }
                    }) {
                        ZStack {
                            // 배경 원 처리
                            if isSelected {
                                // 선택됨: 진한 색
                                Circle().fill(brandColor)
                            } else if isAttended {
                                // 출석함(잔디): 연한 색
                                Circle().fill(brandColor.opacity(0.2))
                            } else if isToday {
                                // 오늘: 테두리
                                Circle().stroke(brandColor, lineWidth: 1.5)
                            }
                            
                            // 날짜 숫자
                            Text("\(day)")
                                .font(.body)
                                .fontWeight(isSelected || isToday ? .bold : .regular)
                                .foregroundColor(isSelected ? .white : (isToday ? brandColor : .primary))
                        }
                        .frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            fetchAttendanceData()
        }
        // 달을 넘기거나 날짜를 선택할 때마다 데이터 갱신
        .onChange(of: currentMonth) { _ in fetchAttendanceData() }
        .onChange(of: selectedDate) { _ in fetchAttendanceData() }
    }
    
    // MARK: - Helper Methods
    
    // 이번 달 1일의 요일 인덱스 (0: 일요일 ~ 6: 토요일)
    private var startOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let startOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: startOfMonth) - 1
    }
    
    // 이번 달의 총 일수
    private var daysInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        return range.count
    }
    
    // 날짜 객체 생성
    private func getDate(for day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? Date()
    }
    
    // 달 이동
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    // ✨ 핵심 로직: 출석 데이터(잔디) 가져오기
    private func fetchAttendanceData() {
        // 1. 이번 달의 시작과 끝 날짜 계산
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // 2. 조건: 내 아이디 && (스케줄 완료됨 OR 타이머 기록 있음)
        
        // A. 완료된 스케줄
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId &&
                item.isCompleted == true &&
                item.startDate >= startOfMonth &&
                item.startDate < endOfMonth
            }
        )
        
        // B. 공부 기록
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == userId &&
                record.date >= startOfMonth &&
                record.date < endOfMonth
            }
        )
        
        do {
            let schedules = try modelContext.fetch(scheduleDescriptor)
            let records = try modelContext.fetch(recordDescriptor)
            
            var days: Set<Int> = []
            
            // 완료된 스케줄이 있는 날짜 추가
            for item in schedules {
                let day = calendar.component(.day, from: item.startDate)
                days.insert(day)
            }
            
            // 공부 기록이 있는 날짜 추가
            for record in records {
                let day = calendar.component(.day, from: record.date)
                days.insert(day)
            }
            
            self.attendedDays = days
            
        } catch {
            print("❌ 출석 데이터 로드 실패: \(error)")
        }
    }
}
