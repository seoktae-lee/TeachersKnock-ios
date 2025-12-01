import SwiftUI
import SwiftData
import FirebaseAuth

struct CharacterView: View {
    // 내 공부 기록 가져오기
    @Query private var records: [StudyRecord]
    // ✨ 내 플래너 일정 가져오기 (추가됨)
    @Query private var scheduleItems: [ScheduleItem]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 말풍선 상태
    @State private var speechText: String = "오늘도 파이팅!"
    @State private var showBubble: Bool = false
    
    let cheerMessages = [
        "오늘도 파이팅!", "합격이 보여요!", "조금만 더 힘내요!",
        "멋진 선생님이 될 거예요!", "포기하지 마세요!", "당신을 믿어요!",
        "오늘 공부 파이팅!", "3월의 교실에서 만나요!", "꾸준함이 답이다!",
        "넌 할 수 있어!"
    ]
    
    init(userId: String) {
        // 1. 타이머 기록 필터링
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        })
        
        // ✨ 2. 플래너 일정 필터링 (추가됨)
        _scheduleItems = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId
        })
    }
    
    // ✨ 누적 공부 일수 계산 (로직 업그레이드!)
    var studyDays: Int {
        let calendar = Calendar.current
        
        // 1) 타이머 쓴 날짜들
        let timerDays = records.map { calendar.startOfDay(for: $0.date) }
        
        // 2) 플래너 완료한 날짜들 (isCompleted == true 인 것만)
        let plannerDays = scheduleItems
            .filter { $0.isCompleted }
            .map { calendar.startOfDay(for: $0.startDate) }
        
        // 3) 두 날짜를 합치고 중복 제거 (Set)
        let allUniqueDays = Set(timerDays + plannerDays)
        
        return allUniqueDays.count
    }
    
    // 현재 레벨 계산 (300일 기준)
    var currentLevel: CharacterLevel {
        CharacterLevel.getLevel(currentDays: studyDays, totalGoalDays: 300)
    }
    
    // 진행률
    var progress: Double {
        let nextLevel = CharacterLevel(rawValue: currentLevel.rawValue + 1) ?? .lv10
        if currentLevel == .lv10 { return 1.0 }
        
        let currentReq = nextLevel.requiredProgress // 다음 레벨에 필요한 %
        // 단순히 전체 300일 중 며칠 했는지 비율 계산 (0.0 ~ 1.0)
        // *참고: 정확한 게이지 바 구현을 위해 전체 300일 기준 진행률로 표시하거나,
        // 레벨 간의 구간 진행률로 표시할 수 있습니다. 여기선 전체 기준으로 단순화합니다.
        return Double(studyDays) / 300.0
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // 1. 캐릭터 + 말풍선
            VStack(spacing: 5) {
                if showBubble {
                    Text(speechText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                        .overlay(
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .offset(y: 8),
                            alignment: .bottom
                        )
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: -5)
                }
                
                Text(currentLevel.emoji)
                    .font(.system(size: 60))
                    .padding()
                    .background(Circle().fill(Color.white))
                    .shadow(color: .gray.opacity(0.2), radius: 5)
                    .onTapGesture {
                        triggerHapticFeedback()
                        changeMessage()
                    }
            }
            .frame(width: 110)
            
            // 2. 정보 및 진행도
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(currentLevel.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Lv.\(currentLevel.rawValue + 1)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(brandColor.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // 게이지 바 (다음 레벨까지 남은 비율로 시각화)
                // * 편의상 다음 레벨 진행률까지 채워지는 것으로 표현
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        // 현재 진행률만큼 채우기 (단순화: 300일 기준 %로 표시)
                        // 더 디테일한 구간별 %를 원하면 로직 추가 가능
                        Rectangle()
                            .frame(width: min(CGFloat(Double(studyDays)/300.0) * geometry.size.width, geometry.size.width), height: 8)
                            .foregroundColor(brandColor)
                    }
                    .cornerRadius(4.0)
                }
                .frame(height: 8)
                
                Text("총 \(studyDays)일 출석 완료")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // ✨ 성장 방법 안내 문구 추가
                Text("타이머 기록 또는 플래너 완료로 성장해요!")
                    .font(.system(size: 10))
                    .foregroundColor(brandColor)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(15)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showBubble = true
                }
            }
        }
    }
    
    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func changeMessage() {
        withAnimation(.easeOut(duration: 0.1)) { showBubble = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            speechText = cheerMessages.randomElement() ?? "파이팅!"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showBubble = true }
        }
    }
}
