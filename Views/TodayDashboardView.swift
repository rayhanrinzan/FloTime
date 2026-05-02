import SwiftUI

struct TodayDashboardView: View {
    let store: ActivityStore
    let onAddLog: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    chartCard
                    latestLogsCard
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [FloTimeTheme.background, FloTimeTheme.accent.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Today")
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
            Text("Latest Check-Ins")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FloTimeTheme.text)

            ForEach(store.logs(on: .now).reversed()) { log in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
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

            if store.logs(on: .now).isEmpty {
                emptyState("No entries yet for today.")
            }
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

    private var averageText: String {
        let average = store.averageRating(on: .now)
        return average == 0 ? "--" : String(format: "%.1f / 10", average)
    }
}
