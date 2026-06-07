import SwiftUI
import HabitsKit

/// Elenco di tutte le abitudini, con creazione/modifica/eliminazione.
struct HabitListView: View {
    @EnvironmentObject private var vm: HabitsViewModel

    @State private var showingEditor = false
    @State private var editingHabit: Habit?

    var body: some View {
        NavigationStack {
            Group {
                if vm.habits.isEmpty {
                    EmptyStateView(
                        icon: "plus.circle",
                        title: "Crea la prima abitudine",
                        message: "Tocca + per iniziare a tracciare qualcosa."
                    )
                } else {
                    List {
                        ForEach(vm.habits) { habit in
                            Button {
                                editingHabit = habit
                            } label: {
                                HabitListRow(habit: habit)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Abitudini")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                HabitEditorView()
            }
            .sheet(item: $editingHabit) { habit in
                HabitEditorView(habit: habit)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for habit in offsets.map({ vm.habits[$0] }) {
            vm.deleteHabit(habit)
        }
    }
}

private struct HabitListRow: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(habit.swiftUIColor.opacity(0.18))
                Image(systemName: habit.icon)
                    .foregroundStyle(habit.swiftUIColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.body.weight(.medium))
                Text("\(habit.targetCount)× \(habit.period.unitLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
