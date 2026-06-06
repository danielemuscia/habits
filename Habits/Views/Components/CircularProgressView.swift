import SwiftUI

/// Anello di avanzamento stile Apple.
struct CircularProgressView: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var icon: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fraction)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: lineWidth * 1.8))
                    .foregroundStyle(color)
            }
        }
    }
}
