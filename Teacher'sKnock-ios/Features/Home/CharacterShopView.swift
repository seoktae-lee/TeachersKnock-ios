import SwiftUI

struct ShopItem: Identifiable {
    let id = UUID()
    let type: String
    let name: String
    let emoji: String
    let price: Int
    let description: String
    let color: Color
    var imageName: String? = nil // ✨ [New] 이미지 이름 (옵셔널)
    var isPurchased: Bool = false
}

struct CharacterShopView: View {
    @Environment(\.dismiss) var dismiss
    
    // Mock Data
    @State private var shopItems = [
        // 💸[캐릭터 상점 캐릭터 등록] 희귀 캐릭터: 스톤 골렘
        ShopItem(type: "golem", name: "단단한 바위", emoji: "🪨", price: 3000, description: "오랜 시간 다져진 단단한 의지.\n흔들리지 않는 집중력의 상징.", color: .brown, imageName: "stone_golem_lv1")
    ]
    
    @State private var showingAlert = false
    @State private var selectedItem: ShopItem?
    @State private var isPurchasing = false // ✨ [New] 로딩 상태
    
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
                    // ✨ [New] 실제 구매 로직 연결
                    isPurchasing = true
                    PurchaseManager.shared.purchase(productID: item.type) { success in
                        isPurchasing = false
                        if success {
                            // 구매 성공 시 캐릭터 잠금 해제
                            CharacterManager.shared.unlockStartingCharacter(type: item.type, name: "")
                            // 성공 알림 (선택 사항)
                        } else {
                            // 실패 알림
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: { item in
                Text("'\(item.name)'을(를) ₩\(item.price)(으)로 구매하시겠습니까?\n(현재는 체험판이라 실제 결제되지 않습니다)")
            }
            // ✨ [New] 로딩 인디케이터 오버레이
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("구매 처리 중...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
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
                    
                    // ✨ [수정] 이미지가 있으면 이미지 표시, 없으면 이모지
                    if let imageName = item.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    } else {
                        Text(item.emoji)
                            .font(.system(size: 50))
                    }
                    
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
                    Text("₩\(item.price)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
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
