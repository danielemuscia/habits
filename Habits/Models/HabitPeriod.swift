import Foundation

/// Periodicità con cui un'abitudine va ripetuta.
enum HabitPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// Etichetta mostrata in UI (es. "al giorno").
    var unitLabel: String {
        switch self {
        case .daily:   return "al giorno"
        case .weekly:  return "a settimana"
        case .monthly: return "al mese"
        case .yearly:  return "all'anno"
        }
    }

    /// Nome singolare del periodo.
    var displayName: String {
        switch self {
        case .daily:   return "Giorno"
        case .weekly:  return "Settimana"
        case .monthly: return "Mese"
        case .yearly:  return "Anno"
        }
    }

    /// Intervallo `[start, end)` del periodo che contiene `date`, secondo `calendar`.
    func dateInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let component: Calendar.Component
        switch self {
        case .daily:   component = .day
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        case .yearly:  component = .year
        }
        return calendar.dateInterval(of: component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }
}
