import SwiftUI
import SwiftData

struct PlannerView: View {
    @Query(sort: \ScheduleItem.startDate) private var allItems: [ScheduleItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    var filteredItems: [ScheduleItem] {
        let calendar = Calendar.current
        return allItems.filter { item in
            calendar.isDate(item.startDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 1. 달력
                DatePicker("날짜 선택", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accentColor(brandColor)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding()
                
                Divider()
                
                // 2. 할 일 목록
                List {
                    if filteredItems.isEmpty {
                        ContentUnavailableView {
                            Label("일정 없음", systemImage: "calendar.badge.exclamationmark")
                        } description: {
                            Text("이 날짜에 등록된 일정이 없습니다.")
                        }
                    } else {
                        ForEach(filteredItems) { item in
                            ScheduleRow(item: item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("스터디 플래너")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(brandColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddScheduleView()
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
    }
}

// 리스트 디자인
struct ScheduleRow: View {
    @Bindable var item: ScheduleItem
    
    var body: some View {
        HStack {
            Button(action: { item.isCompleted.toggle() }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .gray : .primary)
                
                if !item.details.isEmpty {
                    Text(item.details).font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
