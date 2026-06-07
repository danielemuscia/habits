import Foundation
import SwiftData

/// Container SwiftData condiviso dell'app.
///
/// Prova ad attivare la sincronizzazione CloudKit (DB privato dell'utente,
/// container `iCloud.com.danielemuscia.habits`); se non è disponibile — ad es.
/// l'entitlement iCloud non è ancora provisioning-ato nel portale Apple — ripiega
/// su uno store **solo locale**, così l'app parte comunque. Senza iCloud loggato
/// i dati restano in locale e la sync riprende appena l'utente accede.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Habit.self, HabitEntry.self])

        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }

        // Fallback: store locale senza sync.
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }()
}
