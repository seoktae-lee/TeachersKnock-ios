import Foundation
import RevenueCat
import StoreKit
import Combine
import SwiftUI

// ✨ [New] 구매 관리자 (Singleton)
class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()
    
    // ✨ Completion Hander Typealias
    typealias PurchaseCompletionHandler = (Bool, String?) -> Void
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    
    // ✨ [USER ACTION REQUIRED] RevenueCat Public API Key를 여기에 입력하세요.
    // GitHub 등에 코드를 올릴 때는 이 키를 숨기거나 환경변수로 관리하는 것이 좋습니다.
    private let revenueCatApiKey = "appl_EKrdrFWCXNUCCjvNWbJojkhDeOG"
    
    // ✨ 개발자 계정 미보유 시 true로 설정하여 시뮬레이션 모드 활성화
    // 이제 실제 연동을 위해 false로 변경합니다. API 키가 없으면 동작하지 않습니다.
    private let isSimulationMode = false
    
    private override init() {
        super.init()
    }
    
    func configure() {
        if isSimulationMode {
            print("✅ [PurchaseManager] 시뮬레이션 모드로 설정됨")
            fetchOfferings()
            return
        }
        
        // ✨ RevenueCat 초기화
        Purchases.logLevel = .debug // 개발 중 로그 확인용
        Purchases.configure(withAPIKey: revenueCatApiKey)
        
        Purchases.shared.delegate = self
        
        // 정보 로드
        fetchOfferings()
        refreshCustomerInfo()
        
        print("✅ [PurchaseManager] RevenueCat 설정 완료")
    }
    
    // 고객 정보(구매 내역) 새로고침
    func refreshCustomerInfo() {
        guard !isSimulationMode else { return }
        
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            if let info = info {
                self?.customerInfo = info
                print("👤 [PurchaseManager] 고객 정보 갱신 완료")
            }
        }
    }
    
    // 상품 정보 가져오기
    func fetchOfferings() {
        if isSimulationMode {
            // 시뮬레이션: 가짜 상품 정보 처리 (필요 시 구현)
            print("🛍️ [PurchaseManager] 시뮬레이션 상품 로드 (가상)")
            return
        }
        
        print("🛍️ [PurchaseManager] RevenueCat 상품 정보 요청 중...")
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                print("❌ [PurchaseManager] 상품 로드 실패: \(error.localizedDescription)")
                print("   상세 에러: \(error)")
            } else {
                self?.offerings = offerings
                
                if let current = offerings?.current {
                    print("✅ [PurchaseManager] Current Offering 로드 성공: \(current.identifier)")
                    print("   가능한 패키지: \(current.availablePackages.map { $0.storeProduct.productIdentifier })")
                } else {
                    print("⚠️ [PurchaseManager] Offerings는 로드되었으나 Current Offering이 비어있습니다.")
                    print("   RevenueCat 대시보드에서 'Offerings' 설정을 확인하고 'Current'로 지정되었는지 확인하세요.")
                    print("   전체 Offerings 목록: \(offerings?.all.keys.map { String($0) } ?? [])")
                }
            }
        }
    }
    
    // ✨ 내부 캐릭터 타입 -> RevenueCat Product Identifier 매핑
    private func getProductID(for characterType: String) -> String? {
        // App Store Connect에 등록한 Product ID와 일치해야 합니다.
        switch characterType {
        case "golem": return "com.teachersknock.character.golem"
        case "cloud": return "com.teachersknock.character.cloud"
        case "unicorn": return "com.teachersknock.character.unicorn"
        case "wolf": return "com.teachersknock.character.wolf"
        default: return nil
        }
    }
    
    // 구매 실행
    func purchase(productID: String, completion: @escaping PurchaseCompletionHandler) {
        if isSimulationMode {
            print("💳 [PurchaseManager] 시뮬레이션 구매 성공 처리")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { completion(true, nil) }
            return
        }
        
        // 1. Product ID로 매핑 확인 (입력된 productID가 내부 type인 경우 변환 시도)
        let actualProductID = getProductID(for: productID) ?? productID
        
        // 2. Offerings에서 해당 패키지 찾기
        if let package = offerings?.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier == actualProductID }) ??
                            offerings?.all.values.flatMap({ $0.availablePackages }).first(where: { $0.storeProduct.productIdentifier == actualProductID }) {
            
            // 2-1. 패키지를 찾은 경우 (Standard Flow)
            print("💳 [PurchaseManager] Offering 패키지 구매 요청: \(package.storeProduct.productIdentifier)")
            Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                self.handlePurchaseResult(completion: completion, error: error, userCancelled: userCancelled, customerInfo: customerInfo)
            }
            
        } else {
            // 2-2. 패키지를 찾지 못한 경우 -> 직접 제품 로드 시도 (Fallback)
            print("⚠️ [PurchaseManager] Offerings에서 상품을 찾을 수 없음. 직접 상품 조회를 시도합니다: \(actualProductID)")
            
            Purchases.shared.getProducts([actualProductID]) { [weak self] products in
                guard let self = self else { return }
                
                if let product = products.first {
                    print("✅ [PurchaseManager] 직접 상품 조회 성공. 구매 진행: \(product.productIdentifier)")
                    
                    Purchases.shared.purchase(product: product) { (transaction, customerInfo, error, userCancelled) in
                        self.handlePurchaseResult(completion: completion, error: error, userCancelled: userCancelled, customerInfo: customerInfo)
                    }
                } else {
                    let errorMsg = "해당 상품(\(actualProductID))을 찾을 수 없습니다. Offerings 설정과 App Store 제품 등록 상태를 확인해 주세요."
                    print("❌ [PurchaseManager] \(errorMsg)")
                    completion(false, errorMsg)
                }
            }
        }
    }
    
    // ✨ 공통 결과 처리 핸들러
    private func handlePurchaseResult(completion: @escaping PurchaseCompletionHandler, error: Error?, userCancelled: Bool, customerInfo: CustomerInfo?) {
        if let error = error {
            let errorMsg = "구매 실패: \(error.localizedDescription)"
            print("❌ [PurchaseManager] \(errorMsg)")
            completion(false, errorMsg)
        } else if userCancelled {
            print("⚠️ [PurchaseManager] 사용자 취소")
            completion(false, "구매가 취소되었습니다.")
        } else {
            print("✅ [PurchaseManager] 구매 성공!")
            self.customerInfo = customerInfo
            completion(true, nil)
        }
    }
    
    // 구매 복원
    func restorePurchases(completion: @escaping PurchaseCompletionHandler) {
        if isSimulationMode {
            print("🔄 [PurchaseManager] 시뮬레이션 복원 성공")
            completion(true, nil)
            return
        }
        
        print("🔄 [PurchaseManager] 구매 복원 시작...")
        Purchases.shared.restorePurchases { [weak self] (customerInfo, error) in
            if let error = error {
                let errorMsg = "복원 실패: \(error.localizedDescription)"
                print("❌ [PurchaseManager] \(errorMsg)")
                completion(false, errorMsg)
            } else {
                self?.customerInfo = customerInfo
                print("✅ [PurchaseManager] 복원 성공")
                // 복원된 내역 확인 로직은 호출부에서 customerInfo를 보고 처리
                if customerInfo?.entitlements.active.isEmpty == true {
                     completion(true, "복원할 구매 내역이 없습니다.")
                } else {
                     completion(true, nil)
                }
            }
        }
    }
    
    // 특정 캐릭터가 이미 구매되었는지 확인 (Entitlements 기준)
    func isPurchased(characterType: String) -> Bool {
        if isSimulationMode { return false }
        
        // Entitlement ID 매핑 (RevenueCat 대시보드 설정과 일치해야 함)
        let entitlementID = "unlock_\(characterType)"
        return customerInfo?.entitlements[entitlementID]?.isActive == true
    }
}

// ✨ Delegate 확장 (필요 시 추가 로직 구현)
extension PurchaseManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        print("🔄 [PurchaseManager] 고객 정보 업데이트 감지됨")
    }
}
