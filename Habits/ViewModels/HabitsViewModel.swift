import Foundation
import SwiftData
import WidgetKit
import HabitsKit

/// ViewModel principale: gestisce le abitudini e i log, su store locale SwiftData.
@MainActor
final class HabitsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var entries: [HabitEntry] = []
    @Published var selectedDate: Date = Date()
    /// Incrementato a ogni tap su "Oggi" per far scrollare la striscia delle date.
    @Published var scrollToTodayToken = 0
    /// Cambia a ogni modifica dei dati: usato altrove (es. Analytics) per ricalcolare.
    @Published var dataVersion = 0

    private var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2 // lunedì
        return c
    }()

    /// Contesto di lettura corrente. Viene **ricreato a ogni `reload()`** così da
    /// vedere anche le scritture fatte da altri processi (il widget condivide lo
    /// store via App Group). È trattenuto perché possiede gli oggetti pubblicati
    /// in `habits`/`entries`, che le viste mutano direttamente.
    private var context: ModelContext?

    var isToday: Bool { calendar.isDateInToday(selectedDate) }

    func goToToday() {
        selectedDate = Date()
        scrollToTodayToken += 1
    }

    // MARK: - Loading

    func reload() {
        let context = ModelContext(AppModelContainer.shared)
        self.context = context
        let habitsDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.archived == false },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        habits = (try? context.fetch(habitsDescriptor)) ?? []
        entries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        dataVersion &+= 1
    }

    // MARK: - Progress

    func progress(for habit: Habit) -> HabitProgress {
        HabitProgress.make(habit: habit, entries: entries, on: selectedDate, calendar: calendar)
    }

    var progresses: [HabitProgress] {
        habits.map { progress(for: $0) }
    }

    // MARK: - Logging (Today)

    /// Aumenta di 1 il conteggio del giorno selezionato.
    func increment(_ habit: Habit) {
        setCount(habit, to: progress(for: habit).todayCount + 1)
    }

    /// Diminuisce di 1 (non sotto zero).
    func decrement(_ habit: Habit) {
        let current = progress(for: habit).todayCount
        guard current > 0 else { return }
        setCount(habit, to: current - 1)
    }

    /// Toggle per abitudini "a spunta" (una volta al giorno).
    func toggle(_ habit: Habit) {
        let current = progress(for: habit).todayCount
        setCount(habit, to: current > 0 ? 0 : 1)
    }

    /// Marca/smarca il giorno selezionato come "riposo".
    func setRest(_ habit: Habit, _ rest: Bool) {
        upsertEntry(habit, count: 0, skipped: rest)
    }

    private func setCount(_ habit: Habit, to count: Int) {
        upsertEntry(habit, count: max(0, count), skipped: false)
    }

    /// Crea o aggiorna l'entry del giorno selezionato (unicità per `(habitId,
    /// entryDate)` garantita qui, non dal DB).
    private func upsertEntry(_ habit: Habit, count: Int, skipped: Bool) {
        guard let context else { return }
        let day = calendar.startOfDay(for: selectedDate)
        if let existing = entries.first(where: {
            $0.habitId == habit.id && calendar.isDate($0.entryDate, inSameDayAs: day)
        }) {
            existing.count = count
            existing.skipped = skipped
        } else {
            context.insert(HabitEntry(habitId: habit.id, entryDate: day, count: count, skipped: skipped))
        }
        save()
    }

    // MARK: - CRUD abitudini

    func createHabit(
        name: String, details: String?, icon: String, color: String,
        targetCount: Int, period: HabitPeriod, allowsMultiplePerDay: Bool
    ) {
        guard let context else { return }
        let habit = Habit(
            name: name,
            details: details?.isEmpty == true ? nil : details,
            icon: icon,
            color: color,
            targetCount: max(1, targetCount),
            period: period,
            allowsMultiplePerDay: allowsMultiplePerDay,
            sortOrder: habits.count
        )
        context.insert(habit)
        save()
    }

    func updateHabit(
        _ habit: Habit, name: String, details: String?, icon: String, color: String,
        targetCount: Int, period: HabitPeriod, allowsMultiplePerDay: Bool
    ) {
        habit.name = name
        habit.details = details?.isEmpty == true ? nil : details
        habit.icon = icon
        habit.color = color
        habit.targetCount = max(1, targetCount)
        habit.period = period
        habit.allowsMultiplePerDay = allowsMultiplePerDay
        save()
    }

    func deleteHabit(_ habit: Habit) {
        guard let context else { return }
        for entry in entries where entry.habitId == habit.id {
            context.delete(entry)
        }
        context.delete(habit)
        save()
    }

    private func save() {
        guard let context else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Errore di salvataggio SwiftData: \(error)")
        }
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
