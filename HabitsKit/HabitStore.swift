import Foundation
import SwiftData

/// Operazioni di lettura/scrittura sullo store, condivise tra app e widget.
/// Stateless: opera su un `ModelContext` passato dal chiamante.
public enum HabitStore {
    /// Calendario con settimana che inizia di lunedì (coerente con l'app).
    public static var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    /// Abitudini attive, ordinate.
    public static func activeHabits(in context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.archived == false },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public static func habit(id: UUID, in context: ModelContext) -> Habit? {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    public static func allEntries(in context: ModelContext) -> [HabitEntry] {
        (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
    }

    /// Registra un completamento "oggi" per l'abitudine: +1 se è a contatore,
    /// altrimenti toggle on/off. Salva e restituisce true se ha modificato.
    @discardableResult
    public static func logToday(habitId: UUID, in context: ModelContext) -> Bool {
        guard let habit = habit(id: habitId, in: context) else { return false }
        let day = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<HabitEntry>(predicate: #Predicate { $0.habitId == habitId })
        let entries = (try? context.fetch(descriptor)) ?? []
        let today = entries.first { calendar.isDate($0.entryDate, inSameDayAs: day) }

        if habit.usesDailyCounter {
            if let today {
                today.count += 1
                today.skipped = false
            } else {
                context.insert(HabitEntry(habitId: habitId, entryDate: day, count: 1))
            }
        } else {
            if let today, today.count > 0 {
                today.count = 0
            } else if let today {
                today.count = 1
                today.skipped = false
            } else {
                context.insert(HabitEntry(habitId: habitId, entryDate: day, count: 1))
            }
        }
        try? context.save()
        return true
    }
}
