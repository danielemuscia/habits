import SwiftUI
import UIKit

/// Impostazioni dell'app: reminder giornaliero per inserire le abitudini del giorno.
struct SettingsView: View {
    @StateObject private var reminder = ReminderManager.shared
    @State private var showingDeniedAlert = false
    @State private var systemDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Ricordami ogni giorno", isOn: reminderBinding)
                    if reminder.isEnabled {
                        DatePicker("Orario", selection: $reminder.time, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle("Impostazioni")
        }
        .task {
            reminder.syncOnLaunch()
            systemDenied = await reminder.currentAuthorizationStatus() == .denied
        }
        .alert("Notifiche disattivate", isPresented: $showingDeniedAlert) {
            Button("Apri Impostazioni") { openSystemSettings() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Per ricevere il promemoria, abilita le notifiche per Habits nelle Impostazioni di sistema.")
        }
    }

    private var footerText: String {
        systemDenied
            ? "Le notifiche sono disattivate per Habits nelle Impostazioni di sistema."
            : "Ricevi una notifica ogni giorno all'orario scelto, per ricordarti di registrare le tue abitudini."
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminder.isEnabled },
            set: { newValue in
                Task {
                    let granted = await reminder.setEnabled(newValue)
                    systemDenied = await reminder.currentAuthorizationStatus() == .denied
                    if newValue && !granted {
                        showingDeniedAlert = true
                    }
                }
            }
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
