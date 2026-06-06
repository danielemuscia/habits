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

/// Finestra temporale scelta dall'utente per gli Analytics.
/// Determina quanto indietro guardare: di conseguenza grafico, streak e completamento
/// si riferiscono tutti a questo intervallo.
enum AnalyticsRange: String, CaseIterable, Identifiable {
    case week, month, quarter, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:    return "Settimana"
        case .month:   return "Mese"
        case .quarter: return "Trimestre"
        case .year:    return "Anno"
        }
    }

    /// Inizio (incluso) della finestra rispetto a `end`.
    func start(from end: Date, calendar: Calendar) -> Date {
        switch self {
        case .week:    return calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .month:   return calendar.date(byAdding: .month, value: -1, to: end) ?? end
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: end) ?? end
        case .year:    return calendar.date(byAdding: .year, value: -1, to: end) ?? end
        }
    }
}

/// Calcola le statistiche per la sezione Analytics.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var stats: [HabitStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Finestra selezionata; al cambio le statistiche si ricalcolano sui dati già caricati.
    @Published var range: AnalyticsRange = .week {
        didSet { rebuild() }
    }

    private let service = HabitService()
    private var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    /// Dati grezzi dell'ultimo caricamento, per ricalcolare al cambio di finestra senza refetch.
    private var loadedHabits: [Habit] = []
    private var loadedEntries: [HabitEntry] = []

    func load(habits: [Habit]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let end = Date()
        guard let start = calendar.date(byAdding: .year, value: -1, to: end) else { return }

        do {
            loadedEntries = try await service.fetchEntries(from: start, to: end)
            loadedHabits = habits
            rebuild()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ricostruisce le statistiche dai dati caricati, per la finestra corrente.
    private func rebuild() {
        let end = Date()
        stats = loadedHabits.map { habit in
            computeStats(for: habit, entries: loadedEntries.filter { $0.habitId == habit.id }, end: end)
        }
    }

    private func computeStats(for habit: Habit, entries: [HabitEntry], end: Date) -> HabitStats {
        // Un "bucket" è un periodo dell'abitudine (giorno/settimana/...). Ne includiamo
        // quanti ne entrano nella finestra scelta dall'utente, dal più recente all'indietro.
        let windowStart = range.start(from: end, calendar: calendar)
        var buckets: [PeriodBucket] = []
        let safetyCap = 400

        for offset in 0..<safetyCap {
            guard let refDate = shift(end, by: -offset, period: habit.period) else { break }
            let interval = habit.period.dateInterval(containing: refDate, calendar: calendar)
            // Ci fermiamo quando il periodo è interamente prima della finestra
            // (manteniamo sempre almeno il periodo corrente, offset 0).
            if offset > 0 && interval.end <= windowStart { break }
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
        buckets.reverse() // dal più vecchio al più recente

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
