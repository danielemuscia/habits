import Foundation

/// Log giornaliero per un'abitudine: quante volte è stata fatta in una data.
/// Mappa la tabella `public.habit_entries`.
struct HabitEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var habitId: UUID
    var userId: UUID
    var entryDate: Date
    var count: Int
    /// Giorno di riposo: stato neutro, non conta come fatto né come mancato.
    var skipped: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case entryDate = "entry_date"
        case count
        case skipped
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension HabitEntry {
    /// Decodifica tollerante: `skipped` può mancare (DB senza la migration 0002)
    /// e in tal caso vale `false`, evitando di rompere l'intera fetch dei log.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        habitId = try c.decode(UUID.self, forKey: .habitId)
        userId = try c.decode(UUID.self, forKey: .userId)
        entryDate = try c.decode(Date.self, forKey: .entryDate)
        count = try c.decode(Int.self, forKey: .count)
        skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

/// Payload usato per upsert di un log (chiave: habit_id + entry_date).
struct HabitEntryUpsert: Encodable {
    var habitId: UUID
    var userId: UUID
    var entryDate: String   // formato "yyyy-MM-dd"
    var count: Int
    var skipped: Bool

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case userId = "user_id"
        case entryDate = "entry_date"
        case count
        case skipped
    }
}
