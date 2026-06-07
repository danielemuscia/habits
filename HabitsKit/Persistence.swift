import Foundation
import SwiftData

/// Container SwiftData condiviso tra app ed estensione widget.
///
/// Lo store vive nel container dell'**App Group** `group.com.danielemuscia.habits`
/// così entrambi i processi leggono/scrivono gli stessi dati. La sync CloudkKit
/// (DB privato iCloud) si attiva se l'entitlement è provisioning-ato; in caso
/// contrario si ripiega su store locale, così tutto parte comunque.
public enum AppModelContainer {
    public static let appGroupID = "group.com.danielemuscia.habits"

    public static let shared: ModelContainer = {
        let schema = Schema([Habit.self, HabitEntry.self])

        func configuration(group: Bool, cloud: ModelConfiguration.CloudKitDatabase) -> ModelConfiguration {
            ModelConfiguration(
                schema: schema,
                groupContainer: group ? .identifier(appGroupID) : .none,
                cloudKitDatabase: cloud
            )
        }

        // Preferenza: App Group + CloudKit. Poi degradiamo per non bloccare l'avvio.
        let attempts: [ModelConfiguration] = [
            configuration(group: true, cloud: .automatic),
            configuration(group: true, cloud: .none),
            configuration(group: false, cloud: .none)
        ]
        for config in attempts {
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
        }
        fatalError("Impossibile creare il ModelContainer SwiftData.")
    }()
}
