import Foundation
import FirebaseFirestore
import Combine

// ✨ [오류 해결] Quote 타입을 전역 범위로 선언하여 GoalListView에서 인식하도록 함
struct Quote: Identifiable, Codable {
    var id: String?
    let text: String
    let author: String
}

// ✨ [오류 해결] ObservableObject 프로토콜 준수
class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    private let db = Firestore.firestore()
    
    // ✨ [오류 해결] 이제 Combine 임포트로 인해 @Published가 정상 작동합니다.
    @Published var currentQuote: Quote = Quote(text: "오늘도 합격을 향해 달려가요!", author: "티노")
    
    private init() {}
    
    /// ✨ [요구사항 ②] 00시/14시 기준 업데이트 로직
    func updateQuoteIfNeeded() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: now))
        
        let period = hour < 14 ? "AM" : "PM"
        let storageKey = "\(today)-\(period)"
        
        let lastUpdate = UserDefaults.standard.string(forKey: "LastQuoteUpdateKey")
        
        if lastUpdate != storageKey {
            fetchQuoteFromFirebase { [weak self] newQuote in
                if let quote = newQuote {
                    DispatchQueue.main.async {
                        self?.currentQuote = quote
                        UserDefaults.standard.set(storageKey, forKey: "LastQuoteUpdateKey")
                    }
                }
            }
        }
    }
    
    private func fetchQuoteFromFirebase(completion: @escaping (Quote?) -> Void) {
        db.collection("quotes").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                completion(nil)
                return
            }
            
            if let randomDoc = documents.randomElement() {
                let data = randomDoc.data()
                let quote = Quote(
                    id: randomDoc.documentID,
                    text: data["text"] as? String ?? "오늘도 파이팅!",
                    author: data["author"] as? String ?? "T-No"
                )
                completion(quote)
            }
        }
    }
}
