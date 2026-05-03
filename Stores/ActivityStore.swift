import Foundation
import Combine

@MainActor
final class ActivityStore: ObservableObject {
    @Published var logs: [ActivityLog]
    @Published var settings: AppSettings
    @Published var selectedDate: Date
    @Published var upcomingEvents: [CalendarEventSnapshot]
    @Published var calendarPermissionState: CalendarPermissionState
    @Published var draftLogEntry: DraftLogEntry?

    private let storage = UserDefaults.standard
    private let logsKey = "flotime.logs"
    private let settingsKey = "flotime.settings"
    private let scheduler = NotificationScheduler()
    private let calendarService = CalendarService()

    init() {
        self.logs = []
        self.settings = .default
        self.selectedDate = .now
        self.upcomingEvents = []
        self.calendarPermissionState = .unknown
        self.draftLogEntry = nil
        load()
    }

    func bootstrap() async {
        await refreshNotificationAuthorization()
        if settings.calendarSyncEnabled {
            await refreshCalendarEvents()
        }
        await rescheduleNotifications()
    }

    func addLog(note: String, rating: Int, timestamp: Date = .now, source: ActivitySource = .manual, calendarEventID: String? = nil) {
        let entry = ActivityLog(timestamp: timestamp, note: note, rating: rating, source: source, calendarEventID: calendarEventID)
        logs.insert(entry, at: 0)
        save()
    }

    func startManualLog() {
        draftLogEntry = DraftLogEntry(
            title: "New Activity",
            prompt: "What have you been up to?",
            note: "",
            rating: 7,
            timestamp: .now,
            source: .manual
        )
    }

    func startCheckInPrompt(intervalMinutes: Int) {
        draftLogEntry = DraftLogEntry(
            title: "Check-In",
            prompt: "What have you been up to in the last \(intervalDescription(minutes: intervalMinutes))?",
            note: "",
            rating: 7,
            timestamp: .now,
            source: .manual
        )
    }

    func startEventLog(eventID: String, eventTitle: String, endDate: Date) {
        draftLogEntry = DraftLogEntry(
            title: "Log Calendar Event",
            prompt: "Would you like to log \"\(eventTitle)\" as an activity?",
            note: eventTitle,
            rating: 7,
            timestamp: endDate,
            source: .calendarEvent,
            calendarEventID: eventID
        )
    }

    func saveDraft(
        note: String,
        rating: Int,
        timestamp: Date,
        source: ActivitySource,
        calendarEventID: String?
    ) {
        addLog(
            note: note,
            rating: rating,
            timestamp: timestamp,
            source: source,
            calendarEventID: calendarEventID
        )
        draftLogEntry = nil
    }

    func dismissDraft() {
        draftLogEntry = nil
    }

    func logs(on date: Date) -> [ActivityLog] {
        let calendar = Calendar.current
        return logs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func averageRating(on date: Date) -> Double {
        let items = logs(on: date)
        guard !items.isEmpty else { return 0 }
        return Double(items.map(\.rating).reduce(0, +)) / Double(items.count)
    }

    func hourlyTrend(on date: Date) -> [HourlyProductivityPoint] {
        let dayLogs = logs(on: date)
        let calendar = Calendar.current

        return (0..<24).compactMap { hour in
            let matching = dayLogs.filter {
                calendar.component(.hour, from: $0.timestamp) == hour
            }

            guard !matching.isEmpty else { return nil }
            let average = Double(matching.map(\.rating).reduce(0, +)) / Double(matching.count)
            return HourlyProductivityPoint(hour: hour, averageRating: average)
        }
    }

    func updateInterval(to minutes: Int) async {
        settings.promptIntervalMinutes = minutes
        save()
        await rescheduleNotifications()
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        settings.notificationsEnabled = isEnabled
        save()
        await rescheduleNotifications()
    }

    func updateQuietWindow(_ window: QuietWindow) async {
        guard let index = settings.quietWindows.firstIndex(where: { $0.id == window.id }) else { return }
        settings.quietWindows[index] = window
        save()
        await rescheduleNotifications()
    }

    func setCalendarSyncEnabled(_ isEnabled: Bool) async {
        settings.calendarSyncEnabled = isEnabled
        save()

        if isEnabled {
            await refreshCalendarEvents()
        } else {
            upcomingEvents = []
            calendarPermissionState = .unknown
        }

        await rescheduleNotifications()
    }

    func setSuppressDuringSelectedEvents(_ isEnabled: Bool) async {
        settings.suppressDuringSelectedEvents = isEnabled
        save()
        await rescheduleNotifications()
    }

    func setPromptAfterSelectedEvents(_ isEnabled: Bool) async {
        settings.promptAfterSelectedEvents = isEnabled
        save()
        await rescheduleNotifications()
    }

    func updateEventPreference(for event: CalendarEventSnapshot, muteDuringEvent: Bool, promptToLogAfter: Bool) async {
        let preference = CalendarEventPreference(
            eventIdentifier: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            muteDuringEvent: muteDuringEvent,
            promptToLogAfter: promptToLogAfter
        )

        if let index = settings.selectedEventPreferences.firstIndex(where: { $0.eventIdentifier == event.id }) {
            settings.selectedEventPreferences[index] = preference
        } else {
            settings.selectedEventPreferences.append(preference)
        }

        save()
        await rescheduleNotifications()
    }

    func preference(for event: CalendarEventSnapshot) -> CalendarEventPreference {
        settings.selectedEventPreferences.first(where: { $0.eventIdentifier == event.id }) ??
            CalendarEventPreference(
                eventIdentifier: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                muteDuringEvent: true,
                promptToLogAfter: true
            )
    }

    func refreshCalendarEvents() async {
        do {
            let granted = try await calendarService.requestAccessIfNeeded()
            calendarPermissionState = granted ? .authorized : .denied

            guard granted else {
                upcomingEvents = []
                return
            }

            let start = Calendar.current.startOfDay(for: .now)
            guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }
            upcomingEvents = try await calendarService.fetchEvents(from: start, to: end)
            await rescheduleNotifications()
        } catch {
            calendarPermissionState = .denied
        }
    }

    func refreshNotificationAuthorization() async {
        _ = await scheduler.requestAuthorizationIfNeeded()
    }

    func rescheduleNotifications() async {
        await scheduler.reschedulePrompts(settings: settings, events: upcomingEvents)
    }

    private func load() {
        if let data = storage.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([ActivityLog].self, from: data) {
            logs = decoded
        } else {
            logs = ActivityStore.sampleLogs
        }

        if let data = storage.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            storage.set(data, forKey: logsKey)
        }

        if let data = try? JSONEncoder().encode(settings) {
            storage.set(data, forKey: settingsKey)
        }
    }

    private func intervalDescription(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        }

        let hours = Double(minutes) / 60.0
        if hours.rounded() == hours {
            return "\(Int(hours)) hour" + (hours == 1 ? "" : "s")
        }

        return String(format: "%.1f hours", hours)
    }
}

extension ActivityStore {
    static let sampleLogs: [ActivityLog] = [
        ActivityLog(timestamp: Calendar.current.date(byAdding: .hour, value: -8, to: .now) ?? .now, note: "Planned the day and answered email.", rating: 6),
        ActivityLog(timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now, note: "Deep work on a study project.", rating: 9),
        ActivityLog(timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now, note: "Met with a class team and outlined next steps.", rating: 7)
    ]
}

struct HourlyProductivityPoint: Identifiable {
    let hour: Int
    let averageRating: Double

    var id: Int { hour }
}
