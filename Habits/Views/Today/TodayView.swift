import SwiftUI

/// Vista giornaliera: elenco delle abitudini da spuntare per il giorno selezionato.
struct TodayView: View {
    @EnvironmentObject private var vm: HabitsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.habits.isEmpty {
                    ProgressView().controlSize(.large)
                } else if vm.habits.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "Nessuna abitudine",
                        message: "Aggiungi la tua prima abitudine dalla tab Abitudini."
                    )
                } else {
                    content
                }
            }
            .navigationTitle(navTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vm.isToday {
                        Button("Oggi") { vm.goToToday() }
                    }
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            DateStripView(selected: $vm.selectedDate)
                .padding(.vertical, 8)

            LazyVStack(spacing: 12) {
                ForEach(vm.progresses, id: \.habit.id) { progress in
                    HabitTodayRow(progress: progress)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable { await vm.load() }
    }

    private var navTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        if vm.isToday { return "Oggi" }
        f.dateFormat = "EEEE d MMM"
        return f.string(from: vm.selectedDate).capitalized
    }
}

/// Riga di un'abitudine nella vista Today.
private struct HabitTodayRow: View {
    @EnvironmentObject private var vm: HabitsViewModel
    let progress: HabitProgress

    private var habit: Habit { progress.habit }

    var body: some View {
        HStack(spacing: 14) {
            CircularProgressView(
                fraction: progress.fraction,
                color: habit.swiftUIColor,
                lineWidth: 6,
                icon: habit.icon
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .strikethrough(progress.isComplete, color: .secondary)
                Text(targetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actionControl
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(progress.isComplete ? habit.swiftUIColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    /// Per target=1 mostra un toggle; per target>1 mostra stepper +/- con conteggio.
    @ViewBuilder
    private var actionControl: some View {
        if habit.targetCount == 1 && habit.period == .daily {
            Button {
                Task { await vm.toggle(habit) }
            } label: {
                Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(progress.isComplete ? habit.swiftUIColor : .secondary)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 10) {
                Button {
                    Task { await vm.decrement(habit) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(progress.todayCount == 0)

                Text("\(progress.todayCount)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 22)

                Button {
                    Task { await vm.increment(habit) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(habit.swiftUIColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var targetText: String {
        let unit = habit.period.unitLabel
        if habit.targetCount == 1 {
            return "\(progress.currentCount)/\(habit.targetCount) \(unit)"
        }
        return "\(progress.currentCount)/\(habit.targetCount) \(unit)"
    }
}
