import Foundation

/// Finestra temporale scelta dall'utente per gli Analytics.
/// Determina quanto indietro guardare e la granularità delle celle della heatmap.
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

    var subtitle: String {
        switch self {
        case .week:    return "Ultima settimana · per giorno"
        case .month:   return "Ultimo mese · per giorno"
        case .quarter: return "Ultimo trimestre · per settimana"
        case .year:    return "Ultimo anno · per mese"
        }
    }

    /// Granularità di una cella della heatmap.
    var cellComponent: Calendar.Component {
        switch self {
        case .week:    return .day
        case .month:   return .day
        case .quarter: return .weekOfYear
        case .year:    return .month
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

/// Una cella della heatmap: una porzione di tempo (giorno/settimana/mese) colorata
/// in base a quanto l'obiettivo è stato riempito in quella porzione.
struct HeatCell: Identifiable {
    let id = UUID()
    let date: Date
    /// Etichetta breve (es. iniziale del giorno o del mese), usata in alcune finestre.
    let label: String
    let count: Int
    /// Quanto è "pieno" [0, 1+]: count / obiettivo della cella.
    let fraction: Double
    let isComplete: Bool
}

/// Statistiche aggregate per una singola abitudine, riferite alla finestra scelta.
struct HabitStats: Identifiable {
    let id: UUID
    let habit: Habit
    /// Periodi (celle) completati consecutivi fino all'ultimo (streak).
    let currentStreak: Int
    /// Streak massima nella finestra.
    let bestStreak: Int
    /// Completamento medio della finestra [0, 1].
    let completion: Double
    /// Celle della heatmap, dalla più vecchia alla più recente.
    let cells: [HeatCell]
    /// Numero di colonne in cui disporre le celle.
    let columns: Int
    /// Celle vuote iniziali per allineare la griglia mensile ai giorni della settimana.
    let leadingBlanks: Int
    /// Intestazione di colonna (giorni della settimana) per la vista mensile.
    let header: [String]?
    /// Mostra l'etichetta sopra ogni cella (settimana/anno).
    let showCellLabels: Bool
    /// Descrizione della finestra mostrata.
    let subtitle: String
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
        let component = range.cellComponent
        let windowStart = range.start(from: end, calendar: calendar)
        let cellTarget = self.cellTarget(for: habit, component: component)

        var cells: [HeatCell] = []
        for offset in 0..<500 {
            guard let ref = calendar.date(byAdding: component, value: -offset, to: end) else { break }
            let interval = calendar.dateInterval(of: component, for: ref)
                ?? DateInterval(start: calendar.startOfDay(for: ref), duration: 86_400)
            // Manteniamo sempre la cella corrente (offset 0); fermiamo quando è fuori finestra.
            if offset > 0 && interval.end <= windowStart { break }
            let count = entries
                .filter { interval.contains($0.entryDate) }
                .reduce(0) { $0 + $1.count }
            cells.append(HeatCell(
                date: interval.start,
                label: cellLabel(for: interval.start, component: component),
                count: count,
                fraction: cellTarget > 0 ? Double(count) / Double(cellTarget) : 0,
                isComplete: count >= cellTarget
            ))
        }
        cells.reverse() // dal più vecchio al più recente

        // Streak corrente: dalle celle più recenti all'indietro.
        var currentStreak = 0
        for cell in cells.reversed() {
            if cell.isComplete { currentStreak += 1 } else { break }
        }
        // Streak migliore.
        var bestStreak = 0, running = 0
        for cell in cells {
            if cell.isComplete { running += 1; bestStreak = max(bestStreak, running) }
            else { running = 0 }
        }

        // Completamento medio della finestra: somma riempita / somma attesa, con cap per cella.
        let filled = cells.reduce(0) { $0 + min($1.count, cellTarget) }
        let expected = cellTarget * cells.count
        let completion = expected > 0 ? Double(filled) / Double(expected) : 0

        // Layout della griglia.
        let columns = (range == .month) ? 7 : cells.count
        var leadingBlanks = 0
        if range == .month, let first = cells.first {
            let wd = calendar.component(.weekday, from: first.date)
            leadingBlanks = (wd - calendar.firstWeekday + 7) % 7
        }
        let header: [String]? = (range == .month) ? ["L", "M", "M", "G", "V", "S", "D"] : nil

        return HabitStats(
            id: habit.id,
            habit: habit,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            completion: completion,
            cells: cells,
            columns: max(1, columns),
            leadingBlanks: leadingBlanks,
            header: header,
            showCellLabels: range == .week || range == .year,
            subtitle: range.subtitle
        )
    }

    /// Obiettivo atteso in una singola cella, scalando il target dell'abitudine
    /// dalla durata del suo periodo alla durata della cella.
    private func cellTarget(for habit: Habit, component: Calendar.Component) -> Int {
        let periodDays = days(forPeriod: habit.period)
        let cellDays = days(forComponent: component)
        let scaled = Double(habit.targetCount) * cellDays / periodDays
        return max(1, Int(scaled.rounded()))
    }

    private func days(forPeriod period: HabitPeriod) -> Double {
        switch period {
        case .daily:   return 1
        case .weekly:  return 7
        case .monthly: return 30
        case .yearly:  return 365
        }
    }

    private func days(forComponent component: Calendar.Component) -> Double {
        switch component {
        case .day:        return 1
        case .weekOfYear: return 7
        case .month:      return 30
        default:          return 1
        }
    }

    private func cellLabel(for date: Date, component: Calendar.Component) -> String {
        switch component {
        case .day:   return Self.weekdayFormatter.string(from: date).uppercased()
        case .month: return Self.monthFormatter.string(from: date).uppercased()
        default:     return ""
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEEE"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "MMMMM"
        return f
    }()
}
