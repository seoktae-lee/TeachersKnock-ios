import Foundation

// 공부 목적을 정의하는 Enum
enum StudyPurpose: String, Codable, CaseIterable {
    case lectureWatching = "인강시청"
    case reviewOrganize = "복습/정리"
    case conceptMemorization = "개념공부"
    case problemSolving = "문제풀이"
    case mockTest = "모의고사"
    case errorNote = "오답노트"
    case speaking = "말하기" // ✨ [추가됨] 말하기 모드
    case study = "스터디" 
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
            .speaking, // ✨ [추가] 말하기
            .study,
            .etc
        ]
    }
    
    // ✨ [추가] 유연한 매칭을 위한 정적 메서드
    // 저장된 문자열이 rawValue와 조금 다르거나(업데이트 등으로 인해), 영어 케이스 이름으로 저장되어 있어도
    // 최대한 올바른 목적을 찾아냅니다.
    static func flexibleMatch(_ value: String) -> StudyPurpose? {
        // 1. 정확한 RawValue 매칭 (가장 우선)
        if let exactMatch = StudyPurpose(rawValue: value) {
            return exactMatch
        }
        
        // 2. Case 이름(영어) 매칭
        // 예: "lectureWatching" 문자열이 들어오면 .lectureWatching 케이스를 반환
        // 미러링을 통해 케이스 이름을 문자열로 변환하여 비교합니다.
        for purpose in StudyPurpose.allCases {
            if String(describing: purpose) == value {
                return purpose
            }
        }
        
        // 3. (선택사항) 정규화 후 매칭 (공백 제거, 대소문자 무시 등 더 유연하게)
        // ✨ [개선] 대소문자 무시 로직 추가
        let normalizedValue = value.replacingOccurrences(of: " ", with: "").lowercased()
        for purpose in StudyPurpose.allCases {
            // rawValue 비교
            if purpose.rawValue.replacingOccurrences(of: " ", with: "").lowercased() == normalizedValue {
                return purpose
            }
            // case 이름 비교
            if String(describing: purpose).lowercased() == normalizedValue {
                return purpose
            }
        }
        
        return nil
    }
}
