import SwiftUI

// 과목 이름과 색상을 관리하는 매니저
struct SubjectName {
    
    // ✨ 13가지 초등 임용 필수 과목 리스트 (순서 중요)
    static let defaultList: [String] = [
        "교직논술", "국어", "영어", "총론/창체", "사회",
        "도덕", "실과", "수학", "미술", "통합교과",
        "과학", "음악", "체육"
    ]

    // ✨ 과목별 색상 반환 (13과목은 고정색, 나머지는 자동 생성)
    static func color(for subjectName: String) -> Color {
        switch subjectName {
        case "교직논술": return Color(hex: "4A89DC") // 진한 파랑
        case "국어": return Color(hex: "ED5565")    // 빨강
        case "영어": return Color(hex: "FC6E51")    // 주황
        case "총론/창체": return Color(hex: "FFCE54") // 노랑
        case "사회": return Color(hex: "F6BB42")    // 귤색
        case "도덕": return Color(hex: "48CFAD")    // 민트
        case "실과": return Color(hex: "A0D468")    // 연두
        case "수학": return Color(hex: "8CC152")    // 초록
        case "미술": return Color(hex: "AC92EC")    // 라벤더
        case "통합교과": return Color(hex: "5D9CEC") // 하늘색
        case "과학": return Color(hex: "967ADC")    // 보라
        case "음악": return Color(hex: "EC87C0")    // 핑크
        case "체육": return Color(hex: "37BC9B")    // 청록
            
        default:
            // ✨ 사용자가 추가한 과목(예: 심층면접)은 이름에 따라 고유한 파스텔톤 자동 생성
            return generatePastelColor(for: subjectName)
        }
    }
    
    // 해시 기반 자동 색상 생성기
    private static func generatePastelColor(for name: String) -> Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 100) / 100.0 // 0.0 ~ 1.0 사이 난수
        // 채도(Saturation)와 밝기(Brightness)를 조절해 예쁜 파스텔톤 유지
        return Color(hue: hue, saturation: 0.55, brightness: 0.9)
    }
}

// 👇 [핵심 해결] 이 부분이 없어서 오류가 났던 것입니다.
// Color(hex: "...")를 사용할 수 있게 만들어주는 코드입니다.
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
