import SwiftUI
import UIKit

/// Striscia orizzontale degli ultimi giorni, per selezionare la data della vista Today.
struct DateStripView: View {
    @Binding var selected: Date
    /// Cambia valore ogni volta che si tocca "Oggi": solo allora la striscia scrolla.
    /// Selezionare un giorno qui dentro non muove invece lo scroll.
    var scrollToTodayToken: Int

    private let calendar = Calendar.current
    private let days = 14

    private var dates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dates, id: \.self) { date in
                        dayCell(date)
                            .id(date)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(calendar.startOfDay(for: selected), anchor: .trailing)
            }
            .onChange(of: scrollToTodayToken) { _, _ in
                withAnimation {
                    proxy.scrollTo(calendar.startOfDay(for: Date()), anchor: .trailing)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selected)
        return Button {
            selected = date
        } label: {
            VStack(spacing: 4) {
                Text(weekday(date))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(dayNumber(date))
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(width: 44, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}
