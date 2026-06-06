import SwiftUI

extension Color {
    /// Crea un Color da una stringa hex tipo "#34C759" o "34C759".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Palette di colori suggeriti per le abitudini (stile iOS).
enum HabitPalette {
    static let colors: [String] = [
        "#34C759", // green
        "#007AFF", // blue
        "#FF3B30", // red
        "#FF9500", // orange
        "#FFCC00", // yellow
        "#AF52DE", // purple
        "#FF2D55", // pink
        "#5AC8FA", // teal
        "#8E8E93"  // gray
    ]
}

/// SF Symbols suggeriti per le abitudini.
enum HabitIcons {
    static let symbols: [String] = [
        "star.fill", "drop.fill", "flame.fill", "heart.fill", "bolt.fill",
        "book.fill", "dumbbell.fill", "figure.run", "leaf.fill", "moon.fill",
        "cup.and.saucer.fill", "pencil", "music.note", "brain.head.profile",
        "pills.fill", "fork.knife", "bicycle", "sun.max.fill"
    ]
}
