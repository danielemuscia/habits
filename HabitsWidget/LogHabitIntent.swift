import AppIntents
import SwiftData
import WidgetKit
import HabitsKit

/// Registra "oggi" un completamento dell'abitudine, direttamente dal widget
/// (interattivo, iOS 17+): +1 se è a contatore, altrimenti toggle.
struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra abitudine"

    @Parameter(title: "Habit")
    var habitId: String

    init() {}

    init(habitId: UUID) {
        self.habitId = habitId.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: habitId) {
            let context = ModelContext(AppModelContainer.shared)
            HabitStore.logToday(habitId: uuid, in: context)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
