import SwiftUI
import SwiftData
import FirebaseAuth
import Charts

struct DailyDetailView: View {
    let date: Date
    let userId: String
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // ✨ 네비게이션 매니저 연결
    @EnvironmentObject var navManager: StudyNavigationManager
    
    // 데이터 쿼리
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    @Query private var goals: [Goal]
    // ✨ [추가] 캐릭터 레벨 계산을 위해 전체 기록을 가져옵니다.
    @Query private var allRecords: [StudyRecord]
    
    @State private var showingAddSheet = false
    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // MARK: - Computed Properties
    var totalPlannedCount: Int { schedules.count }
    var completedCount: Int { schedules.filter { $0.isCompleted && !$0.isPostponed }.count }
    var achievementRate: Double {
        totalPlannedCount == 0 ? 0 : Double(completedCount) / Double(totalPlannedCount)
    }
    
    var totalStudySeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var studyTimeFormatted: String {
        let h = totalStudySeconds / 3600
        let m = (totalStudySeconds % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
    
    // MARK: - Initializer
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> {
            $0.ownerID == userId && $0.date >= start && $0.date < end
        })
        
        _goals = Query(filter: #Predicate<Goal> {
            $0.ownerID == userId
        })
        
        // ✨ [오류 해결용] 전체 공부 기록 쿼리 초기화
        _allRecords = Query(filter: #Predicate<StudyRecord> {
            $0.ownerID == userId
        })
    }
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCard
                        
                        if schedules.isEmpty {
                            emptyStateView
                        } else {
                            timelineListView
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            
            // 플로팅 버튼 (일정 추가)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(brandColor)
                            .clipShape(Circle())
                            .shadow(color: brandColor.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddScheduleView(selectedDate: date)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    // MARK: - Subviews
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Button(action: renderAndShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(brandColor)
                        .padding(10)
                        .background(brandColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                if let primary = goals.first(where: { $0.isPrimaryGoal }) ?? goals.sorted(by: { $0.targetDate < $1.targetDate }).first {
                    Text("'\(primary.characterName)' 공유 중")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.1)), alignment: .bottom)
    }
    
    var summaryCard: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill").foregroundColor(brandColor)
                    Text("총 공부 시간").font(.caption).foregroundColor(.gray)
                }
                Text(studyTimeFormatted)
                    .font(.title2).fontWeight(.bold).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white).cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill").foregroundColor(.green)
                    Text("계획 달성률").font(.caption).foregroundColor(.gray)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(Int(achievementRate * 100))").font(.title2).fontWeight(.bold)
                    Text("%").font(.caption).fontWeight(.bold).padding(.bottom, 4)
                }
                .foregroundColor(.primary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2).fill(Color.green)
                            .frame(width: geo.size.width * achievementRate)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white).cornerRadius(16)
            .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    var timelineListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(schedules.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 15) {
                    VStack(spacing: 0) {
                        Text(item.startDate.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .trailing)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .padding(.top, 4)
                            .padding(.leading, 38)
                    }
                    
                    ScheduleRow(
                        item: item,
                        context: modelContext,
                        postponeAction: { postponeSchedule(item) },
                        cancelPostponeAction: { cancelPostpone(item) },
                        startStudyAction: {
                            navManager.triggerStudy(for: item)
                        }
                    )
                    .padding(.bottom, 15)
                }
                .padding(.horizontal)
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.3))
            Text("아직 등록된 일정이 없어요.\n플러스 버튼을 눌러 계획을 세워보세요!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
    
    // MARK: - Logic Methods
    
    func postponeSchedule(_ item: ScheduleItem) {
        item.isPostponed = true
        let calendar = Calendar.current
        if let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: item.startDate),
           let tomorrowEnd = item.endDate.map({ calendar.date(byAdding: .day, value: 1, to: $0)! }) {
            
            let newItem = ScheduleItem(
                title: item.title,
                details: item.details,
                startDate: tomorrowStart,
                endDate: tomorrowEnd,
                subject: item.subject,
                isCompleted: false,
                hasReminder: item.hasReminder,
                ownerID: item.ownerID,
                isPostponed: false
            )
            modelContext.insert(newItem)
            ScheduleManager.shared.saveSchedule(newItem)
            ScheduleManager.shared.saveSchedule(item)
        }
    }
    
    func cancelPostpone(_ item: ScheduleItem) {
        item.isPostponed = false
        ScheduleManager.shared.saveSchedule(item)
    }
    
    @MainActor
    func renderAndShare() {
        var charEmoji = "🥚"
        var dDayText = "D-Day"
        var goalTitle = "목표를 설정해주세요"
        var charColor = brandColor
        
        let targetGoal = goals.first(where: { $0.isPrimaryGoal })
                      ?? goals.sorted { $0.targetDate < $1.targetDate }.first
        
        if let goal = targetGoal {
            goalTitle = goal.title
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let target = calendar.startOfDay(for: goal.targetDate)
            let diff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
            if diff == 0 { dDayText = "D-Day" }
            else if diff > 0 { dDayText = "D-\(diff)" }
            else { dDayText = "D+\(-diff)" }
            
            if goal.hasCharacter {
                // ✨ [오류 해결] 비선형 성장 로직 적용
                // ✨ [수정] 비선형 성장 로직 (Unique Days 기준)
                // 해당 목표(goal)에 할당된 기록들 중 날짜가 서로 다른 날의 개수를 셉니다.
                let goalRecords = allRecords.filter { $0.goal?.id == goal.id }
                let uniqueDays = Set(goalRecords.map { Calendar.current.startOfDay(for: $0.date) }).count
                let level = CharacterLevel.getLevel(uniqueDays: uniqueDays)
                
                charEmoji = level.emoji(for: goal.characterType)
                charColor = GoalColorHelper.color(for: goal.characterColor)
            } else {
                charEmoji = "📝"
            }
        }
        
        let renderer = ImageRenderer(content: DailyShareView(
            date: date,
            studyTime: studyTimeFormatted,
            characterEmoji: charEmoji,
            dDay: dDayText,
            goalTitle: goalTitle,
            themeColor: charColor
        ))
        renderer.scale = UIScreen.main.scale
        
        if let image = renderer.uiImage {
            self.shareImage = image
            self.isShareSheetPresented = true
        }
    }
}

// MARK: - 공유용 뷰
struct DailyShareView: View {
    let date: Date
    let studyTime: String
    let characterEmoji: String
    let dDay: String
    let goalTitle: String
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Teacher's Knock")
                .font(.caption)
                .tracking(2)
                .foregroundColor(.gray)
                .padding(.top, 30)
            
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundColor(.black)
            
            Spacer().frame(height: 10)
            
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Text(characterEmoji)
                    .font(.system(size: 70))
            }
            .overlay(
                Text(goalTitle)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(themeColor))
                    .offset(y: 65),
                alignment: .center
            )
            
            Spacer().frame(height: 10)
            
            VStack(spacing: 8) {
                Text("TODAY STUDY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                
                Text(studyTime)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(themeColor)
            }
            
            Text(dDay)
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 4)
            
            Spacer()
        }
        .frame(width: 320, height: 500)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ScheduleRow
struct ScheduleRow: View {
    let item: ScheduleItem
    let context: ModelContext
    var postponeAction: () -> Void
    var cancelPostponeAction: () -> Void
    var startStudyAction: () -> Void
    
    var subjectColor: Color {
        SubjectName.color(for: item.subject)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.isPostponed ? Color.gray : subjectColor)
                .frame(width: 4)
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if item.isPostponed {
                        HStack(spacing: 4) {
                            Text(item.title).font(.headline).strikethrough().foregroundColor(.gray)
                            Image(systemName: "arrowshape.turn.up.right.fill").font(.caption).foregroundColor(.orange)
                            Text("내일로 미룸").font(.caption2).foregroundColor(.orange)
                        }
                    } else {
                        Text(item.title)
                            .font(.headline)
                            .strikethrough(item.isCompleted)
                            .foregroundColor(item.isCompleted ? .gray : .primary)
                    }
                    
                    Spacer()
                    
                    if !item.isPostponed && !item.isCompleted {
                        Button(action: startStudyAction) {
                            Image(systemName: "stopwatch")
                                .font(.title2)
                                .foregroundColor(subjectColor)
                        }
                        .padding(.trailing, 8)
                    }
                    
                    if !item.isPostponed {
                        Button(action: toggleComplete) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(item.isCompleted ? .green : .gray.opacity(0.4))
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Label("\(formatTime(item.startDate)) ~ \(formatTime(item.endDate ?? item.startDate))", systemImage: "clock")
                        .font(.caption).foregroundColor(.gray)
                    
                    Text("•").font(.caption).foregroundColor(.gray)
                    
                    Text(item.subject)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(item.isPostponed ? .gray : subjectColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.isPostponed ? Color.gray.opacity(0.1) : subjectColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
        .contextMenu {
            if item.isPostponed {
                Button { cancelPostponeAction() } label: { Label("미루기 취소", systemImage: "arrow.uturn.backward") }
            } else {
                Button { postponeAction() } label: { Label("내일로 미루기", systemImage: "arrow.right.circle") }
            }
            Divider()
            Button(role: .destructive) {
                ScheduleManager.shared.deleteSchedule(itemId: item.id.uuidString, userId: item.ownerID)
                withAnimation { context.delete(item) }
            } label: { Label("삭제", systemImage: "trash") }
        }
    }
    
    func toggleComplete() {
        withAnimation {
            item.isCompleted.toggle()
            ScheduleManager.shared.saveSchedule(item)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}
