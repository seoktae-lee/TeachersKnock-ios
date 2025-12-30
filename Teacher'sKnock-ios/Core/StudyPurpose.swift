import Foundation

// 공부 목적을 정의하는 Enum
enum StudyPurpose: String, Codable, CaseIterable {
    case lectureWatching = "인강시청"
    case reviewOrganize = "복습/정리"
    case conceptMemorization = "개념공부"
    case problemSolving = "문제풀이"
    case mockTest = "모의고사"
    case errorNote = "오답노트"
    case study = "스터디" // ✨ [추가됨] 스터디 항목
    case etc = "기타"

    var localizedName: String { return self.rawValue }
    
    // UI 표시 순서 정의
    static var orderedCases: [StudyPurpose] {
        // ✨ [추가됨] 메뉴에 표시될 순서에도 .study를 추가했습니다.
        return [
            .lectureWatching,
            .reviewOrganize,
            .conceptMemorization,
            .problemSolving,
            .mockTest,
            .errorNote,
            .study, // 오답노트 다음, 기타 전에 배치했습니다.
            .etc
        ]
    }
}
