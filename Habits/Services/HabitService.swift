import Foundation
import Supabase

/// CRUD per abitudini e log, su Supabase/Postgrest.
struct HabitService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Habits

    func fetchHabits(includeArchived: Bool = false) async throws -> [Habit] {
        var query = client.from("habits").select()
        if !includeArchived {
            query = query.eq("archived", value: false)
        }
        return try await query
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    @discardableResult
    func createHabit(_ habit: NewHabit) async throws -> Habit {
        try await client.from("habits")
            .insert(habit, returning: .representation)
            .single()
            .execute()
            .value
    }

    @discardableResult
    func updateHabit(id: UUID, with update: HabitUpdate) async throws -> Habit {
        try await client.from("habits")
            .update(update, returning: .representation)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func deleteHabit(id: UUID) async throws {
        try await client.from("habits")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Entries

    /// Tutti i log per un intervallo di date (vista Today / settimana).
    func fetchEntries(from start: Date, to end: Date) async throws -> [HabitEntry] {
        let startStr = SupabaseManager.dateFormatter.string(from: start)
        let endStr = SupabaseManager.dateFormatter.string(from: end)
        return try await client.from("habit_entries")
            .select()
            .gte("entry_date", value: startStr)
            .lte("entry_date", value: endStr)
            .execute()
            .value
    }

    /// Log di una singola abitudine (Analytics / dettaglio).
    func fetchEntries(habitId: UUID, from start: Date, to end: Date) async throws -> [HabitEntry] {
        let startStr = SupabaseManager.dateFormatter.string(from: start)
        let endStr = SupabaseManager.dateFormatter.string(from: end)
        return try await client.from("habit_entries")
            .select()
            .eq("habit_id", value: habitId.uuidString)
            .gte("entry_date", value: startStr)
            .lte("entry_date", value: endStr)
            .order("entry_date", ascending: true)
            .execute()
            .value
    }

    /// Imposta il conteggio per (abitudine, data). Upsert sulla chiave unica.
    @discardableResult
    func setEntryCount(habitId: UUID, userId: UUID, date: Date, count: Int) async throws -> HabitEntry {
        let payload = HabitEntryUpsert(
            habitId: habitId,
            userId: userId,
            entryDate: SupabaseManager.dateFormatter.string(from: date),
            count: max(0, count)
        )
        return try await client.from("habit_entries")
            .upsert(payload, onConflict: "habit_id,entry_date", returning: .representation)
            .single()
            .execute()
            .value
    }
}
