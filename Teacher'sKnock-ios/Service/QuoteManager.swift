import Foundation
import FirebaseFirestore
import Combine

// Quote 타입을 유지하되, UserDefaults 저장을 위해 Codable을 적극 활용합니다.
struct Quote: Identifiable, Codable {
    var id: String?
    let text: String
    let author: String
    
    static let defaultQuote = Quote(text: "오늘도 합격을 향해 달려가요!", author: "티노")
}

class QuoteManager: ObservableObject {
    static let shared = QuoteManager()
    private let db = Firestore.firestore()
    
    // ✨ [수정] 초기값을 "가장 최근에 성공적으로 불러온 명언"으로 설정합니다.
    @Published var currentQuote: Quote = Quote.defaultQuote
    
    private init() {
        loadCachedQuote() // 초기화 시 로컬 캐시 먼저 로드
    }
    
    // 로컬 스토리지에 저장된 마지막 명언을 불러와서 화면 깜빡임을 방지합니다.
    private func loadCachedQuote() {
        if let data = UserDefaults.standard.data(forKey: "CachedQuoteData"),
           let decoded = try? JSONDecoder().decode(Quote.self, from: data) {
            self.currentQuote = decoded
        }
    }
    
    /// ✨ [수정] 자정(00시)과 오후 2시(14시) 기준 업데이트 체크
    func updateQuoteIfNeeded() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        // 오늘 날짜 문자열 (예: 2023-10-27)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: now)
        
        // 14시 이전이면 "AM", 이후면 "PM"으로 주기 구분
        let period = hour < 14 ? "AM" : "PM"
        let storageKey = "\(dateString)-\(period)"
        
        let lastUpdateKey = UserDefaults.standard.string(forKey: "LastQuoteUpdateKey")
        
        // 마지막 업데이트 키가 현재 주기와 다를 때만 Firebase에서 가져옵니다.
        if lastUpdateKey != storageKey {
            fetchQuoteFromFirebase { [weak self] newQuote in
                guard let self = self, let quote = newQuote else { return }
                
                DispatchQueue.main.async {
                    self.currentQuote = quote
                    self.saveQuoteToCache(quote, key: storageKey)
                }
            }
        }
    }
    
    private func saveQuoteToCache(_ quote: Quote, key: String) {
        // 1. 업데이트 키 저장
        UserDefaults.standard.set(key, forKey: "LastQuoteUpdateKey")
        
        // 2. 명언 데이터 객체 자체를 JSON으로 인코딩하여 저장
        if let encoded = try? JSONEncoder().encode(quote) {
            UserDefaults.standard.set(encoded, forKey: "CachedQuoteData")
        }
    }
    
    private func fetchQuoteFromFirebase(completion: @escaping (Quote?) -> Void) {
        db.collection("quotes").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("⚠️ 명언 데이터를 가져오지 못했습니다: \(error?.localizedDescription ?? "알 수 없는 오류")")
                completion(nil)
                return
            }
            
            if let randomDoc = documents.randomElement() {
                let data = randomDoc.data()
                let quote = Quote(
                    id: randomDoc.documentID,
                    text: data["text"] as? String ?? "오늘도 파이팅!",
                    author: data["author"] as? String ?? "티노"
                )
                completion(quote)
            }
        }
    }
}
