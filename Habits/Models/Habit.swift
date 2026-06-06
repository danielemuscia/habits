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
        case sortOrder = "sort_order"
        case archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Colore SwiftUI derivato dalla stringa hex.
    var swiftUIColor: Color { Color(hex: color) ?? .green }
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
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case targetCount = "target_count"
        case period
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
    var archived: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case icon
        case color
        case targetCount = "target_count"
        case period
        case archived
    }
}
