import Foundation

/// Statistiche aggregate per una singola abitudine.
struct HabitStats: Identifiable {
    let id: UUID
    let habit: Habit
    /// Periodi completati consecutivi fino a quello corrente (streak).
    let currentStreak: Int
    /// Streak massima storica.
    let bestStreak: Int
    /// Numero di periodi (recenti) in cui il target è stato raggiunto.
    let completedPeriods: Int
    /// Periodi totali considerati.
    let totalPeriods: Int
    /// Conteggio totale di completamenti registrati.
    let totalCount: Int
    /// Serie per il grafico: (etichetta periodo, conteggio, completato?).
    let series: [PeriodBucket]

    var completionRate: Double {
        guard totalPeriods > 0 else { return 0 }
        return Double(completedPeriods) / Double(totalPeriods)
    }
}

struct PeriodBucket: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let count: Int
    let isComplete: Bool
}

/// Calcola le statistiche per la sezione Analytics.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var stats: [HabitStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = HabitService()
    private var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    func load(habits: [Habit]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let end = Date()
        guard let start = calendar.date(byAdding: .year, value: -1, to: end) else { return }

        do {
            let allEntries = try await service.fetchEntries(from: start, to: end)
            stats = habits.map { habit in
                computeStats(for: habit, entries: allEntries.filter { $0.habitId == habit.id }, end: end)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computeStats(for habit: Habit, entries: [HabitEntry], end: Date) -> HabitStats {
        let bucketCount = bucketsToShow(for: habit.period)
        var buckets: [PeriodBucket] = []

        for offset in stride(from: bucketCount - 1, through: 0, by: -1) {
            guard let refDate = shift(end, by: -offset, period: habit.period) else { continue }
            let interval = habit.period.dateInterval(containing: refDate, calendar: calendar)
            let count = entries
                .filter { interval.contains($0.entryDate) }
                .reduce(0) { $0 + $1.count }
            buckets.append(PeriodBucket(
                date: interval.start,
                label: label(for: interval.start, period: habit.period),
                count: count,
                isComplete: count >= habit.targetCount
            ))
        }

        // Streak corrente: dai bucket più recenti all'indietro.
        var currentStreak = 0
        for bucket in buckets.reversed() {
            if bucket.isComplete { currentStreak += 1 } else { break }
        }

        // Streak migliore.
        var bestStreak = 0
        var running = 0
        for bucket in buckets {
            if bucket.isComplete {
                running += 1
                bestStreak = max(bestStreak, running)
            } else {
                running = 0
            }
        }

        let completed = buckets.filter(\.isComplete).count
        let total = entries.reduce(0) { $0 + $1.count }

        return HabitStats(
            id: habit.id,
            habit: habit,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            completedPeriods: completed,
            totalPeriods: buckets.count,
            totalCount: total,
            series: buckets
        )
    }

    private func bucketsToShow(for period: HabitPeriod) -> Int {
        switch period {
        case .daily:   return 30
        case .weekly:  return 12
        case .monthly: return 12
        case .yearly:  return 5
        }
    }

    private func shift(_ date: Date, by amount: Int, period: HabitPeriod) -> Date? {
        let component: Calendar.Component
        switch period {
        case .daily:   component = .day
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        case .yearly:  component = .year
        }
        return calendar.date(byAdding: component, value: amount, to: date)
    }

    private func label(for date: Date, period: HabitPeriod) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        switch period {
        case .daily:   f.dateFormat = "d/M"
        case .weekly:  f.dateFormat = "d/M"
        case .monthly: f.dateFormat = "MMM"
        case .yearly:  f.dateFormat = "yyyy"
        }
        return f.string(from: date)
    }
}
