import SwiftUI

struct StartingCharacterSelectionView: View {
    @Environment(\.dismiss) var dismiss
    
    // 선택된 데이터 반환 클로저
    var onSelect: (String, String) -> Void
    
    @State private var selectedType: String? = nil
    @State private var characterName: String = ""
    @State private var isAnimateStart = false
    
    let options = [
        (type: "bird", name: "열정의 불꽃", emoji: "🥚", color: Color.orange, desc: "뜨거운 열정으로\n알을 깨고 나오는 불 속성 캐릭터"),
        (type: "plant", name: "성실의 새싹", emoji: "🤎", color: Color.green, desc: "묵묵히 뿌리를 내리고\n꽃을 피우는 풀 속성 캐릭터"),
        (type: "sea", name: "지혜의 바다", emoji: "🧊", color: Color.blue, desc: "깊은 지혜를 품고\n세상을 품는 물 속성 캐릭터")
    ]
    
    var body: some View {
        ZStack {
            // 배경색 (선택에 따라 은은하게 변경)
            LinearGradient(
                gradient: Gradient(colors: [
                    selectedType == nil ? Color.gray.opacity(0.1) : (options.first(where: {$0.type == selectedType})?.color.opacity(0.1) ?? Color.white),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: selectedType)
            
            VStack(spacing: 30) {
                // 헤더
                VStack(spacing: 8) {
                    Text("운명의 파트너 선택")
                        .font(.system(size: 28, weight: .black))
                        .opacity(isAnimateStart ? 1 : 0)
                        .offset(y: isAnimateStart ? 0 : -20)
                    
                    Text("당신의 꿈을 함께 이룰 친구를 골라주세요.\n선택한 파트너는 변경할 수 없습니다.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimateStart ? 1 : 0)
                        .offset(y: isAnimateStart ? 0 : -20)
                }
                .padding(.top, 40)
                
                // 캐릭터 카드 리스트
                HStack(spacing: 15) {
                    ForEach(options, id: \.type) { option in
                        CharacterSelectionCard(
                            option: option,
                            isSelected: selectedType == option.type,
                            isDimmed: selectedType != nil && selectedType != option.type
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                if selectedType == option.type {
                                    // 이미 선택된 것 다시 누르면 취소? (아니면 유지)
                                    // selectedType = nil
                                } else {
                                    selectedType = option.type
                                    // 이름 초기화 (기본값 설정은 나중에)
                                    characterName = "" 
                                }
                            }
                        }
                    }
                }
                .frame(height: 350)
                .opacity(isAnimateStart ? 1 : 0)
                .scaleEffect(isAnimateStart ? 1 : 0.9)
                
                // 하단 입력 및 완료 영역
                if let selected = options.first(where: {$0.type == selectedType}) {
                    VStack(spacing: 20) {
                        // 선택된 캐릭터 설명
                        Text(selected.desc)
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        
                        // 이름 입력창
                        VStack(alignment: .leading, spacing: 8) {
                            Text("파트너의 이름")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            TextField("예: \(selected.name)", text: $characterName)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selected.color.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        
                        // 완료 버튼
                        Button(action: {
                            let nameToUse = characterName.isEmpty ? selected.name : characterName
                            onSelect(selected.type, nameToUse)
                            dismiss()
                        }) {
                            Text("이 파트너와 시작하기")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selected.color) // 캐릭터 테마 색상 사용
                                .cornerRadius(16)
                                .shadow(color: selected.color.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                        .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimateStart = true
            }
        }
    }
}

// 개별 캐릭터 카드 뷰
struct CharacterSelectionCard: View {
    let option: (type: String, name: String, emoji: String, color: Color, desc: String)
    let isSelected: Bool
    let isDimmed: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(
                        color: isSelected ? option.color.opacity(0.4) : Color.black.opacity(0.05),
                        radius: isSelected ? 15 : 5,
                        x: 0,
                        y: 5
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? option.color : Color.clear, lineWidth: 3)
                    )
                
                VStack(spacing: 15) {
                    if let imageName = CharacterLevel.lv1.imageName(for: option.type) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: isSelected ? 100 : 80) // 이미지 크기 조정
                            .padding(10)
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    } else {
                        Text(option.emoji)
                            .font(.system(size: isSelected ? 80 : 60))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    }
                    
                    Text(option.name.split(separator: " ").last ?? "") // "티노", "새싹" 등만 표시
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? option.color : .gray)
                }
            }
            .scaleEffect(isDimmed ? 0.9 : 1.0)
            .opacity(isDimmed ? 0.5 : 1.0)
            .rotation3DEffect(
                .degrees(isSelected ? 0 : (isDimmed ? 0 : 0)), // 심플하게 처리
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
        }
        .frame(width: isSelected ? 140 : 100, height: isSelected ? 220 : 180)
    }
}
