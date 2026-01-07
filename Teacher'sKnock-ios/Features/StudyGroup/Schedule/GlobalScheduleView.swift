import SwiftUI

struct GlobalScheduleView: View {
    // 내 그룹 목록의 ID 배열
    var myGroupIDs: [String]
    @StateObject private var scheduleManager = GroupScheduleManager()
    
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding()
            
            List {
                // 날짜에 해당하는 모든 스케줄을 가져옴
                let dailySchedules = scheduleManager.schedules(at: selectedDate, from: scheduleManager.globalSchedules)
                
                if dailySchedules.isEmpty {
                    Text("일정이 없습니다.")
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(dailySchedules) { schedule in
                        /* 
                           Global 뷰에서는 해당 스케줄이 어느 그룹의 것인지 표시해주는게 좋음
                           하지만 현재 GroupSchedule 모델엔 groupName이 없음.
                           (fetch 시 id만 받아옴)
                           일단은 UI에 심플하게 보여주고, 클릭 시 이동은 추후 고려 (Optional)
                        */
                        HStack {
                            VStack(alignment: .leading) {
                                Text(schedule.title)
                                    .font(.subheadline.bold())
                                // 여기서 그룹명을 보여주려면 별도 매핑이 필요함 -> 일단 패스
                            }
                            Spacer()
                            Text(schedule.type.rawValue)
                                .font(.caption2)
                                .padding(4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("전체 스터디 일정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduleManager.listenToGlobalSchedules(myGroupIDs: myGroupIDs)
        }
    }
}
