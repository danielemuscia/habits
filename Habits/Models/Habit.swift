import Foundation
import SwiftData
import SwiftUI

/// Una abitudine definita dall'utente. Persistita localmente con SwiftData e
/// sincronizzata via CloudKit (DB privato dell'utente).
///
/// Nota CloudKit: tutte le proprietà hanno un valore di default e non esistono
/// vincoli di unicità (non supportati con CloudKit). L'unicità per giorno dei
/// log è garantita in codice nel `HabitsViewModel`.
@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    /// Descrizione opzionale. Non si chiama `description` per non collidere con
    /// la proprietà omonima dell'oggetto persistente sottostante.
    var details: String?
    var icon: String = "star.fill"
    var color: String = "#34C759"
    var targetCount: Int = 1
    var period: HabitPeriod = HabitPeriod.daily
    /// Se vera, l'abitudine si può registrare più volte nello stesso giorno
    /// (contatore +/-) anche con obiettivo su un periodo più ampio.
    var allowsMultiplePerDay: Bool = false
    var sortOrder: Int = 0
    var archived: Bool = false
    var createdAt: Date = Date.now

    init(
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
    var swiftUIColor: Color { Color(hex: color) ?? .green }

    /// Vero quando la registrazione giornaliera usa un contatore +/- invece
    /// della spunta on/off: o perché l'utente lo ha scelto esplicitamente,
    /// oppure perché un obiettivo giornaliero > 1 implica più completamenti al
    /// giorno per costruzione.
    var usesDailyCounter: Bool {
        allowsMultiplePerDay || (period == .daily && targetCount > 1)
    }
}
