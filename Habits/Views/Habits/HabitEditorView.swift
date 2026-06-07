import SwiftUI

/// Form per creare o modificare un'abitudine.
struct HabitEditorView: View {
    @EnvironmentObject private var vm: HabitsViewModel
    @Environment(\.dismiss) private var dismiss

    /// Se valorizzata, siamo in modalità modifica.
    var habit: Habit?

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var color: String
    @State private var targetCount: Int
    @State private var period: HabitPeriod
    @State private var allowsMultiplePerDay: Bool

    private var isEditing: Bool { habit != nil }

    /// Un obiettivo giornaliero > 1 implica già più completamenti al giorno
    /// (contatore), quindi l'opzione esplicita sarebbe ridondante: la nascondiamo.
    private var multiplePerDayIsImplicit: Bool {
        period == .daily && targetCount > 1
    }

    init(habit: Habit? = nil) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _description = State(initialValue: habit?.details ?? "")
        _icon = State(initialValue: habit?.icon ?? HabitIcons.symbols.first!)
        _color = State(initialValue: habit?.color ?? HabitPalette.colors.first!)
        _targetCount = State(initialValue: habit?.targetCount ?? 1)
        _period = State(initialValue: habit?.period ?? .daily)
        _allowsMultiplePerDay = State(initialValue: habit?.allowsMultiplePerDay ?? false)
    }

    private var selectedColor: Color { Color(hex: color) ?? .green }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (es. Bere acqua)", text: $name)
                    TextField("Descrizione (opzionale)", text: $description, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Frequenza") {
                    Stepper(value: $targetCount, in: 1...100) {
                        HStack {
                            Text("Quante volte")
                            Spacer()
                            Text("\(targetCount)").foregroundStyle(.secondary)
                        }
                    }
                    Picker("Periodo", selection: $period) {
                        ForEach(HabitPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Obiettivo: \(targetCount)× \(period.unitLabel)")
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondary)

                    if !multiplePerDayIsImplicit {
                        Toggle("Più volte al giorno", isOn: $allowsMultiplePerDay)
                        Text(allowsMultiplePerDay
                             ? "Puoi registrarla più volte nello stesso giorno (contatore +/-)."
                             : "Si spunta una volta al giorno; l'obiettivo si raggiunge in più giorni.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Icona") {
                    iconGrid
                }

                Section("Colore") {
                    colorRow
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            guard let habit else { return }
                            vm.deleteHabit(habit)
                            dismiss()
                        } label: {
                            Label("Elimina abitudine", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica" : "Nuova abitudine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(HabitIcons.symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(icon == symbol ? .white : selectedColor)
                    .background(
                        Circle().fill(icon == symbol ? selectedColor : selectedColor.opacity(0.15))
                    )
                    .onTapGesture { icon = symbol }
            }
        }
        .padding(.vertical, 4)
    }

    private var colorRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(HabitPalette.colors, id: \.self) { hex in
                let c = Color(hex: hex) ?? .green
                Circle()
                    .fill(c)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(.primary, lineWidth: color == hex ? 2.5 : 0)
                            .padding(2)
                    )
                    .onTapGesture { color = hex }
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        let details = trimmedDesc.isEmpty ? nil : trimmedDesc
        if let habit {
            vm.updateHabit(
                habit, name: trimmedName, details: details, icon: icon, color: color,
                targetCount: targetCount, period: period, allowsMultiplePerDay: allowsMultiplePerDay
            )
        } else {
            vm.createHabit(
                name: trimmedName, details: details, icon: icon, color: color,
                targetCount: targetCount, period: period, allowsMultiplePerDay: allowsMultiplePerDay
            )
        }
        dismiss()
    }
}
