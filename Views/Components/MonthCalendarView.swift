import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date

    let logs: [ActivityLog]
    let isRestDay: (Date) -> Bool

    @State private var displayedMonth = Calendar.current.startOfDay(for: .now)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            header

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FloTimeTheme.mutedText)
                }

                ForEach(monthDates, id: \.self) { date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .onAppear {
            displayedMonth = Calendar.current.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        }
        .onChange(of: selectedDate) { _, updated in
            displayedMonth = Calendar.current.dateInterval(of: .month, for: updated)?.start ?? updated
        }
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(FloTimeTheme.primary)
            }

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(FloTimeTheme.primary)
            }
        }
    }

    private var monthDates: [Date?] {
        let calendar = Calendar.current
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else {
            return []
        }

        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: monthInterval.start) ?? 1..<2
        var cells = Array(repeating: Optional<Date>.none, count: leadingBlanks)

        for day in days {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(date)
            }
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return cells
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let average = averageRating(for: date)
        let isRestDay = isRestDay(date)

        Button {
            selectedDate = date
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor(isSelected: isSelected, average: average, isRestDay: isRestDay))

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : FloTimeTheme.text)
                    .fixedSize()
                    .padding(.leading, 8)
                    .padding(.top, 7)
            }
            .overlay(alignment: .topTrailing) {
                if isRestDay {
                    Image(systemName: "bed.double.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? .white : FloTimeTheme.primary)
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isRestDay {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.9) : FloTimeTheme.primary)
                        .frame(width: 7, height: 7)
                        .padding(.leading, 8)
                        .padding(.bottom, 7)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isRestDay && !isSelected ? FloTimeTheme.primary.opacity(0.55) : .clear, lineWidth: 1.5)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private func averageRating(for date: Date) -> Double {
        let dayLogs = logs.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        guard !dayLogs.isEmpty else { return 0 }
        return Double(dayLogs.map(\.rating).reduce(0, +)) / Double(dayLogs.count)
    }

    private func shiftMonth(by value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    private func backgroundColor(isSelected: Bool, average: Double, isRestDay: Bool) -> Color {
        if isSelected {
            return FloTimeTheme.primary
        }

        if isRestDay {
            return FloTimeTheme.accent.opacity(0.48)
        }

        return FloTimeTheme.primary.opacity(max(0.08, average / 15))
    }
}
