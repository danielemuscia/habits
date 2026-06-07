import Foundation
import SwiftData

/// Log giornaliero per un'abitudine: quante volte è stata fatta in una data.
/// Un record per `(habitId, entryDate)`; l'unicità per giorno è garantita in
/// codice (CloudKit non supporta vincoli di unicità).
@Model
public final class HabitEntry {
    public var id: UUID = UUID()
    public var habitId: UUID = UUID()
    /// Giorno del log, normalizzato a mezzanotte locale.
    public var entryDate: Date = Date.now
    public var count: Int = 0
    /// Giorno di riposo: stato neutro, non conta come fatto né come mancato.
    public var skipped: Bool = false

    public init(
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
