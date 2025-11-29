//
//  Teacher_sKnock_iosApp.swift
//  Teacher'sKnock-ios
//
//  Created by 이석태 on 11/29/25.
//

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
    
    // ✨ 여기가 수정된 부분입니다! ✨
    var sharedModelContainer: ModelContainer = {
        // Goal, ScheduleItem에 이어 StudyRecord를 추가합니다.
        let schema = Schema([
            Goal.self,
            ScheduleItem.self,
            StudyRecord.self // 👈 이 줄이 추가되어야 합니다!
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
