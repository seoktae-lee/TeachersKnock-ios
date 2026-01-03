import ActivityKit
import WidgetKit
import SwiftUI

struct StudyTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerAttributes.self) { context in
            // MARK: - Lock Screen / Notification Center UI
            HStack(alignment: .center, spacing: 10) {
                // 왼쪽: 과목 및 목적 (텍스트 정보)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.35, green: 0.65, blue: 0.95))
                            .frame(width: 8, height: 8)
                        
                        Text(context.attributes.subject)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text(context.attributes.purpose)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 14) // 점(Circle) 너비 + 간격만큼 들여쓰기
                }
                
                Spacer()
                
                // 오른쪽: 타이머 (핵심 정보 대형 표시)
                Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .font(.system(size: 46, weight: .heavy)) // 시인성을 위해 폰트 사이즈 대폭 확대
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .activityBackgroundTint(Color(UIColor.systemBackground))
            .activitySystemActionForegroundColor(Color.black)
            .widgetURL(URL(string: "com.seoktaedev.TeachersKnock-ios://timer"))
            
        } dynamicIsland: { context in
            // MARK: - Dynamic Island UI (심플하게 유지)
            DynamicIsland {
                // Expanded Area
                DynamicIslandExpandedRegion(.leading) {
                    Link(destination: URL(string: "com.seoktaedev.TeachersKnock-ios://timer")!) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                            Text(context.attributes.subject)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        .padding(.leading, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "com.seoktaedev.TeachersKnock-ios://timer")!) {
                        Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .font(.title2) // Dynamic Island는 공간 제약으로 적절히 유지
                            .padding(.trailing, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: URL(string: "com.seoktaedev.TeachersKnock-ios://timer")!) {
                        Text(context.attributes.purpose)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                    }
                }
                
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .padding(.leading, 4)
                    .widgetURL(URL(string: "com.seoktaedev.TeachersKnock-ios://timer"))
            } compactTrailing: {
                Text(timerInterval: context.state.startTime...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .font(.caption)
                    .frame(width: 50)
                    .widgetURL(URL(string: "com.seoktaedev.TeachersKnock-ios://timer"))
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                    .widgetURL(URL(string: "com.seoktaedev.TeachersKnock-ios://timer"))
            }
        }
    }
}
