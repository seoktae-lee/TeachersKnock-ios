import Foundation

// 명언 데이터 모델
struct Quote {
    let text: String
    let author: String
}

// 명언 관리자 (데이터 제공)
struct QuoteManager {
    // 임용고시생/교대생을 위한 응원 명언 리스트
    static let quotes: [Quote] = [
        Quote(text: "교육은 세상을 바꿀 수 있는 가장 강력한 무기다.", author: "넬슨 만델라"),
        Quote(text: "아이들을 가르치는 것은 그들의 미래를 만지는 것이다.", author: "헨리 아담스"),
        Quote(text: "좋은 선생님은 촛불과 같다. 스스로를 태워 다른 사람의 길을 밝힌다.", author: "무스타파 케말 아타튀르크"),
        Quote(text: "꿈을 꿀 수 있다면, 그 꿈을 이룰 수도 있다.", author: "월트 디즈니"),
        Quote(text: "멈추지 않는 이상, 얼마나 천천히 가는지는 중요하지 않다.", author: "공자"),
        Quote(text: "오늘 걷지 않으면 내일은 뛰어야 한다.", author: "카를레스 푸욜"),
        Quote(text: "성공의 비결은 시작하는 것이다.", author: "마크 트웨인"),
        Quote(text: "노력은 배신하지 않는다. 다만 시간이 걸릴 뿐이다.", author: "미상"),
        Quote(text: "최고의 복수는 엄청난 성공이다.", author: "프랭크 시나트라"),
        Quote(text: "당신이 포기하고 싶을 때, 당신이 왜 시작했는지를 기억하라.", author: "미상")
    ]
    
    // 랜덤으로 명언 하나를 반환하는 함수
    static func getRandomQuote() -> Quote {
        return quotes.randomElement() ?? quotes[0]
    }
}
