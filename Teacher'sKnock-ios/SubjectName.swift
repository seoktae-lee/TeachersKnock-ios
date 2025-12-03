import Foundation
import SwiftUI // ✨ Color 사용을 위해 추가

// 초등 임용고시 과목을 정의하는 Enum
enum SubjectName: String, Codable, CaseIterable, Identifiable {
    case education = "교육학"
    case teachingEssay = "교직논술"
    case korean = "국어"
    case math = "수학"
    case socialStudies = "사회"
    case science = "과학"
    case english = "영어"
    case ethics = "도덕"
    case pe = "체육"
    case music = "음악"
    case art = "미술"
    case practicalArts = "실과"
    case rightLiving = "바른생활"
    case wiseLiving = "슬기로운생활"
    case pleasantLiving = "즐거운생활"
    case generalCreative = "총론/창의적체험활동"
    case secondRound = "2차 면접/실연"
    case selfStudy = "자율선택"

    var id: String { self.rawValue }
    var localizedName: String { return self.rawValue }

    // ✨ [NEW] 과목별 고유 색상 정의 (파스텔 톤 권장)
    var color: Color {
        switch self {
        case .education: return Color(hex: "5D9CEC") // 파랑 (교육학)
        case .teachingEssay: return Color(hex: "4A89DC") // 진한 파랑
        case .korean: return Color(hex: "ED5565") // 빨강
        case .math: return Color(hex: "A0D468") // 초록
        case .socialStudies: return Color(hex: "FFCE54") // 노랑
        case .science: return Color(hex: "AC92EC") // 보라
        case .english: return Color(hex: "FC6E51") // 주황
        case .ethics: return Color(hex: "48CFAD") // 민트
        case .pe: return Color.cyan
        case .music: return Color.pink
        case .art: return Color.purple
        case .practicalArts: return Color.brown
        default: return Color.gray // 기타 과목
        }
    }
    
    // 기본 과목 목록
    static var defaultSubjects: [SubjectName] {
        return [.education, .teachingEssay, .korean, .math, .socialStudies, .science, .english, .generalCreative]
    }
    
    // ✨ 문자열(일정 제목)에서 과목 색상을 찾아내는 헬퍼 함수
    static func color(for title: String) -> Color {
        // 제목에 과목명이 포함되어 있는지 확인 (예: "교육학 암기" -> 교육학 색상 반환)
        for subject in SubjectName.allCases {
            if title.contains(subject.rawValue) {
                return subject.color
            }
        }
        return Color.blue.opacity(0.5) // 못 찾으면 기본 파란색
    }
}

// ✨ [Hex 코드 지원용 확장] - 파일 맨 아래에 붙여넣으세요
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double((rgb) & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
