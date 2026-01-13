import SwiftUI

struct AIAnalysisView: View {
    // ✨ 데이터 추가: 총 시간, MVP 과목
    let totalSeconds: Int
    let mvpSubject: (name: String, color: Color)?
    
    let records: [StudyRecord]
    let previousRecords: [StudyRecord] // 지난 기간 데이터 (비교용)
    let title: String // "주간 분석" or "월간 분석"
    
    // 단순 랜덤 멘트가 아니라, 데이터 기반 분석
    private var analysisMessage: String {
        // 1. 데이터가 아예 없을 때
        if records.isEmpty {
            return "아직 공부 기록이 없어요. 가볍게 시작해볼까요? 🌱"
        }
        
        let prevSeconds = previousRecords.reduce(0) { $0 + $1.durationSeconds }
        
        // 2. 학습량 비교 (지난 기간 대비)
        if prevSeconds > 0 {
            let diff = totalSeconds - prevSeconds
            if diff > 3600 { // 1시간 이상 증가
                return "지난 번보다 \(diff / 3600)시간 더 달렸어요! 엄청난 열정입니다 🔥"
            } else if diff < -3600 { // 1시간 이상 감소
                return "지난 번보다 조금 줄었네요. 다음엔 더 힘내봐요! 💪"
            }
        }
        
        // 3. 과목 편중 분석 (가장 많이 한 과목)
        var subjectTime: [String: Int] = [:]
        for record in records {
            subjectTime[record.areaName, default: 0] += record.durationSeconds
        }
        
        if let maxSubject = subjectTime.max(by: { $0.value < $1.value }) {
            let ratio = Double(maxSubject.value) / Double(totalSeconds)
            if ratio > 0.6 { // 60% 이상이 한 과목
                return "이번엔 '\(maxSubject.key)'에 푹 빠지셨군요! 밸런스도 챙겨보세요 ⚖️"
            } else if ratio < 0.3 && subjectTime.count >= 4 {
                return "여러 과목을 골고루 공부하셨네요! 황금 밸런스 훌륭해요 ✨"
            }
            
            // 4. 시간대 분석 (간단 버전: 밤/낮)
            // 기록의 시간대가 주로 언제인지 파악하려면 복잡하므로 간단히 가장 많이 한 과목 칭찬
            return "'\(maxSubject.key)' 실력이 쑥쑥 늘고 있어요! 꾸준함이 답이죠 📚"
        }
        
        return "꾸준함이 합격을 만듭니다. 오늘도 고생 많으셨어요! 🌟"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단: 요약 정보 (총 시간 & MVP)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 리포트 총 학습")
                        .font(.caption)
                        .foregroundColor(.gray) // ✨ White -> Gray
                    
                    Text(formatTimeShort(totalSeconds))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue) // ✨ White -> Blue
                }
                
                Spacer()
                
                // MVP 뱃지
                if let mvp = mvpSubject {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("🔥 MVP")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(mvp.color) // ✨ 투명도 제거, 본연의 색상 사용
                            .clipShape(Capsule())
                        
                        Text(mvp.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(mvp.color) // ✨ White -> Subject Color
                    }
                }
            }
            .padding(20)
            .background(Color.white) // ✨ 오버레이 제거, 전체 화이트 통일
            
            // ✨ 구분선 추가 (부드러운 경계)
            Divider()
                .padding(.horizontal, 20)
            
            // 하단: AI 코멘트
            HStack(alignment: .top, spacing: 14) {
                Text("🤖")
                    .font(.system(size: 24))
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 학습 코치")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(analysisMessage)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                
                Spacer() // ✨ [수정] 너비 맞춤을 위한 스페이서 추가
            }
            .padding(20)
            .background(Color.white)
        }
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    private func formatTimeShort(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
}
