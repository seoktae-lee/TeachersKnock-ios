import SwiftUI

struct GoalColorHelper {
    static func color(for name: String) -> Color {
        switch name {
        case "Blue": return Color(red: 0.35, green: 0.65, blue: 0.95)
        case "Pink": return Color.pink
        case "Purple": return Color.purple
        case "Green": return Color.green
        case "Orange": return Color.orange
        case "Mint": return Color.mint
        default: return Color.blue
        }
    }
}
