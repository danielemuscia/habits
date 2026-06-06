import Foundation

/// Log giornaliero per un'abitudine: quante volte è stata fatta in una data.
/// Mappa la tabella `public.habit_entries`.
struct HabitEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var habitId: UUID
    var userId: UUID
    var entryDate: Date
    var count: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case entryDate = "entry_date"
        case count
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Payload usato per upsert di un log (chiave: habit_id + entry_date).
struct HabitEntryUpsert: Encodable {
    var habitId: UUID
    var userId: UUID
    var entryDate: String   // formato "yyyy-MM-dd"
    var count: Int

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case userId = "user_id"
        case entryDate = "entry_date"
        case count
    }
}
