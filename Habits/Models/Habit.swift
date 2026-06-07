import Foundation
import SwiftUI

/// Una abitudine definita dall'utente.
/// Mappa la tabella `public.habits`.
struct Habit: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var name: String
    var description: String?
    var icon: String
    var color: String
    var targetCount: Int
    var period: HabitPeriod
    /// Se vera, l'abitudine si può registrare più volte nello stesso giorno
    /// (contatore +/-) anche con obiettivo su un periodo più ampio.
    var allowsMultiplePerDay: Bool
    var sortOrder: Int
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case targetCount = "target_count"
        case period
        case allowsMultiplePerDay = "allows_multiple_per_day"
        case sortOrder = "sort_order"
        case archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

extension Habit {
    /// Decodifica tollerante: `allows_multiple_per_day` può mancare (DB senza la
    /// migration 0003) e in tal caso vale `false`, evitando di rompere la fetch.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        icon = try c.decode(String.self, forKey: .icon)
        color = try c.decode(String.self, forKey: .color)
        targetCount = try c.decode(Int.self, forKey: .targetCount)
        period = try c.decode(HabitPeriod.self, forKey: .period)
        allowsMultiplePerDay = try c.decodeIfPresent(Bool.self, forKey: .allowsMultiplePerDay) ?? false
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        archived = try c.decode(Bool.self, forKey: .archived)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

/// Payload per inserire una nuova abitudine (senza i campi gestiti dal DB).
struct NewHabit: Encodable {
    var userId: UUID
    var name: String
    var description: String?
    var icon: String
    var color: String
    var targetCount: Int
    var period: HabitPeriod
    var allowsMultiplePerDay: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case targetCount = "target_count"
        case period
        case allowsMultiplePerDay = "allows_multiple_per_day"
        case sortOrder = "sort_order"
    }
}

/// Payload per aggiornare un'abitudine esistente.
struct HabitUpdate: Encodable {
    var name: String
    var description: String?
    var icon: String
    var color: String
    var targetCount: Int
    var period: HabitPeriod
    var allowsMultiplePerDay: Bool
    var archived: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case icon
        case color
        case targetCount = "target_count"
        case period
        case allowsMultiplePerDay = "allows_multiple_per_day"
        case archived
    }
}
