import Foundation
import Combine

@MainActor
final class ActivityStore: ObservableObject {
    @Published var logs: [ActivityLog]
    @Published var settings: AppSettings
    @Published var selectedDate: Date
    @Published var upcomingEvents: [CalendarEventSnapshot]
    @Published var availableCalendars: [DeviceCalendarSnapshot]
    @Published var calendarPermissionState: CalendarPermissionState
    @Published var googleConnectionState: GoogleCalendarConnectionState
    @Published var draftLogEntry: DraftLogEntry?

    private let storage = UserDefaults.standard
    private let logsKey = "flotime.logs"
    private let settingsKey = "flotime.settings"
    private let scheduler = NotificationScheduler()
    private let calendarService = CalendarService()
    private let googleOAuthService = GoogleOAuthService()
    private lazy var googleCalendarService = GoogleCalendarService(oauthService: googleOAuthService)

    init() {
        self.logs = []
        self.settings = .default
        self.selectedDate = .now
        self.upcomingEvents = []
        self.availableCalendars = []
        self.calendarPermissionState = .unknown
        self.googleConnectionState = .disconnected
        self.draftLogEntry = nil
        load()
        self.googleConnectionState = googleOAuthService.hasStoredSession() ? .connected : .disconnected
    }

    func bootstrap() async {
        await googleOAuthService.restorePreviousSignInIfPossible()
        await refreshNotificationAuthorization()
        refreshGoogleConnectionState()
        if settings.calendarSyncEnabled {
            await refreshCalendarEvents()
        }
        await rescheduleNotifications()
    }

    func addLog(note: String, rating: Int, timestamp: Date = .now, source: ActivitySource = .manual, calendarEventID: String? = nil) {
        let entry = ActivityLog(timestamp: timestamp, note: note, rating: rating, source: source, calendarEventID: calendarEventID)
        logs.append(entry)
        normalizeLogs()
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

    func startEditing(_ log: ActivityLog) {
        draftLogEntry = DraftLogEntry(
            title: "Edit Activity",
            prompt: "Update the note, rating, or timestamp for this activity.",
            note: log.note,
            rating: log.rating,
            timestamp: log.timestamp,
            source: log.source,
            calendarEventID: log.calendarEventID,
            existingLogID: log.id
        )
    }

    func saveDraft(
        note: String,
        rating: Int,
        timestamp: Date,
        source: ActivitySource,
        calendarEventID: String?,
        existingLogID: UUID?
    ) {
        if let existingLogID {
            updateLog(
                id: existingLogID,
                note: note,
                rating: rating,
                timestamp: timestamp,
                source: source,
                calendarEventID: calendarEventID
            )
        } else {
            addLog(
                note: note,
                rating: rating,
                timestamp: timestamp,
                source: source,
                calendarEventID: calendarEventID
            )
        }
        draftLogEntry = nil
    }

    func deleteLog(_ log: ActivityLog) {
        deleteLog(id: log.id)
    }

    func deleteLog(id: UUID) {
        logs.removeAll { $0.id == id }
        save()
    }

    func dismissDraft() {
        draftLogEntry = nil
    }

    func logs(on date: Date) -> [ActivityLog] {
        let calendar = Calendar.current
        return logs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp > $1.timestamp }
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
            availableCalendars = []
            calendarPermissionState = .unknown
        }

        await rescheduleNotifications()
    }

    func connectGoogleCalendar() async {
        googleConnectionState = .connecting

        do {
            try await googleOAuthService.authorizeCalendarAccess()
            googleConnectionState = .connected
            if settings.calendarSyncEnabled {
                await refreshCalendarEvents()
            }
        } catch {
            googleConnectionState = .failed(error.localizedDescription)
        }
    }

    func googleConfigurationIssueMessage() -> String? {
        googleOAuthService.configurationIssue()?.localizedDescription
    }

    func disconnectGoogleCalendar() async {
        do {
            try await googleCalendarService.disconnect()
            googleConnectionState = .disconnected
            settings.selectedCalendarIdentifiers.removeAll(where: { $0.hasPrefix("google:") })
            settings.selectedEventPreferences.removeAll(where: { $0.eventIdentifier.hasPrefix("google-event:") })
            availableCalendars.removeAll(where: { $0.id.hasPrefix("google:") })
            upcomingEvents.removeAll(where: { $0.id.hasPrefix("google-event:") })
            save()
            await rescheduleNotifications()
        } catch {
            googleConnectionState = .failed(error.localizedDescription)
        }
    }

    func setCalendarSelection(_ calendarID: String, isSelected: Bool) async {
        if isSelected {
            if !settings.selectedCalendarIdentifiers.contains(calendarID) {
                settings.selectedCalendarIdentifiers.append(calendarID)
            }
        } else {
            settings.selectedCalendarIdentifiers.removeAll { $0 == calendarID }
        }

        save()

        if settings.calendarSyncEnabled {
            await refreshCalendarEvents()
        }
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
        var mergedCalendars: [DeviceCalendarSnapshot] = []
        var mergedEvents: [CalendarEventSnapshot] = []

        do {
            let granted = try await calendarService.requestAccessIfNeeded()
            calendarPermissionState = granted ? .authorized : .denied

            if granted {
                mergedCalendars.append(contentsOf: calendarService.availableCalendars())
            }
        } catch {
            calendarPermissionState = .denied
        }

        if googleOAuthService.hasStoredSession() {
            do {
                let googleCalendars = try await googleCalendarService.fetchCalendars()
                mergedCalendars.append(contentsOf: googleCalendars)
                googleConnectionState = .connected
            } catch {
                googleConnectionState = .failed(error.localizedDescription)
            }
        } else if !googleConnectionState.isConnected {
            googleConnectionState = .disconnected
        }

        availableCalendars = mergedCalendars
        reconcileSelectedCalendars(with: mergedCalendars)

        let start = Calendar.current.startOfDay(for: .now)
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }

        let selectedIDs = Set(settings.selectedCalendarIdentifiers)
        let deviceSelectedIDs = selectedIDs.filter { !$0.hasPrefix("google:") }
        let googleSelectedIDs = selectedIDs.filter { $0.hasPrefix("google:") }

        do {
            if !deviceSelectedIDs.isEmpty || calendarPermissionState == .authorized {
                let deviceEvents = try await calendarService.fetchEvents(
                    from: start,
                    to: end,
                    calendarIdentifiers: deviceSelectedIDs
                )
                mergedEvents.append(contentsOf: deviceEvents)
            }
        } catch {
            calendarPermissionState = .denied
        }

        if !googleSelectedIDs.isEmpty && googleConnectionState.isConnected {
            do {
                let googleEvents = try await googleCalendarService.fetchEvents(
                    calendarIdentifiers: googleSelectedIDs,
                    from: start,
                    to: end
                )
                mergedEvents.append(contentsOf: googleEvents)
            } catch {
                googleConnectionState = .failed(error.localizedDescription)
            }
        }

        upcomingEvents = mergedEvents.sorted { $0.startDate < $1.startDate }
        await rescheduleNotifications()
    }

    func refreshNotificationAuthorization() async {
        _ = await scheduler.requestAuthorizationIfNeeded()
    }

    func rescheduleNotifications() async {
        await scheduler.reschedulePrompts(settings: settings, events: upcomingEvents)
    }

    func isCalendarSelected(_ calendar: DeviceCalendarSnapshot) -> Bool {
        settings.selectedCalendarIdentifiers.contains(calendar.id)
    }

    func googleCalendars() -> [DeviceCalendarSnapshot] {
        availableCalendars.filter { $0.provider == .google }
    }

    func nonGoogleCalendars() -> [DeviceCalendarSnapshot] {
        availableCalendars.filter { $0.provider != .google }
    }

    func isRestDay(_ date: Date) -> Bool {
        settings.restDayIdentifiers.contains(dayIdentifier(for: date))
    }

    func toggleRestDay(on date: Date) async {
        let identifier = dayIdentifier(for: date)
        if settings.restDayIdentifiers.contains(identifier) {
            settings.restDayIdentifiers.removeAll { $0 == identifier }
        } else {
            settings.restDayIdentifiers.append(identifier)
        }
        settings.restDayIdentifiers.sort()
        save()
        await rescheduleNotifications()
    }

    func refreshGoogleConnectionState() {
        googleConnectionState = googleOAuthService.hasStoredSession() ? .connected : .disconnected
    }

    private func load() {
        if let data = storage.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([ActivityLog].self, from: data) {
            logs = shouldDiscardLegacySampleLogs(decoded) ? [] : decoded
        } else {
            logs = []
        }

        if let data = storage.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }

        normalizeLogs()
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

    private func updateLog(
        id: UUID,
        note: String,
        rating: Int,
        timestamp: Date,
        source: ActivitySource,
        calendarEventID: String?
    ) {
        guard let index = logs.firstIndex(where: { $0.id == id }) else { return }
        logs[index].note = note
        logs[index].rating = rating
        logs[index].timestamp = timestamp
        logs[index].source = source
        logs[index].calendarEventID = calendarEventID
        normalizeLogs()
        save()
    }

    private func normalizeLogs() {
        logs.sort { $0.timestamp > $1.timestamp }
    }

    private func shouldDiscardLegacySampleLogs(_ logs: [ActivityLog]) -> Bool {
        guard logs.count == ActivityStore.legacySampleNotes.count else { return false }
        let notes = Set(logs.map(\.note))
        return notes == ActivityStore.legacySampleNotes
    }

    private func reconcileSelectedCalendars(with calendars: [DeviceCalendarSnapshot]) {
        let availableIDs = Set(calendars.map(\.id))
        let filtered = settings.selectedCalendarIdentifiers.filter { availableIDs.contains($0) }

        if filtered.isEmpty && !calendars.isEmpty {
            settings.selectedCalendarIdentifiers = calendars.map(\.id)
            save()
        } else if filtered.count != settings.selectedCalendarIdentifiers.count {
            settings.selectedCalendarIdentifiers = filtered
            save()
        }
    }

    private func dayIdentifier(for date: Date) -> String {
        ActivityStore.dayFormatter.string(from: date)
    }
}

extension ActivityStore {
    static let legacySampleNotes: Set<String> = [
        "Planned the day and answered email.",
        "Deep work on a study project.",
        "Met with a class team and outlined next steps."
    ]

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct HourlyProductivityPoint: Identifiable {
    let hour: Int
    let averageRating: Double

    var id: Int { hour }
}
