import Foundation
import SwiftData
import SwiftUI

/// Una abitudine definita dall'utente. Persistita con SwiftData e sincronizzata
/// via CloudKit. Compatibile CloudKit: campi con default, nessun vincolo unique.
@Model
public final class Habit {
    public var id: UUID = UUID()
    public var name: String = ""
    public var details: String?
    public var icon: String = "star.fill"
    public var color: String = "#34C759"
    public var targetCount: Int = 1
    public var period: HabitPeriod = HabitPeriod.daily
    public var allowsMultiplePerDay: Bool = false
    public var sortOrder: Int = 0
    public var archived: Bool = false
    public var createdAt: Date = Date.now

    public init(
        id: UUID = UUID(),
        name: String,
        details: String? = nil,
        icon: String = "star.fill",
        color: String = "#34C759",
        targetCount: Int = 1,
        period: HabitPeriod = .daily,
        allowsMultiplePerDay: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.icon = icon
        self.color = color
        self.targetCount = targetCount
        self.period = period
        self.allowsMultiplePerDay = allowsMultiplePerDay
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// Colore SwiftUI derivato dalla stringa hex.
    public var swiftUIColor: Color { Color(hex: color) ?? .green }

    /// Vero quando la registrazione giornaliera usa un contatore +/- invece
    /// della spunta: scelta esplicita dell'utente, oppure obiettivo giornaliero
    /// > 1 (più completamenti al giorno per costruzione).
    public var usesDailyCounter: Bool {
        allowsMultiplePerDay || (period == .daily && targetCount > 1)
    }
}
