import SwiftUI
import HabitsKit

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
        // List (non LazyVStack) per avere lo swipe-to-rest nativo sulle righe.
        List {
            DateStripView(selected: $vm.selectedDate, scrollToTodayToken: vm.scrollToTodayToken)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(vm.progresses, id: \.habit.id) { progress in
                HabitTodayRow(progress: progress)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
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
                Text(progress.isRest ? restStatusText : targetText)
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
        // Swipe (azione primaria, scopribile) + long-press (scorciatoia bonus).
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                vm.setRest(habit, !progress.isRest)
            } label: {
                Label(restActionLabel, systemImage: progress.isRest ? "arrow.uturn.backward" : "moon.zzz.fill")
            }
            .tint(progress.isRest ? .gray : .indigo)
        }
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
            HabitRingView(
                fraction: progress.ratio,
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

    /// Menu contestuale (long-press) per marcare/smarcare il riposo.
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
                Label(restMenuLabel, systemImage: "moon.zzz.fill")
            }
        }
    }

    // MARK: - Label adattive al periodo dell'abitudine
    // Per habit non-daily il "riposo" salta l'intero periodo (settimana/mese/anno).

    /// Testo breve per lo swipe / azione.
    private var restActionLabel: String {
        if progress.isRest { return "Annulla" }
        switch habit.period {
        case .daily:   return "Riposo"
        case .weekly:  return "Salta sett."
        case .monthly: return "Salta mese"
        case .yearly:  return "Salta anno"
        }
    }

    /// Testo esteso per il menu long-press.
    private var restMenuLabel: String {
        switch habit.period {
        case .daily:   return "Segna giorno di riposo"
        case .weekly:  return "Salta questa settimana"
        case .monthly: return "Salta questo mese"
        case .yearly:  return "Salta quest'anno"
        }
    }

    /// Testo di stato mostrato sotto il nome quando è attivo il riposo.
    private var restStatusText: String {
        switch habit.period {
        case .daily:   return "Giorno di riposo"
        case .weekly:  return "Settimana di riposo"
        case .monthly: return "Mese di riposo"
        case .yearly:  return "Anno di riposo"
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
