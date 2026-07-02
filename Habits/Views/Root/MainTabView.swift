import SwiftUI

/// Tab bar principale dell'app.
struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var habitsVM = HabitsViewModel()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Oggi", systemImage: "checkmark.circle.fill") }

            HabitListView()
                .tabItem { Label("Abitudini", systemImage: "list.bullet") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
        .environmentObject(habitsVM)
        .task {
            habitsVM.reload()
            // Riallinea il reminder pianificato allo stato salvato, anche se
            // l'utente non apre la tab Impostazioni in questa sessione.
            ReminderManager.shared.syncOnLaunch()
        }
        .onChange(of: scenePhase) { _, phase in
            // Al ritorno in foreground rilegge lo store: riflette anche i log
            // fatti dal widget mentre l'app era in background.
            if phase == .active { habitsVM.reload() }
        }
    }
}
