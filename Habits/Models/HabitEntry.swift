import Foundation
import SwiftData

/// Log giornaliero per un'abitudine: quante volte è stata fatta in una data.
/// Un record per `(habitId, entryDate)`; l'unicità per giorno è garantita in
/// codice (CloudKit non supporta vincoli di unicità).
@Model
final class HabitEntry {
    var id: UUID = UUID()
    /// Riferimento all'abitudine (per id, non come relazione: la logica di
    /// avanzamento lavora su array piatti filtrati per `habitId`).
    var habitId: UUID = UUID()
    /// Giorno del log, normalizzato a mezzanotte locale.
    var entryDate: Date = Date.now
    var count: Int = 0
    /// Giorno di riposo: stato neutro, non conta come fatto né come mancato.
    var skipped: Bool = false

    init(
        id: UUID = UUID(),
        habitId: UUID,
        entryDate: Date,
        count: Int = 0,
        skipped: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.entryDate = entryDate
        self.count = count
        self.skipped = skipped
    }
}
