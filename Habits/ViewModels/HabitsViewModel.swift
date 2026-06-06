import Foundation

/// ViewModel principale: gestisce le abitudini e i log della vista Today.
@MainActor
final class HabitsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var entries: [HabitEntry] = []
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = HabitService()
    private var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2 // lunedì
        return c
    }()

    var userId: UUID?

    var isToday: Bool { calendar.isDateInToday(selectedDate) }

    func goToToday() { selectedDate = Date() }

    // MARK: - Loading

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let habitsResult = service.fetchHabits()
            let (start, end) = entriesWindow()
            async let entriesResult = service.fetchEntries(from: start, to: end)
            habits = try await habitsResult
            entries = try await entriesResult
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Finestra di log da caricare: dall'inizio dell'anno corrente a fine giornata selezionata.
    /// Copre la finestra del periodo corrente per ogni periodicità.
    private func entriesWindow() -> (Date, Date) {
        let yearStart = calendar.dateInterval(of: .year, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        let end = calendar.startOfDay(for: selectedDate)
        return (yearStart, end)
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
    func increment(_ habit: Habit) async {
        let current = progress(for: habit).todayCount
        await setCount(habit, to: current + 1)
    }

    /// Diminuisce di 1 (non sotto zero).
    func decrement(_ habit: Habit) async {
        let current = progress(for: habit).todayCount
        guard current > 0 else { return }
        await setCount(habit, to: current - 1)
    }

    /// Toggle per abitudini con target giornaliero = 1.
    func toggle(_ habit: Habit) async {
        let current = progress(for: habit).todayCount
        await setCount(habit, to: current > 0 ? 0 : 1)
    }

    private func setCount(_ habit: Habit, to count: Int) async {
        guard let userId else { return }
        do {
            let updated = try await service.setEntryCount(
                habitId: habit.id, userId: userId, date: selectedDate, count: count
            )
            mergeEntry(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergeEntry(_ entry: HabitEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else if let idx = entries.firstIndex(where: {
            $0.habitId == entry.habitId && calendar.isDate($0.entryDate, inSameDayAs: entry.entryDate)
        }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    // MARK: - CRUD abitudini

    func createHabit(
        name: String, description: String?, icon: String, color: String,
        targetCount: Int, period: HabitPeriod
    ) async {
        guard let userId else { return }
        let payload = NewHabit(
            userId: userId,
            name: name,
            description: description?.isEmpty == true ? nil : description,
            icon: icon,
            color: color,
            targetCount: max(1, targetCount),
            period: period,
            sortOrder: habits.count
        )
        do {
            let created = try await service.createHabit(payload)
            habits.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateHabit(_ habit: Habit, with update: HabitUpdate) async {
        do {
            let updated = try await service.updateHabit(id: habit.id, with: update)
            if let idx = habits.firstIndex(where: { $0.id == updated.id }) {
                if updated.archived {
                    habits.remove(at: idx)
                } else {
                    habits[idx] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteHabit(_ habit: Habit) async {
        do {
            try await service.deleteHabit(id: habit.id)
            habits.removeAll { $0.id == habit.id }
            entries.removeAll { $0.habitId == habit.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        habits = []
        entries = []
        userId = nil
    }
}
