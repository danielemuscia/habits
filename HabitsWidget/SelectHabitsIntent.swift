import AppIntents
import SwiftData
import HabitsKit

/// Configurazione del widget: l'utente sceglie quali abitudini mostrare.
/// Se nessuna è selezionata, il widget mostra tutte le abitudini attive.
struct SelectHabitsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Abitudini"
    static var description = IntentDescription("Scegli quali abitudini mostrare nel widget.")

    @Parameter(title: "Abitudini")
    var habits: [HabitChoice]?
}

/// Abitudine selezionabile nella UI di configurazione del widget.
struct HabitChoice: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Abitudine"
    static var defaultQuery = HabitChoiceQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// Sorgente delle abitudini per la configurazione, letta dallo store condiviso.
struct HabitChoiceQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [HabitChoice.ID]) async throws -> [HabitChoice] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitChoice] {
        all()
    }

    @MainActor
    private func all() -> [HabitChoice] {
        let context = ModelContext(AppModelContainer.shared)
        return HabitStore.activeHabits(in: context).map { HabitChoice(id: $0.id, name: $0.name) }
    }
}
