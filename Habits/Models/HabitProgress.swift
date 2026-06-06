import Foundation

/// Avanzamento di un'abitudine nel periodo corrente.
struct HabitProgress {
    let habit: Habit
    /// Conteggio totale nel periodo corrente (es. quante volte questa settimana).
    let currentCount: Int
    /// Conteggio registrato oggi (per il pulsante della vista Today).
    let todayCount: Int
    /// Il giorno selezionato è marcato come "riposo".
    var isRest: Bool = false

    var target: Int { habit.targetCount }

    /// Frazione di completamento [0, 1].
    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(currentCount) / Double(target))
    }

    var isComplete: Bool { currentCount >= target }

    /// Calcola l'avanzamento dato l'elenco completo dei log dell'abitudine.
    static func make(habit: Habit, entries: [HabitEntry], on day: Date, calendar: Calendar) -> HabitProgress {
        let interval = habit.period.dateInterval(containing: day, calendar: calendar)
        let startOfDay = calendar.startOfDay(for: day)

        var periodCount = 0
        var todayCount = 0
        var isRest = false
        for entry in entries where entry.habitId == habit.id {
            // Intervallo semi-aperto [inizio, fine): la mezzanotte finale appartiene
            // al periodo successivo, non a questo (evita di sommare il giorno dopo).
            if entry.entryDate >= interval.start && entry.entryDate < interval.end {
                periodCount += entry.count
            }
            if calendar.isDate(entry.entryDate, inSameDayAs: startOfDay) {
                todayCount += entry.count
                if entry.skipped { isRest = true }
            }
        }
        return HabitProgress(habit: habit, currentCount: periodCount, todayCount: todayCount, isRest: isRest)
    }
}
