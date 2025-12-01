import SwiftUI
import SwiftData
import Firebase
import FirebaseAuth

@main
struct Teacher_sKnock_iosApp: App {
    
    @StateObject var authManager = AuthManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    // SwiftData 설정 (모델 3개 등록 확인)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            ScheduleItem.self,
            StudyRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
