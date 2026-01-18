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
        ShopItem(type: "golem", name: "스톤 골렘", emoji: "🪨", price: 1500, description: "오랜 시간 다져진 단단한 의지.\n흔들리지 않는 집중력의 상징.", color: .brown, imageName: "stone_golem_lv1"),
        // 💸[캐릭터 상점 캐릭터 등록] 희귀 캐릭터: 포근한 구름
        ShopItem(type: "cloud", name: "클라우드 가디언", emoji: "☁️", price: 1500, description: "자유롭게 떠다니는 구름처럼,\n넓은 세상을 품을 잠재력.", color: .cyan, imageName: "cloud_lv1"),
        // 💸[캐릭터 상점 캐릭터 등록] 희귀 캐릭터: 유니콘 가디언
        ShopItem(type: "unicorn", name: "브라이트닝 유니콘", emoji: "🦄", price: 1500, description: "찬란한 빛을 머금은 신수.\n순수한 마음을 지키는 힘.", color: Color(red: 1.0, green: 0.85, blue: 0.4), imageName: "unicorn_lv1"),
        // 💸[캐릭터 상점 캐릭터 등록] 희귀 캐릭터: 크리스탈 울프
        ShopItem(type: "wolf", name: "크리스탈 울프", emoji: "🐺", price: 1500, description: "차가운 얼음 속에서도 피어나는 열정.\n냉철한 판단력의 상징.", color: Color(red: 0.4, green: 0.7, blue: 1.0), imageName: "wolf_lv1")
    ]
    
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isPurchasing = false // ✨ [New] 로딩 상태
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
                // ✨ [New] 구매 복원 버튼 (Apple 필수 요구사항)
                ToolbarItem(placement: .primaryAction) {
                    Button("복원") {
                        isPurchasing = true
                        PurchaseManager.shared.restorePurchases { success, error in
                            DispatchQueue.main.async {
                                isPurchasing = false
                                if success {
                                    // 복원 성공 시, 모든 캐릭터의 Entitlement를 확인하여 잠금 해제
                                    let types = ["golem", "cloud", "unicorn", "wolf"]
                                    for type in types {
                                        if PurchaseManager.shared.isPurchased(characterType: type) {
                                            CharacterManager.shared.unlockStartingCharacter(type: type, name: "")
                                            print("🔓 [Purchase] 구매 복원으로 '\(type)' 잠금 해제됨")
                                        }
                                    }
                                    
                                    // 복원 완료 메시지
                                    if let msg = error {
                                         errorMessage = msg
                                         showingErrorAlert = true
                                    } else {
                                         errorMessage = "구매 내역이 복원되었습니다."
                                         showingErrorAlert = true
                                    }
                                } else {
                                    errorMessage = error ?? "복원에 실패했습니다."
                                    showingErrorAlert = true
                                }
                            }
                        }
                    }
                }
            }
            .alert("알림", isPresented: $showingErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("상품 구매", isPresented: $showingAlert, presenting: selectedItem) { item in
                Button("구매하기", role: .none) {
                    guard let item = selectedItem else { return }
                    isPurchasing = true
                    // PurchaseManager 내부에서 type -> productID 매핑 처리됨
                    PurchaseManager.shared.purchase(productID: item.type) { success, error in
                        DispatchQueue.main.async {
                            isPurchasing = false
                            if success {
                                // 구매 성공 시 캐릭터 잠금 해제
                                CharacterManager.shared.unlockStartingCharacter(type: item.type, name: "")
                                print("🎉 구매 완료: \(item.name)")
                            } else {
                                print("❌ 구매 실패 또는 취소됨")
                                if let error = error {
                                    errorMessage = error
                                    showingErrorAlert = true
                                }
                            }
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: { item in
                if PurchaseManager.shared.isPurchased(characterType: item.type) {
                     Text("이미 구매하신 상품입니다.")
                } else {
                     Text("'\(item.name)'을(를) 구매하시겠습니까?")
                }
            }
            // ✨ [New]로딩 인디케이터 오버레이
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("처리 중...")
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
