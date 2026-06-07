import WidgetKit
import SwiftUI
import AppIntents
import HabitsKit

/// Vista radice del widget: gestisce vuoto, cap per famiglia e apertura app.
struct DotsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitsTimelineEntry

    var body: some View {
        Group {
            if entry.dots.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal").font(.title2)
                    Text("Nessuna abitudine").font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let cap = Self.cap(for: family)
                let visible = Array(entry.dots.prefix(cap))
                let overflow = entry.dots.count - visible.count
                DotsGridView(dots: visible, overflow: overflow, family: family)
            }
        }
        // Tap fuori dai cerchi → apre l'app (interazione ibrida).
        .widgetURL(URL(string: "habits://today"))
    }

    /// Numero massimo di cerchi per famiglia, oltre cui l'interazione si fa scomoda.
    static func cap(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 12
        case .systemLarge: return 16
        default: return 6
        }
    }
}

/// Griglia adattiva di cerchi: il numero di colonne dipende da quanti elementi
/// ci sono e dalla famiglia; il diametro si adatta allo spazio disponibile.
struct DotsGridView: View {
    let dots: [HabitDot]
    let overflow: Int
    let family: WidgetFamily

    private var itemCount: Int { dots.count + (overflow > 0 ? 1 : 0) }

    private var columns: Int {
        let n = itemCount
        switch family {
        case .systemSmall:
            return n <= 1 ? 1 : 2
        case .systemMedium:
            if n <= 4 { return max(1, n) }   // riga unica per pochi
            if n <= 8 { return 4 }
            return 6
        case .systemLarge:
            if n <= 4 { return 2 }
            if n <= 9 { return 3 }
            return 4
        default:
            return 2
        }
    }

    var body: some View {
        let cols = max(1, columns)
        let rows = max(1, Int(ceil(Double(itemCount) / Double(cols))))
        let gap: CGFloat = 8

        GeometryReader { geo in
            let diameter = circleDiameter(in: geo.size, cols: cols, rows: rows, gap: gap)
            let layout = Array(repeating: GridItem(.flexible(), spacing: gap), count: cols)
            LazyVGrid(columns: layout, spacing: gap) {
                ForEach(dots) { dot in
                    HabitDotButton(dot: dot, size: diameter)
                }
                if overflow > 0 {
                    OverflowDot(count: overflow, size: diameter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func circleDiameter(in size: CGSize, cols: Int, rows: Int, gap: CGFloat) -> CGFloat {
        let w = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let h = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        return max(28, min(w, h))
    }
}

/// Singolo cerchio interattivo: tap = log immediato via App Intent.
struct HabitDotButton: View {
    let dot: HabitDot
    let size: CGFloat

    private var color: Color { Color(hex: dot.colorHex) ?? .green }

    var body: some View {
        Button(intent: LogHabitIntent(habitId: dot.id)) {
            ZStack {
                if dot.isRest {
                    Circle().fill(Color(.systemGray5))
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(.secondary)
                } else if dot.isComplete {
                    Circle().fill(color)
                    icon.foregroundStyle(.white)
                } else {
                    Circle().stroke(Color(.systemGray3), lineWidth: max(2, size * 0.05))
                    if dot.fraction > 0 {
                        Circle()
                            .trim(from: 0, to: dot.fraction)
                            .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.07), lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(max(1, size * 0.025))
                    }
                    icon.foregroundStyle(color)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private var icon: some View {
        Image(systemName: dot.icon)
            .font(.system(size: size * 0.4, weight: .semibold))
    }
}

/// Cerchio "+N" per le abitudini oltre il cap: tap → apre l'app (via widgetURL).
struct OverflowDot: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            Text("+\(count)")
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
    }
}
