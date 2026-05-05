import SwiftUI

struct CalendarOverviewView: View {
    @ObservedObject var store: ActivityStore
    @State private var logPendingDeletion: ActivityLog?

    var body: some View {
        NavigationStack {
            ZStack {
                FloTimeTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        MonthCalendarView(
                            selectedDate: bindableDate,
                            logs: store.logs,
                            isRestDay: { store.isRestDay($0) }
                        )
                            .floTimeCard()

                        selectedDayCard
                    }
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete this activity?",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let logPendingDeletion else { return }
                    store.deleteLog(logPendingDeletion)
                    self.logPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    logPendingDeletion = nil
                }
            } message: {
                if let logPendingDeletion {
                    Text(logPendingDeletion.note)
                }
            }
        }
    }

    private var selectedDayCard: some View {
        let dayLogs = store.logs(on: store.selectedDate)

        return VStack(alignment: .leading, spacing: 14) {
            Text(store.selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            if store.isRestDay(store.selectedDate) {
                Label("Rest day", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(FloTimeTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FloTimeTheme.accent.opacity(0.42))
                    .clipShape(Capsule())

                Text("FloTime treats this date as a rest day, so productivity reminders stay paused.")
                    .foregroundStyle(FloTimeTheme.mutedText)
            }

            if dayLogs.isEmpty {
                Text(
                    store.isRestDay(store.selectedDate)
                        ? "No entries were logged for this rest day."
                        : "No productivity entries for this day yet."
                )
                    .foregroundStyle(FloTimeTheme.mutedText)
                    .padding(.vertical, 18)
            } else {
                DailyProductivityChartView(points: store.hourlyTrend(on: store.selectedDate))

                ForEach(dayLogs) { log in
                    logRow(log)
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

    private func logRow(_ log: ActivityLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.note)
                    .foregroundStyle(FloTimeTheme.text)
                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(FloTimeTheme.mutedText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                RatingBadge(rating: log.rating)
                Menu {
                    Button("Edit Activity", systemImage: "pencil") {
                        store.startEditing(log)
                    }
                    Button("Delete Activity", systemImage: "trash", role: .destructive) {
                        logPendingDeletion = log
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(FloTimeTheme.mutedText)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            store.startEditing(log)
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { logPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    logPendingDeletion = nil
                }
            }
        )
    }
}
