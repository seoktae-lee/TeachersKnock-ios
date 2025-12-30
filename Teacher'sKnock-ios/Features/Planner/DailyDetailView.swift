import SwiftUI
import SwiftData
import FirebaseAuth
import Charts
import UIKit

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
    @State private var editingItem: ScheduleItem? // 수정할 아이템
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
        .sheet(item: $editingItem) { item in
            AddScheduleView(selectedDate: date, scheduleToEdit: item)
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
                        editAction: { editingItem = item },
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
        
        // ✨ [미루기 취소 로직] 내일 일정을 찾아서 삭제
        // 조건: 날짜가 내일 + 제목 동일 + 과목 동일
        let calendar = Calendar.current
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: item.startDate) else { return }
        
        // 내일 날짜 범위 (00:00 ~ 23:59)
        let dayStart = calendar.startOfDay(for: tomorrowStart)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        
        let targetTitle = item.title
        let targetSubject = item.subject
        
        // ModelContext에서 직접 검색
        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { target in
                target.ownerID == userId &&
                target.startDate >= dayStart &&
                target.startDate < dayEnd &&
                target.title == targetTitle &&
                target.subject == targetSubject
            }
        )
        
        do {
            let foundItems = try modelContext.fetch(descriptor)
            if let targetToDelete = foundItems.first {
                // 하나 발견되면 삭제
                modelContext.delete(targetToDelete)
                ScheduleManager.shared.deleteSchedule(itemId: targetToDelete.id.uuidString, userId: userId)
            }
        } catch {
            print("미루기 취소 중 검색 실패: \(error)")
        }
    }
    
    @MainActor
    func renderAndShare() {
        var charEmoji = "🥚"
        var dDayText = "D-Day"
        var goalTitle = "목표를 설정해주세요"
        var charColor = brandColor
        var charLevel = 0
        
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
                // ✨ [수정] 전체 레코드에서 필터링하는 대신, 역방향 관계를 사용하여 안전하게 접근
                // 기존: let goalRecords = allRecords.filter { $0.goal?.id == goal.id }
                let goalRecords = goal.records ?? []
                
                let uniqueDays = Set(goalRecords.map { Calendar.current.startOfDay(for: $0.date) }).count
                let level = CharacterLevel.getLevel(uniqueDays: uniqueDays)
                charLevel = level.rawValue
                
                charEmoji = level.emoji(for: goal.characterType)
                charColor = GoalColorHelper.color(for: goal.characterColor)
            } else {
                charEmoji = "📝"
            }
        }
        
        // 인스타그램 스토리 비율 (9:16)
        // 1080 x 1920 해상도를 목표로 하되, 렌더링 시에는 포인트 단위로 작업
        // iPhone 화면 포인트 기준 width: 375 ~ 430 정도.
        // 여기서는 논리적 크기를 375x667(iPhone 8 기준 비율) 또는 적절한 비율로 잡고 scale을 키웁니다.
        let width: CGFloat = 375
        let height: CGFloat = 667 // 9:16 ratio approx
        
        let renderer = ImageRenderer(content: DailyShareView(
            date: date,
            studyTime: studyTimeFormatted,
            characterEmoji: charEmoji,
            characterLevel: charLevel,
            dDay: dDayText,
            goalTitle: goalTitle,
            themeColor: charColor
        ).frame(width: width, height: height))
        
        // ✨ [수정] 렌더링 사이즈 명시 및 스케일 설정
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            self.shareImage = image
            self.isShareSheetPresented = true
        }
    }
}

// MARK: - 공유용 뷰 (인스타그램 스토리 스타일)
struct DailyShareView: View {
    let date: Date
    let studyTime: String
    let characterEmoji: String
    let characterLevel: Int
    let dDay: String
    let goalTitle: String
    let themeColor: Color
    
    var body: some View {
        ZStack {
            // 1. 배경 (Background) - 테마 컬러를 활용한 감성적인 그라데이션
            LinearGradient(
                gradient: Gradient(colors: [
                    themeColor.opacity(0.8),
                    themeColor.opacity(0.4),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 배경 데코레이션 (부드러운 빛 효과)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 400, height: 400)
                .offset(x: -120, y: -200)
                .blur(radius: 20)
            
            VStack {
                Spacer()
                
                // 2. 포커스 카드 (Focus Card)
                VStack(spacing: 25) {
                    // 상단 날짜 헤더
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date.formatted(.dateTime.weekday(.wide)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            Text(date.formatted(.dateTime.month().day()))
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        
                        // D-Day 뱃지
                        Text(dDay)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(themeColor))
                    }
                    .padding(.horizontal, 10)
                    
                    Divider().opacity(0.5)
                    
                    // 메인 콘텐츠
                    VStack(spacing: 15) {
                        // 캐릭터 영역
                        ZStack {
                            Circle()
                                .fill(themeColor.opacity(0.1))
                                .frame(width: 140, height: 140)
                            
                            Text(characterEmoji)
                                .font(.system(size: 80))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            // 레벨 표시
                            if characterLevel > 0 {
                                VStack {
                                    Spacer()
                                    Text("Lv.\(characterLevel)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(themeColor))
                                        .offset(y: 10)
                                }
                                .frame(height: 140)
                            }
                        }
                        .padding(.top, 10)
                        
                        // 공부 시간
                        VStack(spacing: 0) {
                            Text(studyTime)
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("TOTAL STUDY TIME")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.top, 5)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    Divider().opacity(0.5)
                    
                    // 하단 목표 정보
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(themeColor)
                            .font(.caption)
                        Text(goalTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 60) // 중앙에서 약간 위로 배치
                
                Spacer()
                
                // 3. 하단 브랜딩
                Text("Teacher's Knock")
                    .font(.custom("Futura-Medium", size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(2)
                    .padding(.bottom, 50)
            }
        }
        .frame(width: 375, height: 667)
        .clipped()
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
    var editAction: () -> Void
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
                    
                    if !item.isPostponed && !item.isCompleted && SubjectName.isStudySubject(item.subject) {
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
            // ✨ [수정] 수정 기능 추가
            Button { editAction() } label: { Label("수정", systemImage: "pencil") }
            
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
