import SwiftUI

/// Tab bar principale dell'app.
struct MainTabView: View {
    let userId: UUID
    @StateObject private var habitsVM = HabitsViewModel()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Oggi", systemImage: "checkmark.circle.fill") }

            HabitListView()
                .tabItem { Label("Abitudini", systemImage: "list.bullet") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
        }
        .tint(.accentColor)
        .environmentObject(habitsVM)
        .task {
            habitsVM.userId = userId
            await habitsVM.load()
        }
    }
}
