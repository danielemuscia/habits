import SwiftUI
import SwiftData

/// Tab bar principale dell'app.
struct MainTabView: View {
    @Environment(\.modelContext) private var context
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
        .task { habitsVM.configure(context) }
    }
}
