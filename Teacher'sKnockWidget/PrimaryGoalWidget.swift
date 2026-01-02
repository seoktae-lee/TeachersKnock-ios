import WidgetKit
import SwiftUI

struct PrimaryGoalWidget: Widget {
    let kind: String = "PrimaryGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrimaryGoalWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                PrimaryGoalWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PrimaryGoalWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("대표 목표 위젯")
        .description("나의 대표 목표 D-Day와 캐릭터를 홈 화면에서 만나보세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
        // ✨ 중요: 컨텐츠 마진 제거 (꽉 찬 디자인을 위해)
        .contentMarginsDisabled() 
    }
}
