import SwiftUI
import WidgetKit

struct PrimaryGoalWidgetEntryView: View {
    var entry: PrimaryGoalEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let data = entry.data {
            realContent(data: data)
        } else {
            emptyView
        }
    }
    
    @ViewBuilder
    func realContent(data: WidgetData) -> some View {
        let themeColor = GoalColorHelper.color(for: data.characterColor)
        let characterLevel = CharacterLevel(rawValue: data.level - 1) ?? .lv1
        let emoji = characterLevel.emoji(for: data.characterType)
        let imageName = characterLevel.imageName(for: data.characterType)
        
        if family == .accessoryRectangular {
            HStack(spacing: 0) {
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .padding(2)
                } else {
                    Text(emoji)
                        .font(.system(size: 20))
                        .padding(6)
                        .background(Circle().stroke(lineWidth: 1))
                }
                Spacer()
                Text(dDayString(data.dDay))
                    .font(.system(size: 32, weight: .black, design: .rounded))
            }
        } else if family == .accessoryCircular {
            // Lock Screen Widget (Circular)
            ZStack {
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Text(emoji)
                        .font(.system(size: 30))
                        .padding(4)
                        .background(Circle().stroke(lineWidth: 1))
                }
            }
        } else {
            GeometryReader { proxy in
                ZStack {
                    // 배경: 은은한 그라데이션
                    LinearGradient(
                        gradient: Gradient(colors: [themeColor.opacity(0.1), .white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    if family == .systemSmall {
                        VStack(spacing: 8) {
                            // D-Day
                            Text(dDayString(data.dDay))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(data.dDay <= 7 ? .red : .primary)
                                .minimumScaleFactor(0.8)
                            
                            // 캐릭터
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                if let imageName = imageName {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(8)
                                        .frame(width: 50, height: 50)
                                } else {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                }
                            }
                            
                            // 목표 제목 (짧게)
                            Text(data.goalTitle)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if family == .systemMedium {
                        // Medium Size
                        HStack(spacing: 20) {
                            // 좌측: 캐릭터 영역
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle()
                                        .fill(themeColor.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                    if let imageName = imageName {
                                        Image(imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(10)
                                            .frame(width: 60, height: 60)
                                    } else {
                                        Text(emoji)
                                            .font(.system(size: 34))
                                    }
                                }
                                Text("LV.\(data.level)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(themeColor.opacity(0.3))
                                    .cornerRadius(8)
                                    .foregroundColor(themeColor)
                            }
                            
                            Divider()
                                .frame(height: 60)
                            
                            // 우측: 정보 영역
                            VStack(alignment: .leading, spacing: 4) {
                                Text("나의 목표")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(data.goalTitle)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Spacer().frame(height: 4)
                                
                                Text(dDayString(data.dDay))
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(data.dDay <= 7 ? .red : themeColor)
                            }
                            Spacer()
                        }
                        .padding(20)
                    }
                }
            }
        }
    }
    
    var emptyView: some View {
        ZStack {
            Color(.systemGroupedBackground)
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.dashed")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("목표를\n설정해주세요")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
        }
    }
        
    func dDayString(_ dDay: Int) -> String {
        if dDay == 0 { return "D-Day" }
        return dDay > 0 ? "D-\(dDay)" : "완료"
    }
}
