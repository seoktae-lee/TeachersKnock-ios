import Foundation

struct StudySubject: Identifiable, Codable, Hashable {
    var id: String { name } // 이름 자체가 고유 ID
    let name: String
    
    // 기존 코드와의 호환성을 위한 속성
    var localizedName: String { name }
}
