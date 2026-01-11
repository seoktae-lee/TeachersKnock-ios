import Foundation
import RevenueCat
import StoreKit
import Combine
import SwiftUI

// ✨ [New] 구매 관리자 (Singleton)
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    
    // ✨ 개발자 계정 미보유 시 true로 설정하여 시뮬레이션 모드 활성화
    // RevenueCat API 키가 없거나 로드 실패 시 자동으로 true로 간주하는 로직도 포함
    private let isSimulationMode = true 
    
    private init() {}
    
    func configure() {
        // ✨ 실제 API 키가 있다면 여기에 입력 (현재는 시뮬레이션 모드라 주석 처리)
        // Purchases.configure(withAPIKey: "appl_Your_RevenueCat_Key_Here")
        
        // 델리게이트 설정 등 추가 작업
        print("✅ [PurchaseManager] 설정 완료 (Simulation Mode: \(isSimulationMode))")
        
        // 상품 정보 가져오기 (시뮬레이션 또는 실제)
        fetchOfferings()
    }
    
    // 상품 정보 가져오기
    func fetchOfferings() {
        if isSimulationMode {
            // 시뮬레이션: 가짜 상품 정보 생성 (실제 RevenueCat 객체를 만들 수 없으므로 Published 변수 외 별도 관리 필요할 수도 있음)
            print("🛍️ [PurchaseManager] 시뮬레이션 상품 로드 완료")
            return
        }
        
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            if let error = error {
                print("❌ [PurchaseManager] 상품 로드 실패: \(error.localizedDescription)")
            } else {
                self?.offerings = offerings
                print("✅ [PurchaseManager] 상품 로드 성공")
            }
        }
    }
    
    // 구매 실행
    func purchase(productID: String, completion: @escaping (Bool) -> Void) {
        if isSimulationMode {
            print("💳 [PurchaseManager] 시뮬레이션 구매 시작: \(productID)")
            
            // 1초 뒤 성공 처리
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("✅ [PurchaseManager] 시뮬레이션 구매 성공!")
                completion(true)
            }
            return
        }
        
        // 실제 구매 로직 (RevenueCat)
        guard let package = offerings?.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) else {
            print("❌ [PurchaseManager] 해당 상품(\(productID))을 찾을 수 없음")
            completion(false)
            return
        }
        
        Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
            if let error = error {
                print("❌ [PurchaseManager] 구매 실패: \(error.localizedDescription)")
                completion(false)
            } else if userCancelled {
                print("⚠️ [PurchaseManager] 사용자 취소")
                completion(false)
            } else {
                print("✅ [PurchaseManager] 구매 성공!")
                self.customerInfo = customerInfo
                completion(true)
            }
        }
    }
    
    // 구매 복원
    func restorePurchases() {
        if isSimulationMode {
            print("🔄 [PurchaseManager] 시뮬레이션 구매 복원 완료")
            return
        }
        
        Purchases.shared.restorePurchases { [weak self] (customerInfo, error) in
            if let error = error {
                print("❌ [PurchaseManager] 복원 실패: \(error.localizedDescription)")
            } else {
                self?.customerInfo = customerInfo
                print("✅ [PurchaseManager] 복원 성공")
            }
        }
    }
}
