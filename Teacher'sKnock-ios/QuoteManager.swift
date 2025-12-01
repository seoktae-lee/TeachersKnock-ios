import Foundation
import FirebaseFirestore

// 명언 데이터 모델 (Firestore 데이터 구조에 맞춤)
struct Quote: Identifiable, Codable {
    var id: String? // 문서 ID
    let text: String
    let author: String
}

class QuoteManager {
    static let shared = QuoteManager() // 싱글톤 패턴 사용
    private let db = Firestore.firestore()
    private let historyKey = "quoteHistory" // 최근 본 명언 ID 저장 키
    
    private init() {}
    
    // ✨ Firestore에서 랜덤 명언 가져오기 (비동기)
    func fetchQuote(completion: @escaping (Quote?) -> Void) {
        // 1. 최근 본 명언 ID 리스트 가져오기
        let history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        
        // 2. 전체 명언 개수 확인 (문서 ID가 0~49라고 가정)
        // * 실제로는 컬렉션의 전체 문서를 가져오는 것은 비효율적이므로,
        // * 여기서는 0~49 사이의 랜덤 ID를 생성해서 가져오는 방식을 사용합니다.
        // * (아까 업로드할 때 id 필드에 index를 넣었으므로 가능합니다)
        
        var randomId: Int
        var attempts = 0
        
        // 중복되지 않는 ID 뽑기 (최대 10번 시도)
        repeat {
            randomId = Int.random(in: 0..<50) // 50개 명언 기준
            attempts += 1
        } while history.contains(String(randomId)) && attempts < 10
        
        // 3. Firestore에서 해당 ID를 가진 명언 찾기
        db.collection("quotes").whereField("id", isEqualTo: randomId).getDocuments { snapshot, error in
            if let error = error {
                print("명언 가져오기 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = snapshot?.documents.first else {
                print("해당 ID의 명언을 찾을 수 없음")
                completion(nil)
                return
            }
            
            let data = document.data()
            let text = data["text"] as? String ?? "오늘도 파이팅!"
            let author = data["author"] as? String ?? "Tino"
            
            let quote = Quote(id: String(randomId), text: text, author: author)
            
            // 4. 히스토리 업데이트 (새로운 명언 ID 추가)
            self.updateHistory(newId: String(randomId))
            
            completion(quote)
        }
    }
    
    // 최근 본 명언 리스트 업데이트 (최대 7개 유지)
    private func updateHistory(newId: String) {
        var history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        
        // 이미 있으면 제거하고 맨 뒤로 (최신화)
        if let index = history.firstIndex(of: newId) {
            history.remove(at: index)
        }
        history.append(newId)
        
        // 7개 넘으면 오래된 것 삭제
        if history.count > 7 {
            history.removeFirst()
        }
        
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}
