import SwiftUI

// 말풍선 꼬리가 왼쪽(캐릭터 방향)으로 향하는 Shape
struct LeftTailBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 12
        let arrowSize: CGFloat = 8
        var path = Path()
        
        // 왼쪽 상단 (꼬리 시작점 위)
        path.move(to: CGPoint(x: arrowSize + radius, y: 0))
        
        // 상단 라인
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - radius, y: radius), radius: radius, startAngle: Angle(radians: -Double.pi/2), endAngle: Angle(radians: 0), clockwise: false)
        
        // 우측 라인
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addArc(center: CGPoint(x: rect.width - radius, y: rect.height - radius), radius: radius, startAngle: Angle(radians: 0), endAngle: Angle(radians: Double.pi/2), clockwise: false)
        
        // 하단 라인
        path.addLine(to: CGPoint(x: arrowSize + radius, y: rect.height))
        path.addArc(center: CGPoint(x: arrowSize + radius, y: rect.height - radius), radius: radius, startAngle: Angle(radians: Double.pi/2), endAngle: Angle(radians: Double.pi), clockwise: false)
        
        // 좌측 라인 (꼬리 부분)
        path.addLine(to: CGPoint(x: arrowSize, y: rect.midY + 6))
        path.addLine(to: CGPoint(x: 0, y: rect.midY)) // 꼬리 끝
        path.addLine(to: CGPoint(x: arrowSize, y: rect.midY - 6))
        path.closeSubpath()
        
        return path
    }
}

// 메인 캐릭터 뷰 (홈 화면용)
struct MainCharacterView: View {
    @ObservedObject var characterManager = CharacterManager.shared
    @EnvironmentObject var settingsManager: SettingsManager // ✨ 추가
    @Binding var showStorage: Bool
    
    let primaryGoalTitle: String?
    let dDay: Int
    
    @State private var currentCheer: String = ""
    @State private var isWiggling: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            // ✨ [수정] 보관함 버튼을 UI 박스 밖 우측 상단으로 이동
            HStack(alignment: .bottom) {
                // ✨ 교육청 정보 표시 (선택된 경우에만)
                if let office = settingsManager.targetOffice {
                    HStack(spacing: 4) {
                        Text("\(office.rawValue) 소속 예비 초등교사")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 3)
                }
                
                Spacer()
                
                // ✨ [DEBUG] 임시 디버그 버튼 (테스트 중) - 주석 처리됨
                // ✨ [DEBUG] 임시 디버그 버튼 제거됨

                
                Button(action: { showStorage = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.caption2)
                        Text("보관함")
                            .font(.caption2)
                            .bold()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.8)) // 배경 살짝 투명하게
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 3)
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 25) // 카드 내부 패딩과 라인 맞춤
            
            ZStack(alignment: .bottom) {
                // 배경: 그라데이션
                LinearGradient(gradient: Gradient(colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color.white]), startPoint: .top, endPoint: .bottom)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                
                // ✨ [NEW] 교육청 로고 워터마크 (항상 표시)
                // 미선택 시: 기본 로고, 선택 시: 해당 교육청 로고 (없으면 기본 로고)
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            // 로고 이미지 결정 로직
                            let logoName: String = {
                                if let office = settingsManager.targetOffice,
                                    UIImage(named: office.logoImageName) != nil {
                                    return office.logoImageName
                                } else {
                                    return "TeachersKnockLogo"
                                }
                            }()
                            
                            Image(logoName)
                                .resizable()
                                .scaledToFill() // ✨ 비율 유지하며 꽉 채우기 (글씨 잘리게)
                                .frame(width: 140, height: 140, alignment: .leading) // ✨ 왼쪽(심벌) 기준 정렬
                                .clipped() // 넘치는 부분 자르기
                                .opacity(0.12) // 투명도 약간만 높임 (잘라내면 여백이 줄어드므로)
                                .blendMode(.multiply)
                                .rotationEffect(.degrees(-15)) // 살짝 기울기
                                .offset(x: 10, y: 40) // 위치 미세 조정
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24)) // 카드 모양에 맞춰 자르기
                
                if let character = characterManager.equippedCharacter {
                    VStack(spacing: 0) {
                        HStack(spacing: 15) {
                            // 왼쪽: 캐릭터 영역
                            VStack {
                                // 홈 화면에서는 등급 배지 숨김 (showBadge: false)
                                CharacterAvatarView(character: character, showBadge: false)
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(isWiggling ? 1.15 : 1.1)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isWiggling)
                                    .onTapGesture {
                                        triggerInteraction()
                                    }
                            }
                            
                            // 오른쪽: 정보 영역
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 4)
                                
                                // 말풍선 (보관함 버튼이 밖으로 나갔으므로 우측 패딩 제거)
                                Text(currentCheer.isEmpty ? getRandomCheer() : currentCheer)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 12)
                                    .padding(.leading, 20)
                                    .background(
                                        LeftTailBubbleShape()
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.05), radius: 2)
                                    )
                                // .padding(.trailing, 50) // ✨ 제거됨
                                    .id("cheer_\(currentCheer)")
                                    .transition(.opacity.animation(.easeInOut))
                                
                                Spacer() // ✨ 말풍선 크기에 상관없이 목표 정보는 하단 고정
                                
                                // 목표 정보 및 D-Day
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(primaryGoalTitle ?? "목표를 설정해주세요")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.blue.opacity(0.8))
                                        .lineLimit(1)
                                    
                                    HStack(alignment: .bottom, spacing: 2) {
                                        Text("D-")
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary.opacity(0.8))
                                            .padding(.bottom, 6)
                                        
                                        // D-Day 숫자 표시 (크기 고정)
                                        Text("\(max(0, dDay))")
                                            .font(.system(size: 42, weight: .black, design: .rounded))
                                            .foregroundColor(.blue)
                                            .offset(y: 4)
                                            .fixedSize() // 크기 고정으로 축소 방지
                                    }
                                }
                            }
                            .frame(height: 130) // 오른쪽 영역 높이 확보 (Spacer 작동용)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 25)
                        
                        Spacer()
                        
                        // ✨ [수정] 경험치(일수) 기반이 아닌 실제 저장된 레벨 사용 (등급별 제한 반영됨)
                        VStack(spacing: 6) {
                            let level = CharacterLevel(rawValue: character.level) ?? .lv1
                            let nextDays = level.daysRequiredForNextLevel
                            let currentStart = level.daysRequiredForCurrentLevel
                            let progress = nextDays > 0 ? Double(character.exp - currentStart) / Double(nextDays - currentStart) : 1.0
                            let daysLeft = max(0, nextDays - character.exp)
                            
                            // 진행도 바
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 10)
                                    
                                    if !level.isMaxLevel(for: character.type) {
                                        Capsule()
                                            .fill(CharacterManager.shared.getRarityColor(type: character.type))
                                            .frame(width: geometry.size.width * CGFloat(progress), height: 10)
                                    } else {
                                        Capsule()
                                            .fill(Color.purple)
                                            .frame(width: geometry.size.width, height: 10)
                                    }
                                }
                            }
                            .frame(height: 10)
                            
                            // 텍스트 정보 (좌: 레벨, 우: 남은 일수)
                            HStack {
                                Text("Lv.\(level.rawValue + 1)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !level.isMaxLevel(for: character.type) {
                                    Text("다음 레벨까지 \(daysLeft)일 남음")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.gray)
                                } else {
                                    Text("최종 진화 완료")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, 20)
                    }
                    
                    // ✨ [Debug] 테스트용 버튼 제거됨 (Cleanup)
                } else {
                    // ✨ [New] 캐릭터 미선택 시 안내 Empty State
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("아직 파트너가 없어요")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("새 목표를 추가하여 나만의 캐릭터와\n목표 교육청을 설정해보세요!")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 220) // 높이를 조금 더 늘려서 하단 바 공간 확보
        }
        .padding(.horizontal)
        .onAppear {
            if currentCheer.isEmpty { currentCheer = getRandomCheer() }
        }
    }
    
    private func triggerInteraction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        isWiggling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isWiggling = false }
        
        withAnimation { currentCheer = getRandomCheer() }
    }
    
    private func getRandomCheer() -> String {
        let cheers = [
            "예비 선생님, 오늘도 힘내요",
            "아이들이 선생님을 기다려요🏫",
            "당신의 꿈을 티처스 노크가 진심으로 응원합니다",
            "오늘의 노력은 절대 배신하지 않아요",
            "멋진 선생님이 될 거예요✨",
            "포기하지 않는 당신이 아름다워요",
            "합격의 순간이 다가오고 있어요!",
            "당신은 이미 충분히 잘하고 있어요👏",
            "건강 챙기면서 공부하세요💊",
            "교실에서 만날 그날을 위해!!",
            "오늘도 한 걸음 더 앞으로 나아갔어요👣",
            "오늘의 하루가 큰 변화를 가져올 거예요",
            "모두 함께 응원해요💖",
            "이번 시험에서 당신의 힘을 발휘해 보세요",
            "오늘 하루도 최대한 웃으면서 보내세요🎉",
            "너를 응원하는 수 많은 사람들이 있어🫂",
            "절대 포기하지마",
            "나를 멋있게 진화시켜줘!!",
            "오늘 하루도 힘내세요💪",
            "미미한 하루가 모여 큰 변화로 다가 올 거에요🌟"
        ]
        return cheers.randomElement() ?? "파이팅!"
    }
}

// 간단한 캐릭터 표시용 뷰
struct CharacterAvatarView: View {
    let character: UserCharacter
    // ✨ [추가] 배지 표시 여부를 제어하는 플래그 (기본값 true)
    var showBadge: Bool = true
    
    @State private var isAnimating = false
    
    var body: some View {
        let level = CharacterLevel(rawValue: character.level) ?? .lv1
        let rarityTitle = CharacterManager.shared.getRarityTitle(type: character.type)
        let rarityColor = CharacterManager.shared.getRarityColor(type: character.type)
        
        ZStack {
            // 배경 원
            Circle()
                .fill(rarityColor.opacity(0.1))
            
            // 캐릭터 표시 (이미지 우선, 없으면 이모지)
            if let imageName = level.imageName(for: character.type) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(15) // 이모지 대비 이미지가 꽉 차보일 수 있어서 패딩 추가
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
            } else {
                Text(level.emoji(for: character.type))
                    .font(.system(size: 80))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
            }
            
            // ✨ [수정] 배지 표시 옵션 적용
            if showBadge {
                VStack {
                    Text(rarityTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(rarityColor))
                        .shadow(radius: 2)
                        .padding(.top, 10)
                    Spacer()
                }
            }
            
            // 레벨 배지 (항상 표시)
            VStack {
                Spacer()
                Text("Lv.\(character.level + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rarityColor.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 10)
            }
        }
    }
}
