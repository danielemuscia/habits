import SwiftUI

/// Anello di avanzamento stile Apple Activity, condiviso tra app e widget.
///
/// `fraction` è il rapporto **non cappato** (currentCount/target): fino a 1
/// riempie l'anello; oltre 1 disegna un **secondo giro dello stesso colore**
/// sollevato sopra il primo, con un'ombra direzionale (luce dall'alto) che gli
/// dà profondità — così l'overperformance resta leggibile invece di fermarsi.
public struct HabitRingView: View {
    private let fraction: Double
    private let color: Color
    private let lineWidth: CGFloat
    private let icon: String?
    private let animated: Bool

    public init(
        fraction: Double,
        color: Color,
        lineWidth: CGFloat = 6,
        icon: String? = nil,
        animated: Bool = true
    ) {
        self.fraction = max(0, fraction)
        self.color = color
        self.lineWidth = lineWidth
        self.icon = icon
        self.animated = animated
    }

    public var body: some View {
        let base = min(1, fraction)
        let overflow = max(0, min(1, fraction - 1)) // un solo giro extra mostrato

        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            ZStack {
                // Traccia di sfondo.
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: lineWidth)

                // Anello base: 0 → 100%.
                Circle()
                    .trim(from: 0, to: max(0.001, base))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Secondo giro (overperformance): stesso colore, sollevato sopra
                // il primo con ombra direzionale → effetto a strati di Apple.
                if overflow > 0 {
                    Circle()
                        .trim(from: 0, to: overflow)
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .black.opacity(0.35),
                                radius: lineWidth * 0.35,
                                x: 0, y: lineWidth * 0.28)
                }

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: dim * 0.34, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(animated ? .spring(response: 0.4, dampingFraction: 0.8) : nil, value: fraction)
        }
    }
}
