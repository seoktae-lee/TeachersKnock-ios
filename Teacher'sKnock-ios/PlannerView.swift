import SwiftUI
import SwiftData
import FirebaseAuth

struct PlannerView: View {
    // 쿼리는 init에서 설정
    @Query private var allItems: [ScheduleItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // ✨ 생성자: 내 ID에 해당하는 일정만 가져오기
    init(userId: String) {
        _allItems = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId
        }, sort: \.startDate)
    }
    
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
                
                Text(item.startDate, style: .time).font(.caption2).foregroundColor(.blue)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
