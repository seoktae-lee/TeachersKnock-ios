import SwiftUI

struct ParticipationView: View {
    let members: [User]
    
    // 출석 기준: 2시간 (7200초)
    private let attendanceThreshold = 7200
    
    var attendanceCount: Int {
        members.filter { $0.todayStudyTime >= attendanceThreshold }.count
    }
    
    var totalCount: Int {
        members.count
    }
    
    var attendanceRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(attendanceCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 출석 현황")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("오늘 \(totalCount)명 중 \(attendanceCount)명 출석 완료! 🔥")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 간단한 원형 차트나 퍼센트 표시
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: attendanceRate)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: attendanceRate)
                    
                    Text("\(Int(attendanceRate * 100))%")
                        .font(.caption.bold())
                }
                .frame(width: 40, height: 40)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct ParticipationView_Previews: PreviewProvider {
    static var previews: some View {
        ParticipationView(members: [
            User(id: "1", nickname: "User1", tkID: nil, university: nil, todayStudyTime: 8000), // 출석
            User(id: "2", nickname: "User2", tkID: nil, university: nil, todayStudyTime: 3000), // 미출석
            User(id: "3", nickname: "User3", tkID: nil, university: nil, todayStudyTime: 0)     // 미출석
        ])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
