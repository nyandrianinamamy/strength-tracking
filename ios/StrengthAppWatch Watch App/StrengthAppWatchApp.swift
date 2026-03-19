import SwiftUI

@main
struct StrengthAppWatchApp: App {
    @StateObject private var sessionManager = WorkoutSessionManager.shared

    init() {
        WorkoutSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
