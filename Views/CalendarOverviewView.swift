import SwiftUI

struct CalendarOverviewView: View {
    let store: ActivityStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MonthCalendarView(selectedDate: bindableDate, logs: store.logs)
                        .floTimeCard()

                    selectedDayCard
                }
                .padding(20)
            }
            .background(FloTimeTheme.background.ignoresSafeArea())
            .navigationTitle("Calendar")
        }
    }

    private var selectedDayCard: some View {
        let dayLogs = store.logs(on: store.selectedDate)

        return VStack(alignment: .leading, spacing: 14) {
            Text(store.selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            if dayLogs.isEmpty {
                Text("No productivity entries for this day yet.")
                    .foregroundStyle(FloTimeTheme.mutedText)
                    .padding(.vertical, 18)
            } else {
                DailyProductivityChartView(points: store.hourlyTrend(on: store.selectedDate))

                ForEach(dayLogs.reversed()) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.note)
                                .foregroundStyle(FloTimeTheme.text)
                            Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(FloTimeTheme.mutedText)
                        }

                        Spacer()
                        RatingBadge(rating: log.rating)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .floTimeCard()
    }

    private var bindableDate: Binding<Date> {
        Binding(
            get: { store.selectedDate },
            set: { store.selectedDate = $0 }
        )
    }
}
