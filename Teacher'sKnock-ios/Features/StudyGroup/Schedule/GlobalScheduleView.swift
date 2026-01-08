import SwiftUI

struct GlobalScheduleView: View {
    // 내 그룹 목록의 ID 배열
    var myGroupIDs: [String]
    // ✨ [New] 그룹 이름 매핑 (ID -> Name)
    var groupNameMap: [String: String] = [:]
    
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
                
                Section {
                    if dailySchedules.isEmpty {
                        Text("일정이 없습니다.")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(dailySchedules) { schedule in
                            HStack {
                                // 아이콘 표시
                                let iconData = getIconData(for: schedule.type)
                                
                                Image(systemName: iconData.icon)
                                    .foregroundColor(iconData.color)
                                    .frame(width: 32, height: 32)
                                    .background(iconData.color.opacity(0.1))
                                    .cornerRadius(8) // ✨ [Modified] 원형 -> 둥근 사각형 (통일감)
                                
                                VStack(alignment: .leading) {
                                    // 그룹명 조회
                                    let groupName = groupNameMap[schedule.groupID] ?? "알 수 없는 그룹"
                                    
                                    if schedule.type == .timer, let subject = schedule.subject {
                                        Text("\(groupName) / \(subject) / \(schedule.title)")
                                            .font(.subheadline.bold())
                                    } else {
                                        Text("\(groupName) / \(schedule.title)")
                                            .font(.subheadline.bold())
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("일정 목록")
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
    
    // ✨ [New] Helper for Icon Data (Consistent with GroupScheduleView)
    func getIconData(for type: GroupSchedule.ScheduleType) -> (icon: String, color: Color) {
        switch type {
        case .notice: return ("megaphone.fill", .orange)
        case .timer: return ("stopwatch", .purple)
        case .pairing: return ("arrow.triangle.2.circlepath", .green)
        case .gathering: return ("person.3.fill", .blue)
        case .etc: return ("calendar", .gray)
        }
    }
}
