import SwiftUI
import HabitsKit

/// Sezione Analytics: heatmap di completamento, streak e percentuale per abitudine,
/// sulla finestra temporale scelta dall'utente (periodo di calendario fisso).
struct AnalyticsView: View {
    @EnvironmentObject private var habitsVM: HabitsViewModel
    @StateObject private var vm = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Periodo", selection: $vm.range) {
                    ForEach(AnalyticsRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Navigazione tra periodi
                HStack(spacing: 12) {
                    Button {
                        vm.goToPreviousPeriod()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Spacer()

                    Text(vm.periodLabel)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Button {
                        vm.goToNextPeriod()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(vm.canGoNext ? .primary : Color(.systemGray3))
                    .disabled(!vm.canGoNext)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                Group {
                    if habitsVM.habits.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar",
                            title: "Niente da analizzare",
                            message: "Aggiungi abitudini e inizia a registrarle per vedere i trend."
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(vm.stats) { stat in
                                    HabitStatsCard(stat: stat)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Analytics")
            .task(id: habitsVM.dataVersion) {
                vm.load(habits: habitsVM.habits, entries: habitsVM.entries)
            }
        }
    }
}

private struct HabitStatsCard: View {
    let stat: HabitStats
    private var habit: Habit { stat.habit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(habit.swiftUIColor.opacity(0.18))
                    Image(systemName: habit.icon).foregroundStyle(habit.swiftUIColor)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.name).font(.headline)
                    Text(stat.subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((stat.completion * 100).rounded()))%")
                    .font(.title3.bold())
                    .foregroundStyle(habit.swiftUIColor)
            }

            HeatmapView(stat: stat, color: habit.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Label("serie \(stat.currentStreak)", systemImage: "flame.fill")
                Label("record \(stat.bestStreak)", systemImage: "trophy.fill")
                if stat.hasRest {
                    Spacer()
                    Label("riposo", systemImage: "moon.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

/// Griglia di celle colorate per intensità di completamento. La disposizione
/// (riga unica, griglia mensile, etichette) è decisa in `HabitStats`.
private struct HeatmapView: View {
    let stat: HabitStats
    let color: Color

    private enum Item: Identifiable {
        case blank(Int)
        case cell(HeatCell)
        var id: String {
            switch self {
            case .blank(let i): return "b\(i)"
            case .cell(let c):  return c.id.uuidString
            }
        }
    }

    private let gap: CGFloat = 5

    /// Dimensione fissa che garantisce di stare anche sugli schermi più stretti
    /// (fino a ~13 colonne per trimestre/anno).
    private var cellSize: CGFloat {
        switch stat.columns {
        case ...7:  return 32
        case ...10: return 24
        default:    return 18
        }
    }

    private var items: [Item] {
        (0..<stat.leadingBlanks).map(Item.blank) + stat.cells.map(Item.cell)
    }

    private var rows: [[Item]] {
        let cols = max(1, stat.columns)
        return stride(from: 0, to: items.count, by: cols).map { start in
            Array(items[start..<min(start + cols, items.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            if let header = stat.header {
                HStack(spacing: gap) {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, h in
                        Text(h)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize)
                    }
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(rows[r]) { item in
                        itemView(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: Item) -> some View {
        switch item {
        case .blank:
            Color.clear.frame(width: cellSize, height: cellSize)
        case .cell(let cell):
            VStack(spacing: 3) {
                if stat.showCellLabels {
                    Text(cell.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                RoundedRectangle(cornerRadius: cellSize * 0.24)
                    .fill(cellColor(cell))
                    .frame(width: cellSize, height: cellSize)
                    .overlay {
                        if cell.isRest {
                            Image(systemName: "moon.fill")
                                .font(.system(size: cellSize * 0.5))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .overlay {
                        if cell.isToday {
                            RoundedRectangle(cornerRadius: cellSize * 0.24)
                                .strokeBorder(.primary.opacity(0.55), lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    private func cellColor(_ cell: HeatCell) -> Color {
        if cell.isRest { return Color(.systemGray3) }
        guard cell.fraction > 0 else { return Color(.systemGray5) }
        return color.opacity(0.30 + 0.70 * min(1, cell.fraction))
    }
}
