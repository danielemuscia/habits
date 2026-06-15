import Foundation
import HabitsKit

/// Finestra temporale scelta dall'utente per gli Analytics.
/// Ogni case corrisponde a un periodo di calendario fisso (non scorrevole):
/// .week = lunedì–domenica correnti, .month = 1°–ultimo del mese, ecc.
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

    /// Componente calendario usato per spostarsi al periodo precedente/successivo.
    var navigationComponent: Calendar.Component {
        switch self {
        case .week:    return .weekOfYear
        case .month:   return .month
        case .quarter: return .month   // si sposta di 3 mesi (vedi goToPreviousPeriod)
        case .year:    return .year
        }
    }

    /// Numero di unità del navigationComponent da aggiungere per avanzare di 1 periodo.
    var navigationStep: Int {
        switch self {
        case .quarter: return 3
        default:       return 1
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

    /// Inizio (incluso) del periodo fisso che contiene `reference`.
    func start(from reference: Date, calendar: Calendar) -> Date {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: reference)?.start ?? reference
        case .month:
            return calendar.dateInterval(of: .month, for: reference)?.start ?? reference
        case .quarter:
            let month = calendar.component(.month, from: reference)
            let qStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: reference)
            comps.month = qStartMonth
            comps.day = 1
            return calendar.date(from: comps) ?? reference
        case .year:
            return calendar.dateInterval(of: .year, for: reference)?.start ?? reference
        }
    }

    /// Fine (esclusa) del periodo fisso che contiene `reference`.
    func end(from reference: Date, calendar: Calendar) -> Date {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: reference)?.end ?? reference
        case .month:
            return calendar.dateInterval(of: .month, for: reference)?.end ?? reference
        case .quarter:
            let periodStart = start(from: reference, calendar: calendar)
            return calendar.date(byAdding: .month, value: 3, to: periodStart) ?? reference
        case .year:
            return calendar.dateInterval(of: .year, for: reference)?.end ?? reference
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
    /// Periodo di riposo: stato neutro (non rompe la streak, escluso dal completamento).
    let isRest: Bool
    /// True se la cella contiene il giorno corrente (oggi).
    let isToday: Bool
}

/// Statistiche aggregate per una singola abitudine, riferite alla finestra scelta.
struct HabitStats: Identifiable {
    let id: UUID
    let habit: Habit
    /// Serie consecutiva all-time (non limitata alla finestra).
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
    /// Almeno una cella è un giorno di riposo (per mostrare la legenda).
    let hasRest: Bool
    /// Descrizione del periodo mostrato (es. "9 – 15 giu 2026").
    let subtitle: String
}

/// Calcola le statistiche per la sezione Analytics.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var stats: [HabitStats] = []
    /// Finestra selezionata; al cambio le statistiche si ricalcolano sui dati già caricati.
    @Published var range: AnalyticsRange = .week {
        didSet { rebuild() }
    }
    /// Data di riferimento per il periodo visualizzato (di default oggi).
    @Published private(set) var referenceDate: Date = Date()

    private var calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    /// Dati grezzi dell'ultimo caricamento, per ricalcolare al cambio di finestra.
    private var loadedHabits: [Habit] = []
    private var loadedEntries: [HabitEntry] = []

    // MARK: - Navigation

    /// True se il periodo visualizzato è già quello corrente (non si può avanzare).
    var canGoNext: Bool {
        let periodStart = range.start(from: Date(), calendar: calendar)
        let refStart = range.start(from: referenceDate, calendar: calendar)
        return refStart < periodStart
    }

    /// Etichetta leggibile del periodo corrente (es. "9 – 15 giu 2026", "Giugno 2026").
    var periodLabel: String {
        switch range {
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
                return range.label
            }
            let start = interval.start
            // fine = mezzanotte del lunedì successivo → sottraiamo 1 secondo per avere domenica
            let end = interval.end.addingTimeInterval(-1)
            return formatWeekRange(from: start, to: end)
        case .month:
            return Self.monthYearFormatter.string(from: referenceDate)
        case .quarter:
            let month = calendar.component(.month, from: referenceDate)
            let q = (month - 1) / 3 + 1
            let year = calendar.component(.year, from: referenceDate)
            return "Q\(q) \(year)"
        case .year:
            return Self.yearFormatter.string(from: referenceDate)
        }
    }

    func goToPreviousPeriod() {
        referenceDate = calendar.date(
            byAdding: range.navigationComponent,
            value: -range.navigationStep,
            to: referenceDate
        ) ?? referenceDate
        rebuild()
    }

    func goToNextPeriod() {
        guard canGoNext else { return }
        let candidate = calendar.date(
            byAdding: range.navigationComponent,
            value: range.navigationStep,
            to: referenceDate
        ) ?? referenceDate
        // non permettiamo di andare oltre il periodo corrente
        referenceDate = range.start(from: candidate, calendar: calendar) <= range.start(from: Date(), calendar: calendar)
            ? candidate
            : Date()
        rebuild()
    }

    // MARK: - Data Loading

    /// Ricalcola le statistiche dai dati locali già caricati dallo store.
    func load(habits: [Habit], entries: [HabitEntry]) {
        loadedHabits = habits
        loadedEntries = entries
        rebuild()
    }

    /// Ricostruisce le statistiche dai dati caricati, per la finestra e il periodo correnti.
    private func rebuild() {
        let ref = referenceDate
        stats = loadedHabits.map { habit in
            computeStats(
                for: habit,
                entries: loadedEntries.filter { $0.habitId == habit.id },
                reference: ref
            )
        }
    }

    private func computeStats(for habit: Habit, entries: [HabitEntry], reference: Date) -> HabitStats {
        let component = range.cellComponent
        let windowStart = range.start(from: reference, calendar: calendar)
        let periodEnd = range.end(from: reference, calendar: calendar)
        // Il loop parte dall'ultimo istante del periodo (non da "oggi") così mostriamo
        // sempre tutte le celle del periodo, incluse quelle future (count = 0).
        let loopAnchor = periodEnd.addingTimeInterval(-1)
        let cellTarget = self.cellTarget(for: habit, component: component)
        let today = calendar.startOfDay(for: Date())
        let now = Date()

        // Giorni marcati come riposo (inizio giornata), per scontare le aspettative.
        let restDays = Set(entries.filter(\.skipped).map { calendar.startOfDay(for: $0.entryDate) })

        var cells: [HeatCell] = []
        for offset in 0..<500 {
            guard let ref = calendar.date(byAdding: component, value: -offset, to: loopAnchor) else { break }
            let interval = calendar.dateInterval(of: component, for: ref)
                ?? DateInterval(start: calendar.startOfDay(for: ref), duration: 86_400)
            // Manteniamo sempre la cella corrente (offset 0); fermiamo quando la cella
            // inizia prima della finestra (così la finestra ha il numero giusto di celle).
            if offset > 0 && interval.start < windowStart { break }

            // Intervallo semi-aperto [inizio, fine): la mezzanotte finale appartiene
            // alla cella successiva, non a questa (evita doppi conteggi sul confine).
            func inCell(_ date: Date) -> Bool { date >= interval.start && date < interval.end }

            // Le celle future (ancora non arrivate) hanno sempre count = 0.
            let isFuture = interval.start > now
            let count = isFuture ? 0 : entries
                .filter { inCell($0.entryDate) }
                .reduce(0) { $0 + $1.count }

            // Quanti giorni di questa cella sono di riposo: scontano l'obiettivo atteso.
            let totalDays = max(1, Int((interval.duration / 86_400).rounded()))
            let restInCell = restDays.filter(inCell).count
            let isRest = !isFuture && restInCell >= totalDays
            let activeFactor = Double(totalDays - restInCell) / Double(totalDays)
            let effectiveTarget = isRest ? 0 : max(1, Int((Double(cellTarget) * activeFactor).rounded()))

            // True se la cella include il giorno corrente.
            let isToday = today >= interval.start && today < interval.end

            cells.append(HeatCell(
                date: interval.start,
                label: cellLabel(for: interval.start, component: component),
                count: count,
                fraction: effectiveTarget > 0 ? Double(count) / Double(effectiveTarget) : 0,
                isComplete: !isRest && !isFuture && count >= effectiveTarget,
                isRest: isRest,
                isToday: isToday
            ))
        }
        cells.reverse() // dal più vecchio al più recente

        // ── Current streak: all-time, non limitata alla finestra ──────────────
        // Itera a ritroso da oggi, cella per cella, contando quelle complete.
        // Il riposo è trasparente (non incrementa né interrompe).
        // La cella corrente (oggi) non interrompe la streak se ancora incompleta
        // perché l'utente ha ancora tempo per completarla.
        var currentStreak = 0
        var cursor = calendar.startOfDay(for: Date())
        let todayCellStart = calendar.dateInterval(of: component, for: Date())?.start
        for _ in 0..<5000 {
            guard let cellInterval = calendar.dateInterval(of: component, for: cursor) else { break }
            let restInCell = restDays.filter { $0 >= cellInterval.start && $0 < cellInterval.end }.count
            let totalInCell = max(1, Int((cellInterval.duration / 86_400).rounded()))
            if restInCell < totalInCell {
                // Cella non interamente a riposo: valutiamo il completamento.
                let cellCount = entries
                    .filter { $0.entryDate >= cellInterval.start && $0.entryDate < cellInterval.end }
                    .reduce(0) { $0 + $1.count }
                let activeFac = Double(totalInCell - restInCell) / Double(totalInCell)
                let effTarget = max(1, Int((Double(cellTarget) * activeFac).rounded()))
                if cellCount >= effTarget {
                    currentStreak += 1
                } else if cellInterval.start != todayCellStart {
                    // Cella passata incompleta → streak interrotta.
                    break
                }
                // Cella corrente ancora in corso → non incrementiamo, ma non interrompiamo.
            }
            // Cella a riposo → trasparente: avanziamo senza modificare la streak.
            guard let prev = calendar.date(byAdding: component, value: -1, to: cellInterval.start) else { break }
            cursor = prev
        }

        // ── Best streak: massima all-time ─────────────────────────────────────
        // Stessa logica della current streak ma in avanti: itera da prima entry a oggi.
        var bestStreak = 0
        if let firstDate = entries.min(by: { $0.entryDate < $1.entryDate })?.entryDate {
            var bCursor = calendar.dateInterval(of: component, for: firstDate)?.start ?? firstDate
            let bEnd = calendar.dateInterval(of: component, for: Date())?.start ?? Date()
            var bRunning = 0
            while bCursor <= bEnd {
                guard let cellInterval = calendar.dateInterval(of: component, for: bCursor) else { break }
                let restInCell = restDays.filter { $0 >= cellInterval.start && $0 < cellInterval.end }.count
                let totalInCell = max(1, Int((cellInterval.duration / 86_400).rounded()))
                if restInCell < totalInCell {
                    let cellCount = entries
                        .filter { $0.entryDate >= cellInterval.start && $0.entryDate < cellInterval.end }
                        .reduce(0) { $0 + $1.count }
                    let activeFac = Double(totalInCell - restInCell) / Double(totalInCell)
                    let effTarget = max(1, Int((Double(cellTarget) * activeFac).rounded()))
                    if cellCount >= effTarget {
                        bRunning += 1
                        bestStreak = max(bestStreak, bRunning)
                    } else if cellInterval.start != todayCellStart {
                        bRunning = 0
                    }
                }
                guard let next = calendar.date(byAdding: component, value: 1, to: cellInterval.start) else { break }
                bCursor = next
            }
        }

        // Completamento medio della finestra = media di quanto sono piene le celle,
        // escludendo le celle di riposo.
        let active = cells.filter { !$0.isRest }
        let completion = active.isEmpty
            ? 0
            : active.map { min(1, $0.fraction) }.reduce(0, +) / Double(active.count)

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
            hasRest: cells.contains(where: \.isRest),
            subtitle: subtitleForCell(component: component)
        )
    }

    // MARK: - Helpers

    private func subtitleForCell(component: Calendar.Component) -> String {
        let granularity: String
        switch component {
        case .day:        granularity = "per giorno"
        case .weekOfYear: granularity = "per settimana"
        case .month:      granularity = "per mese"
        default:          granularity = ""
        }
        return "\(periodLabel) · \(granularity)"
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

    private func formatWeekRange(from start: Date, to end: Date) -> String {
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)

        if startYear != endYear {
            // Es. "30 dic 2025 – 5 gen 2026"
            return "\(startDay) \(shortMonth(start)) \(startYear) – \(endDay) \(shortMonth(end)) \(endYear)"
        } else if startMonth != endMonth {
            // Es. "30 mag – 5 giu 2026"
            return "\(startDay) \(shortMonth(start)) – \(endDay) \(shortMonth(end)) \(endYear)"
        } else {
            // Es. "9 – 15 giu 2026"
            return "\(startDay) – \(endDay) \(shortMonth(end)) \(endYear)"
        }
    }

    private func shortMonth(_ date: Date) -> String {
        Self.shortMonthFormatter.string(from: date)
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

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy"
        return f
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "MMM"
        return f
    }()
}
