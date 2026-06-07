import SwiftUI

/// Vista giornaliera: elenco delle abitudini da spuntare per il giorno selezionato.
struct TodayView: View {
    @EnvironmentObject private var vm: HabitsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.habits.isEmpty {
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
            DateStripView(selected: $vm.selectedDate, scrollToTodayToken: vm.scrollToTodayToken)
                .padding(.vertical, 8)

            LazyVStack(spacing: 12) {
                ForEach(vm.progresses, id: \.habit.id) { progress in
                    HabitTodayRow(progress: progress)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .refreshable { vm.reload() }
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

    /// Scala dell'anello, usata per il "pop" al raggiungimento dell'obiettivo.
    @State private var popScale: CGFloat = 1

    var body: some View {
        HStack(spacing: 14) {
            leadingRing

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                Text(progress.isRest ? "Giorno di riposo" : targetText)
                    .font(.caption)
                    .foregroundStyle(progress.isRest ? Color.indigo : .secondary)
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
        .contextMenu { restMenu }
    }

    /// Anello di avanzamento, oppure un indicatore di riposo se il giorno è marcato.
    @ViewBuilder
    private var leadingRing: some View {
        if progress.isRest {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Image(systemName: "moon.zzz.fill").foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
        } else {
            CircularProgressView(
                fraction: progress.fraction,
                color: habit.swiftUIColor,
                lineWidth: 6,
                icon: habit.icon
            )
            .frame(width: 44, height: 44)
            .scaleEffect(popScale)
            .onChange(of: progress.isComplete) { _, isComplete in
                guard isComplete else { return }
                celebratePop()
            }
        }
    }

    /// Menu contestuale (long-press) per marcare/smarcare il giorno di riposo.
    @ViewBuilder
    private var restMenu: some View {
        if progress.isRest {
            Button {
                vm.setRest(habit, false)
            } label: {
                Label("Annulla riposo", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                vm.setRest(habit, true)
            } label: {
                Label("Segna giorno di riposo", systemImage: "moon.zzz.fill")
            }
        }
    }

    /// Lo stepper +/- serve quando l'abitudine ammette più completamenti nello
    /// *stesso* giorno (`habit.usesDailyCounter`): target giornaliero > 1, oppure
    /// l'utente ha attivato "Più volte al giorno" anche con obiettivo settimanale/
    /// mensile (es. 2 sessioni oggi verso "5 a settimana"). Negli altri casi si
    /// completa una volta al giorno con un toggle: la spunta riflette "fatto
    /// **oggi**" (`todayCount`), mentre l'anello e il testo a sinistra mostrano
    /// l'avanzamento del periodo. Si va oltre il target completando più giorni/
    /// periodi (es. "6/5"), quindi il toggle non si disabilita.
    @ViewBuilder
    private var actionControl: some View {
        if progress.isRest {
            Button {
                vm.setRest(habit, false)
            } label: {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.indigo)
            }
            .buttonStyle(.plain)
        } else if !habit.usesDailyCounter {
            let doneToday = progress.todayCount > 0
            Button {
                vm.toggle(habit)
            } label: {
                Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(doneToday ? habit.swiftUIColor : .secondary)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 10) {
                Button {
                    vm.decrement(habit)
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
                    vm.increment(habit)
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
        "\(progress.currentCount)/\(habit.targetCount) \(habit.period.unitLabel)"
    }

    /// Breve "pop" celebrativo dell'anello quando l'obiettivo del periodo viene raggiunto.
    private func celebratePop() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { popScale = 1.3 }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { popScale = 1 }
        }
    }
}
