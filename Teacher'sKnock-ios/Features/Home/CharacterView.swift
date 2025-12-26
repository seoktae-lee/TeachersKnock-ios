import SwiftUI
import SwiftData
import FirebaseAuth

struct CharacterView: View {
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
    let totalGoalDays: Int
    let characterName: String
    let themeColorName: String
    
    // 테마 컬러 변환
    var themeColor: Color {
        GoalColorHelper.color(for: themeColorName)
    }
    
    @State private var speechText: String = "오늘도 파이팅!"
    @State private var showBubble: Bool = false
    
    let cheerMessages = [
        "오늘도 파이팅!", "합격이 보여요!", "조금만 더 힘내!", "멋진 선생님이 될 거예요!",
        "포기하지 마세요!", "당신을 믿어요!", "꾸준함이 답이다!", "넌 할 수 있어!",
        "오늘 하루도 멋져!", "너의 능력을 믿어봐", "선생님, 저 벌써 3월이 기다려져요!",
        "합격이라는 마침표가 아닌, 꿈의 시작점!", "지금 흘리는 값진 땀방울.",
        "너는 이미 훌륭한 선생님.", "칠판 앞에 선 선생님 모습, 너무 멋져!",
        "조금 느려도 괜찮아", "마지막까지 펜 꽉 잡아!"
    ]
    
    // ✨ [수정] init에 name, color 추가
    init(userId: String, totalGoalDays: Int, characterName: String, themeColorName: String) {
        self.totalGoalDays = max(totalGoalDays, 1)
        self.characterName = characterName
        self.themeColorName = themeColorName
        
        _records = Query(filter: #Predicate<StudyRecord> { $0.ownerID == userId })
        _scheduleItems = Query(filter: #Predicate<ScheduleItem> { $0.ownerID == userId })
    }
    
    var studyDays: Int {
        let calendar = Calendar.current
        let timerDays = records.map { calendar.startOfDay(for: $0.date) }
        let plannerDays = scheduleItems.filter { $0.isCompleted }.map { calendar.startOfDay(for: $0.startDate) }
        let allUniqueDays = Set(timerDays + plannerDays)
        return allUniqueDays.count
    }
    
    var currentLevel: CharacterLevel {
        CharacterLevel.getLevel(currentDays: studyDays, totalGoalDays: totalGoalDays)
    }
    
    var progress: Double {
        if totalGoalDays == 0 { return 0 }
        return min(Double(studyDays) / Double(totalGoalDays), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // 1. 캐릭터 + 말풍선
            VStack(spacing: 5) {
                if showBubble {
                    Text(speechText)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
                        .overlay(
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.caption2).foregroundColor(.white).offset(y: 8),
                            alignment: .bottom
                        )
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: -5)
                }
                
                Text(currentLevel.emoji)
                    .font(.system(size: 60))
                    .padding()
                    .background(Circle().fill(Color.white))
                    // ✨ 그림자 색상도 테마 색으로 은은하게
                    .shadow(color: themeColor.opacity(0.3), radius: 8)
                    .onTapGesture {
                        triggerHapticFeedback()
                        changeMessage()
                    }
            }
            .frame(width: 110)
            
            // 2. 정보 및 진행도
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // ✨ 설정한 별명 표시
                    Text(characterName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("Lv.\(currentLevel.rawValue + 1)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.2)) // 테마 배경
                        .cornerRadius(8)
                }
                
                Text(currentLevel.title)
                    .font(.caption2).foregroundColor(.gray)
                
                // 게이지 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.3)
                            .foregroundColor(.gray)
                        
                        // ✨ 테마 색상으로 게이지 채우기
                        Rectangle()
                            .frame(width: max(progress * geometry.size.width, 0), height: 8)
                            .foregroundColor(themeColor)
                    }
                    .cornerRadius(4.0)
                }
                .frame(height: 8)
                
                Text("총 \(studyDays)일 / 목표 \(totalGoalDays)일")
                    .font(.caption).foregroundColor(.gray)
                
                Text("꾸준함이 합격을 만들어요!")
                    .font(.system(size: 10))
                    .foregroundColor(themeColor) // 테마 색상 텍스트
                    .padding(.top, 2)
            }
        }
        .padding()
        // ✨ 배경을 테마색의 아주 연한 톤으로
        .background(themeColor.opacity(0.08))
        .cornerRadius(15)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showBubble = true }
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
