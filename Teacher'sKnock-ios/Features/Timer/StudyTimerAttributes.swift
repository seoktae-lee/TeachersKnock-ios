import ActivityKit
import Foundation

struct StudyTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 타이머가 시작된 절대 시간 (이 시간을 기준으로 타이머가 돌아감)
        var startTime: Date
    }

    // 변하지 않는 속성
    var subject: String
    var purpose: String
}
