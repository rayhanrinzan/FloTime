import SwiftUI

struct TodayDashboardView: View {
    @ObservedObject var store: ActivityStore
    let onAddLog: () -> Void
    @State private var logPendingDeletion: ActivityLog?
    @State private var isLatestLogsExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [FloTimeTheme.background, FloTimeTheme.accent.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        chartCard
                        latestLogsCard
                        restDayCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Today")
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Build a clearer picture of your day.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(FloTimeTheme.text)

            Text("FloTime checks in on your time, captures a quick rating, and turns the day into a visual story.")
                .foregroundStyle(FloTimeTheme.mutedText)

            HStack(spacing: 12) {
                metric(title: "Interval", value: "\(store.settings.promptIntervalMinutes) min")
                metric(title: "Today Avg", value: averageText)
                metric(title: "Entries", value: "\(store.logs(on: .now).count)")
            }

            Button(action: onAddLog) {
                Label("Log Activity", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FloTimeTheme.primary)
        }
        .floTimeCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's Productivity")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            if store.hourlyTrend(on: .now).isEmpty {
                emptyState("Once you add a few check-ins, your productivity trend will appear here.")
            } else {
                DailyProductivityChartView(points: store.hourlyTrend(on: .now))
            }
        }
        .floTimeCard()
    }

    private var latestLogsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if todayLogs.isEmpty {
                Text("Latest Check-Ins")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FloTimeTheme.text)

                emptyState("No recent check-ins.")
            } else {
                DisclosureGroup(isExpanded: $isLatestLogsExpanded) {
                    VStack(spacing: 0) {
                        ForEach(todayLogs) { log in
                            logRow(log)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text("Latest Check-Ins")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(FloTimeTheme.text)
                        Spacer()
                        Text("\(todayLogs.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FloTimeTheme.mutedText)
                    }
                }
                .tint(FloTimeTheme.primary)
            }
        }
        .floTimeCard()
    }

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isRestDayToday ? "Rest day is on." : "Need a lighter day?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            Text(
                isRestDayToday
                    ? "FloTime will pause check-ins and event follow-ups for the rest of today."
                    : "Mark today as a rest day when you need a break. FloTime will pause productivity reminders until tomorrow."
            )
            .foregroundStyle(FloTimeTheme.mutedText)

            Button {
                Task {
                    await store.toggleRestDay(on: .now)
                }
            } label: {
                Label(
                    isRestDayToday ? "End Rest Day" : "Take a Rest Day",
                    systemImage: isRestDayToday ? "sun.max" : "bed.double.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(FloTimeTheme.primary)
        }
        .floTimeCard()
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(FloTimeTheme.mutedText)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FloTimeTheme.accent.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(FloTimeTheme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
    }

    private func logRow(_ log: ActivityLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
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

    private var averageText: String {
        let average = store.averageRating(on: .now)
        return average == 0 ? "--" : String(format: "%.1f / 10", average)
    }

    private var todayLogs: [ActivityLog] {
        store.logs(on: .now)
    }

    private var isRestDayToday: Bool {
        store.isRestDay(.now)
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
