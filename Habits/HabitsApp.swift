import SwiftUI

@main
struct HabitsApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(AppModelContainer.shared)
    }
}
