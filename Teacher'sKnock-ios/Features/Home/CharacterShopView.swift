import SwiftUI

struct ShopItem: Identifiable {
    let id = UUID()
    let type: String
    let name: String
    let emoji: String
    let price: Int
    let description: String
    let color: Color
    var isPurchased: Bool = false
}

struct CharacterShopView: View {
    @Environment(\.dismiss) var dismiss
    
    // Mock Data
    @State private var shopItems = [
        ShopItem(type: "phoenix", name: "전설의 불사조", emoji: "🦚", price: 1000, description: "영원한 열정으로 공부를 돕는\n전설 속의 새", color: .red),
        ShopItem(type: "tree", name: "천년의 고목", emoji: "🌳", price: 800, description: "천 년의 지혜가 담긴\n든든한 버팀목", color: .green),
        ShopItem(type: "whale", name: "우주의 고래", emoji: "🐋", price: 1200, description: "지식의 바다를 유영하는\n신비로운 고래", color: .purple),
        ShopItem(type: "robot", name: "AI 튜터", emoji: "🤖", price: 500, description: "완벽한 계획을 세워주는\n스마트한 파트너", color: .gray),
        ShopItem(type: "unicorn", name: "꿈의 유니콘", emoji: "🦄", price: 1500, description: "합격의 꿈을 현실로 만드는\n마법의 유니콘", color: .pink),
        ShopItem(type: "dragon", name: "용기의 드래곤", emoji: "🐉", price: 2000, description: "시험장의 두려움을 없애줄\n용맹한 드래곤", color: .orange)
    ]
    
    @State private var showingAlert = false
    @State private var selectedItem: ShopItem?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 상단 배너 (재화 표시)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("MY GEMS")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "diamond.fill")
                                        .foregroundColor(.blue)
                                    Text("0") // Mock Balance
                                        .font(.title2)
                                        .fontWeight(.black)
                                }
                            }
                            Spacer()
                            Button(action: { 
                                // 충전 페이지 이동 (미구현)
                            }) {
                                Text("충전하기")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.blue))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // 상점 아이템 그리드
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(shopItems) { item in
                                ShopItemCard(item: item) {
                                    selectedItem = item
                                    showingAlert = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("캐릭터 상점")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("상품 구매", isPresented: $showingAlert, presenting: selectedItem) { item in
                Button("구매하기", role: .none) {
                    // 실제 구매 로직은 나중에 구현
                }
                Button("취소", role: .cancel) {}
            } message: { item in
                Text("'\(item.name)'을(를) 구매하시겠습니까?\n(현재는 체험판이라 실제 결제되지 않습니다)")
            }
        }
    }
}

struct ShopItemCard: View {
    let item: ShopItem
    let action: () -> Void
    
    var body: some View {
        let rarityTitle = CharacterManager.shared.getRarityTitle(type: item.type)
        let rarityColor = CharacterManager.shared.getRarityColor(type: item.type)
        
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Text(item.emoji)
                        .font(.system(size: 50))
                    
                    // ✨ [추가] 상점 아이템 희귀도 배지
                    VStack {
                        HStack {
                            Text(rarityTitle)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(rarityColor))
                                .shadow(radius: 2)
                            Spacer()
                        }
                        Spacer()
                    }
                    .offset(x: -10, y: -10)
                }
                
                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 35) // 높이 고정
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                    Text("\(item.price)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
