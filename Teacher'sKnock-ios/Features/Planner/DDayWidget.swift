import SwiftUI

struct DDayWidget: View {
    @AppStorage("dDayTargetDate") private var targetDateInterval: Double = Date().timeIntervalSince1970
    @State private var showingDatePicker = false
    @State private var tempDate = Date()
    
    var targetDate: Date {
        Date(timeIntervalSince1970: targetDateInterval)
    }
    
    var dDayString: String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        
        if let days = components.day {
            if days > 0 { return "D-\(days)" }
            else if days == 0 { return "D-Day" }
            else { return "D+\(-days)" }
        }
        return "D-?"
    }
    
    var body: some View {
        Button(action: {
            tempDate = targetDate
            showingDatePicker = true
        }) {
            VStack(spacing: 2) {
                Text(dDayString)
                    .font(.title3)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                Text("시험일")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(12)
            .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .sheet(isPresented: $showingDatePicker) {
            VStack(spacing: 20) {
                Text("시험 목표일 설정")
                    .font(.headline)
                    .padding(.top)
                
                DatePicker("날짜", selection: $tempDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                Button("저장") {
                    targetDateInterval = tempDate.timeIntervalSince1970
                    showingDatePicker = false
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .presentationDetents([.medium])
        }
    }
}
