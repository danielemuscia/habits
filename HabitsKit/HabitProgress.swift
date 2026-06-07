import Foundation

/// Avanzamento di un'abitudine nel periodo corrente.
public struct HabitProgress {
    public let habit: Habit
    /// Conteggio totale nel periodo corrente (es. quante volte questa settimana).
    public let currentCount: Int
    /// Conteggio registrato oggi (per il pulsante della vista Today / widget).
    public let todayCount: Int
    /// Il giorno selezionato è marcato come "riposo".
    public var isRest: Bool

    public init(habit: Habit, currentCount: Int, todayCount: Int, isRest: Bool = false) {
        self.habit = habit
        self.currentCount = currentCount
        self.todayCount = todayCount
        self.isRest = isRest
    }

    public var target: Int { habit.targetCount }

    /// Rapporto completamento **non cappato** (può superare 1: overperformance).
    /// Usato dall'anello per mostrare un secondo giro oltre l'obiettivo.
    public var ratio: Double {
        guard target > 0 else { return 0 }
        return Double(currentCount) / Double(target)
    }

    /// Frazione di completamento [0, 1].
    public var fraction: Double {
        min(1, ratio)
    }

    public var isComplete: Bool { currentCount >= target }

    /// Calcola l'avanzamento dato l'elenco completo dei log dell'abitudine.
    public static func make(habit: Habit, entries: [HabitEntry], on day: Date, calendar: Calendar) -> HabitProgress {
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
