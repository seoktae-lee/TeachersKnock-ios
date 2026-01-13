import SwiftUI

struct RadarChartView: View {
    let records: [StudyRecord]
    
    @State private var selectedPhase = 0 // 0: 1차(주요), 1: 2차(면접 등)
    
    // 차트 데이터 구조
    struct RadarDataset: Identifiable {
        let id = UUID()
        let label: String
        let value: Double // 0.0 ~ 1.0 (상대적 비율)
        let color: Color
    }
    
    // 데이터 가공 (화면 갱신마다 재계산)
    private var chartData: [RadarDataset] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        
        let targetSubjects = (selectedPhase == 0) ? SubjectName.primarySubjects : SubjectName.secondarySubjects
        
        // 해당 단계(1차/2차)에 해당하는 과목만 필터링
        var filteredData: [(String, Int)] = []
        
        // 1. 타겟 과목들 데이터 수집
        for subject in targetSubjects {
            if let seconds = dict[subject], seconds > 0 {
                filteredData.append((subject, seconds))
            }
        }
        
        // 2. 데이터가 너무 많으면 Top 6로 자르기 (기타 없음 - 깔끔함을 위해)
        // 레이더 차트는 '기타' 항목이 있으면 모양이 이상해짐.
        let sortedData = filteredData.sorted { $0.1 > $1.1 }.prefix(6)
        
        guard let maxVal = sortedData.max(by: { $0.1 < $1.1 })?.1, maxVal > 0 else {
            return []
        }
        
        return sortedData.map { (subject, seconds) in
            RadarDataset(
                label: subject,
                value: Double(seconds) / Double(maxVal),
                color: SubjectName.color(for: subject)
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 탭 (1차 / 2차) - 우측 정렬된 컴팩트 스타일
            HStack {
                Spacer()
                Picker("단계", selection: $selectedPhase) {
                    Text("1차").tag(0)
                    Text("2차").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            if chartData.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("해당하는 공부 기록이 없어요")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 200)
            } else {
                ZStack {
                    // 배경 거미줄 (5단계)
                    RadarBackground(sides: max(3, chartData.count))
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    
                    // 데이터 폴리곤
                    RadarPolygon(data: chartData)
                        .fill(Color.blue.opacity(0.3))
                    
                    RadarPolygon(data: chartData)
                        .stroke(Color.blue, lineWidth: 2)
                    
                    // 레이블 표시
                    RadarLabels(data: chartData)
                }
                .frame(height: 240)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        // ✨ [수정] 흰색 배경 제거 (원형 그래프와 통일감)
        // .background(Color.white)
        // .cornerRadius(16)
        // .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Shapes

struct RadarBackground: Shape {
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // ✨ [수정] 라벨 영역 확보를 위해 반지름 축소 (-30)
        let radius = (min(rect.width, rect.height) / 2.0) - 30.0
        let angle = (2.0 * .pi) / Double(sides)
        
        // 5단계 동심원
        for i in 1...5 {
            let r = radius * (CGFloat(i) / 5.0)
            for j in 0..<sides {
                let currentAngle = angle * Double(j) - .pi / 2.0
                let point = CGPoint(
                    x: center.x + r * CGFloat(cos(currentAngle)),
                    y: center.y + r * CGFloat(sin(currentAngle))
                )
                if j == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
        
        // 중앙에서 뻗어나가는 선
        for j in 0..<sides {
            let currentAngle = angle * Double(j) - .pi / 2.0
            let endPoint = CGPoint(
                x: center.x + radius * CGFloat(cos(currentAngle)),
                y: center.y + radius * CGFloat(sin(currentAngle))
            )
            path.move(to: center)
            path.addLine(to: endPoint)
        }
        
        return path
    }
}

struct RadarPolygon: Shape {
    let data: [RadarChartView.RadarDataset]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // ✨ [수정] 라벨 영역 확보를 위해 반지름 축소 (-30)
        let radius = (min(rect.width, rect.height) / 2.0) - 30.0
        let angle = (2.0 * .pi) / Double(data.count)
        
        for (index, item) in data.enumerated() {
            let currentAngle = angle * Double(index) - .pi / 2.0
            let r = radius * CGFloat(item.value) // 값 비율 반영
            let point = CGPoint(
                x: center.x + r * CGFloat(cos(currentAngle)),
                y: center.y + r * CGFloat(sin(currentAngle))
            )
            
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarLabels: View {
    let data: [RadarChartView.RadarDataset]
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // ✨ [수정] 라벨 영역 확보를 위해 반지름 축소 (-30)
            let radius = (min(geo.size.width, geo.size.height) / 2.0) - 30.0
            let angle = (2.0 * .pi) / Double(data.count)
            
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                let currentAngle = angle * Double(index) - .pi / 2.0
                // 텍스트는 반지름보다 조금 더 바깥에
                let r = radius + 25.0
                let x = center.x + r * CGFloat(cos(currentAngle))
                let y = center.y + r * CGFloat(sin(currentAngle))
                
                VStack(spacing: 2) {
                    Text(item.label)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.primary)
                }
                .position(x: x, y: y)
            }
        }
    }
}
