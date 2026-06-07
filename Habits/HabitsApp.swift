import SwiftUI
import HabitsKit

@main
struct HabitsApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(AppModelContainer.shared)
    }
}
