import SwiftUI

struct SubjectName {
    static let primarySubjects: [String] = ["교직논술", "국어", "영어", "총론/창체", "사회", "도덕", "실과", "수학", "미술", "통합교과", "과학", "음악", "체육"]
    static let secondarySubjects: [String] = ["심층면접", "수업실연", "과정안작성", "영어면접", "영어수업실연"]
    // ✨ [추가] 생활 관련 과목 (타이머 미표시)
    static let lifeSubjects: [String] = ["식사", "운동", "휴식", "이동", "약속", "기타"]
    
    static var defaultList: [String] { primarySubjects + secondarySubjects }
    
    static func isStudySubject(_ name: String) -> Bool {
        return !lifeSubjects.contains(name)
    }

    static func color(for subjectName: String) -> Color {
        switch subjectName {
        case "교직논술": return Color(hex: "4A89DC")
        case "국어": return Color(hex: "ED5565")
        case "영어": return Color(hex: "FC6E51")
        case "총론/창체": return Color(hex: "FFCE54")
        case "사회": return Color(hex: "F6BB42")
        case "도덕": return Color(hex: "48CFAD")
        case "실과": return Color(hex: "A0D468")
        case "수학": return Color(hex: "8CC152")
        case "미술": return Color(hex: "AC92EC")
        case "통합교과": return Color(hex: "5D9CEC")
        case "과학": return Color(hex: "967ADC")
        case "음악": return Color(hex: "EC87C0")
        case "체육": return Color(hex: "37BC9B")
        case "심층면접", "수업실연", "과정안작성", "영어면접", "영어수업실연": return Color(hex: "5D6D7E")
        default: return generatePastelColor(for: subjectName)
        }
    }
    
    private static func generatePastelColor(for name: String) -> Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 100) / 100.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.9)
    }
}

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
