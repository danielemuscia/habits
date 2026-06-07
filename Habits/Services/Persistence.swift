import Foundation
import SwiftData

/// Container SwiftData condiviso dell'app.
///
/// La sincronizzazione CloudKit si attiva automaticamente quando l'app è
/// firmata con l'entitlement iCloud/CloudKit (vedi `Habits.entitlements` e il
/// container `iCloud.com.danielemuscia.habits`). Senza iCloud loggato sul
/// dispositivo, i dati restano comunque in locale: la sync riprende appena
/// l'utente accede a iCloud.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Habit.self, HabitEntry.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }()
}
