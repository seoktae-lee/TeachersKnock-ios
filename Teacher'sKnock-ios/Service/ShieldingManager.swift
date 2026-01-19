import Foundation
import FamilyControls
import ManagedSettings
import SwiftUI
import Sentry

@MainActor
class ShieldingManager: ObservableObject {
    static let shared = ShieldingManager()
    
    // Store for ManagedSettings
    private let store = ManagedSettingsStore()
    
    // Selected apps/categories to shield (block)
    @Published var discouragedSelection = FamilyActivitySelection()
    
    // Authorization status
    @Published var isAuthorized: Bool = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        Task {
            let status = AuthorizationCenter.shared.authorizationStatus
            self.isAuthorized = status == .approved
        }
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.isAuthorized = true
        } catch {
            print("Failed to authorize FamilyControls: \(error)")
            SentrySDK.capture(error: error)
            self.isAuthorized = false
        }
    }
    
    /// Starts shielding the selected apps.
    func startShielding() {
        // Clear existing shields first to be safe
        store.clearAllSettings()
        
        let applications = discouragedSelection.applicationTokens
        let categories = discouragedSelection.categoryTokens
        // Web domains if needed, but sticking to apps for now
        
        if applications.isEmpty && categories.isEmpty {
            print("No apps selected to shield.")
            return
        }
        
        print("Starting shielding for \(applications.count) apps and \(categories.count) categories.")
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(categories, except: Set())
        store.shield.applications = applications
    }
    
    /// Stops shielding all apps.
    func stopShielding() {
        print("Stopping all shielding.")
        store.clearAllSettings()
    }
}
