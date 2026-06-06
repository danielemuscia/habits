import SwiftUI
import Charts

/// Sezione Analytics: trend, streak e tasso di completamento per abitudine.
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
                .padding(.bottom, 8)

                Group {
                    if vm.isLoading && vm.stats.isEmpty {
                        ProgressView().controlSize(.large)
                    } else if habitsVM.habits.isEmpty {
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
            .task(id: habitsVM.habits.map(\.id)) {
                await vm.load(habits: habitsVM.habits)
            }
            .refreshable { await vm.load(habits: habitsVM.habits) }
        }
    }
}

private struct HabitStatsCard: View {
    let stat: HabitStats
    private var habit: Habit { stat.habit }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(habit.swiftUIColor.opacity(0.18))
                    Image(systemName: habit.icon).foregroundStyle(habit.swiftUIColor)
                }
                .frame(width: 36, height: 36)
                Text(habit.name).font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                metric("Streak", "\(stat.currentStreak)", "flame.fill", .orange)
                Divider().frame(height: 34)
                metric("Record", "\(stat.bestStreak)", "trophy.fill", .yellow)
                Divider().frame(height: 34)
                metric("Completamento", "\(Int(stat.completionRate * 100))%", "checkmark.seal.fill", habit.swiftUIColor)
            }

            chart
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            Text(value).font(.title3.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var chart: some View {
        Chart(stat.series) { bucket in
            BarMark(
                x: .value("Periodo", bucket.label),
                y: .value("Conteggio", bucket.count)
            )
            .foregroundStyle(bucket.isComplete ? habit.swiftUIColor : habit.swiftUIColor.opacity(0.35))
            .cornerRadius(4)

            RuleMark(y: .value("Obiettivo", habit.targetCount))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .frame(height: 130)
        .chartXAxis {
            // L'asse X è categorico (etichette stringa): senza selezione esplicita
            // verrebbero mostrate tutte e si sovrapporrebbero. Mostriamo ~6 etichette.
            AxisMarks(values: thinnedLabels) {
                AxisValueLabel().font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    /// Sottoinsieme uniforme delle etichette dei periodi, per evitare sovrapposizioni.
    private var thinnedLabels: [String] {
        let labels = stat.series.map(\.label)
        let maxLabels = 6
        guard labels.count > maxLabels else { return labels }
        let step = Int((Double(labels.count) / Double(maxLabels)).rounded(.up))
        return labels.enumerated()
            .filter { $0.offset % step == 0 }
            .map(\.element)
    }
}
