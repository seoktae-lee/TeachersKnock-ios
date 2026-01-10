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
                            VStack(alignment: .leading, spacing: 6) {
                                // 1. Group Badge
                                let groupName = groupNameMap[schedule.groupID] ?? "알 수 없는 그룹"
                                let groupColor = color(for: schedule.groupID)
                                
                                Text(groupName)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(groupColor.opacity(0.15))
                                    .foregroundColor(groupColor)
                                    .cornerRadius(6)
                                
                                HStack(spacing: 12) {
                                    // Icon
                                    let iconData = getIconData(for: schedule.type)
                                    Image(systemName: iconData.icon)
                                        .font(.title3)
                                        .foregroundColor(iconData.color)
                                        .frame(width: 40, height: 40)
                                        .background(iconData.color.opacity(0.1))
                                        .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        // 2. Title & Subject
                                        HStack(alignment: .center, spacing: 6) {
                                            Text(schedule.title)
                                                .font(.body.bold())
                                                .foregroundColor(.primary)
                                            
                                            if let subject = schedule.subject, !subject.isEmpty {
                                                Text("| \(subject)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // 3. Time
                                        Text(formatTime(schedule.date))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
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
    
    // ✨ [New] Helper for Color Generation
    func color(for id: String) -> Color {
        let colors: [Color] = [.red, .orange, .blue, .purple, .pink, .green, .mint, .teal, .indigo, .cyan]
        let hash = id.utf8.reduce(0) { $0 + Int($1) }
        return colors[hash % colors.count]
    }
    
    // ✨ [New] Helper for Time Formatting
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
