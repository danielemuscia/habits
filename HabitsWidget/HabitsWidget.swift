import WidgetKit
import SwiftUI
import SwiftData
import HabitsKit

/// Stato di un'abitudine "appiattito" per il rendering nella timeline.
struct HabitDot: Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    /// Rapporto non cappato (può superare 1: overperformance → secondo giro).
    let ratio: Double
    let isRest: Bool
    let todayCount: Int
}

struct HabitsTimelineEntry: TimelineEntry {
    let date: Date
    let dots: [HabitDot]

    static let placeholder = HabitsTimelineEntry(
        date: .now,
        dots: (0..<4).map {
            HabitDot(id: UUID(), name: "Abitudine", icon: HabitIcons.symbols[$0],
                     colorHex: HabitPalette.colors[$0], ratio: Double($0) / 2,
                     isRest: false, todayCount: $0)
        }
    )
}

/// Provider basato su App Intent: legge dallo store condiviso (App Group) le
/// abitudini scelte nella configurazione e ne calcola lo stato di oggi.
struct Provider: AppIntentTimelineProvider {
    typealias Intent = SelectHabitsIntent
    typealias Entry = HabitsTimelineEntry

    func placeholder(in context: Context) -> HabitsTimelineEntry { .placeholder }

    func snapshot(for configuration: SelectHabitsIntent, in context: Context) async -> HabitsTimelineEntry {
        await makeEntry(for: configuration)
    }

    func timeline(for configuration: SelectHabitsIntent, in context: Context) async -> Timeline<HabitsTimelineEntry> {
        let entry = await makeEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(Self.nextReload()))
    }

    @MainActor
    private func makeEntry(for configuration: SelectHabitsIntent) -> HabitsTimelineEntry {
        let context = ModelContext(AppModelContainer.shared)
        let all = HabitStore.activeHabits(in: context)
        let entries = HabitStore.allEntries(in: context)

        let selectedIds = configuration.habits?.map(\.id) ?? []
        let chosen = selectedIds.isEmpty
            ? all
            : selectedIds.compactMap { id in all.first { $0.id == id } } // rispetta l'ordine scelto

        let cal = HabitStore.calendar
        let dots = chosen.map { habit -> HabitDot in
            let p = HabitProgress.make(habit: habit, entries: entries, on: Date(), calendar: cal)
            return HabitDot(
                id: habit.id, name: habit.name, icon: habit.icon, colorHex: habit.color,
                ratio: p.ratio, isRest: p.isRest, todayCount: p.todayCount
            )
        }
        return HabitsTimelineEntry(date: Date(), dots: dots)
    }

    /// Prossimo refresh: alla prossima ora piena (e comunque entro mezzanotte per
    /// il cambio di giorno). Le modifiche dal widget/app forzano già un reload.
    private static func nextReload() -> Date {
        let cal = Calendar.current
        let nextHour = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return cal.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }
}

struct HabitsWidget: Widget {
    static let kind = "HabitsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectHabitsIntent.self, provider: Provider()) { entry in
            DotsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Abitudini")
        .description("Spunta le tue abitudini direttamente dalla Home.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
