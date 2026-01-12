import SwiftUI

struct CharacterStorageView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var characterManager = CharacterManager.shared
    @State private var showShop = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 헤더
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        Text("나의 파트너 보관함")
                            .font(.title2)
                            .bold()
                        
                        Text("함께 꿈을 이룰 파트너를 선택해주세요")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // 그리드 리스트
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(characterManager.characters) { character in
                            CharacterStorageCard(
                                character: character,
                                isEquipped: characterManager.equippedCharacterType == character.type
                            )
                            .onTapGesture {
                                withAnimation {
                                    characterManager.equipCharacter(type: character.type)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                
                // ✨ [추가] 상점 이동 버튼
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showShop = true }) {
                        Image(systemName: "storefront.fill") // or bag.fill
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showShop) {
                CharacterShopView()
            }
        }
    }
}

struct CharacterStorageCard: View {
    let character: UserCharacter
    let isEquipped: Bool
    
    var body: some View {
        let level = CharacterLevel(rawValue: character.level) ?? .lv1
        let rarityTitle = CharacterManager.shared.getRarityTitle(type: character.type)
        let rarityColor = CharacterManager.shared.getRarityColor(type: character.type)
        
        VStack(spacing: 12) {
            ZStack {
                // 카드 배경
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: isEquipped ? .blue.opacity(0.3) : .black.opacity(0.05), radius: isEquipped ? 8 : 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isEquipped ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                VStack(spacing: 8) {
                    // 장착 중 표시 & 등급 배지
                    HStack {
                        // ✨ [추가] 등급 배지
                        Text(rarityTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(rarityColor))
                        
                        Spacer()
                        
                        if isEquipped {
                            Text("사용 중")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // 캐릭터 이미지 (이미지 우선, 없으면 이모지)
                    if let imageName = level.imageName(for: character.type) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80) // 텍스트 크기 대응
                            .padding(10)
                            .grayscale(character.isUnlocked ? 0 : 1.0)
                            .opacity(character.isUnlocked ? 1.0 : 0.5)
                    } else {
                        Text(level.emoji(for: character.type))
                            .font(.system(size: 60))
                            .grayscale(character.isUnlocked ? 0 : 1.0)
                            .opacity(character.isUnlocked ? 1.0 : 0.5)
                    }
                    
                    // 정보
                    VStack(spacing: 2) {
                        Text(character.name)
                            .font(.headline)
                            .foregroundColor(character.isUnlocked ? .primary : .gray)
                        
                        if character.isUnlocked {
                            Text("Lv.\(character.level + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("잠김")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 15)
                }
            }
            .frame(height: 220)
        }
    }
}
