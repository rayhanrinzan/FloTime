import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    @State private var isShowingGoogleAlert = false
    @State private var googleAlertMessage = ""
    @State private var isGoogleCalendarsExpanded = false
    @State private var isDeviceCalendarsExpanded = false
    @State private var isUpcomingEventsExpanded = false
    @State private var expandedEventCalendarIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                FloTimeTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        reminderCard
                        quietHoursCard
                        calendarCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Google Sign-In", isPresented: $isShowingGoogleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(googleAlertMessage)
            }
        }
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: notificationBinding) {
                Text("Enable Check-In Notifications")
                    .foregroundStyle(FloTimeTheme.text)
            }
            .tint(FloTimeTheme.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Interval")
                    .font(.headline)
                    .foregroundStyle(FloTimeTheme.text)

                Picker("Reminder Interval", selection: intervalBinding) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text(intervalOptionLabel(for: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .floTimeCard()
    }

    private var quietHoursCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quiet Windows")
                .font(.headline)
                .foregroundStyle(FloTimeTheme.text)

            ForEach(store.settings.quietWindows) { window in
                QuietWindowEditor(
                    window: window,
                    onChange: { updated in
                        Task {
                            await store.updateQuietWindow(updated)
                        }
                    }
                )
            }
        }
        .floTimeCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: calendarSyncBinding) {
                Text("Use Calendar-Aware Reminders")
                    .foregroundStyle(FloTimeTheme.text)
            }
            .tint(FloTimeTheme.primary)

            Text(calendarStatusText)
                .font(.caption)
                .foregroundStyle(FloTimeTheme.mutedText)

            VStack(alignment: .leading, spacing: 10) {
                Text("Google Calendar")
                    .font(.headline)
                    .foregroundStyle(FloTimeTheme.text)

                Text(googleStatusText)
                    .font(.caption)
                    .foregroundStyle(FloTimeTheme.mutedText)

                if let googleSetupIssue {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Google setup still needs one step", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)

                        Text(googleSetupIssue)
                            .font(.caption)
                            .foregroundStyle(FloTimeTheme.text)

                        Text("Fastest fix: add your Google iOS OAuth `GoogleService-Info.plist` file to the FloTime target, then make sure the reversed client ID is also listed under `CFBundleURLSchemes` in Info.plist.")
                            .font(.caption)
                            .foregroundStyle(FloTimeTheme.mutedText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.92))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.connectGoogleCalendar()
                            if case .failed(let message) = store.googleConnectionState {
                                presentGoogleAlert(message)
                            }
                        }
                    } label: {
                        Label(connectButtonLabel, systemImage: "globe")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FloTimeTheme.primary)
                    .disabled(isConnectingGoogle)

                    if store.googleConnectionState.isConnected {
                        Button(role: .destructive) {
                            Task {
                                await store.disconnectGoogleCalendar()
                            }
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(14)
            .background(FloTimeTheme.accent.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if store.settings.calendarSyncEnabled && hasAvailableCalendarSources {
                Toggle(isOn: suppressDuringEventBinding) {
                    Text("Mute During Selected Events")
                        .foregroundStyle(FloTimeTheme.text)
                }
                .tint(FloTimeTheme.primary)

                Toggle(isOn: promptAfterEventBinding) {
                    Text("Prompt to Log After Selected Events")
                        .foregroundStyle(FloTimeTheme.text)
                }
                .tint(FloTimeTheme.primary)

                if store.availableCalendars.isEmpty {
                    Text("No synced calendars were detected yet.")
                        .font(.caption)
                        .foregroundStyle(FloTimeTheme.mutedText)
                } else {
                    calendarProviderSection(
                        title: "Google Calendars",
                        description: store.googleCalendars().isEmpty
                            ? "No Google calendars were returned for this connected account yet."
                            : "Turn Google calendars on or off as a group, then expand to fine-tune individual calendars.",
                        isEnabled: googleCalendarsEnabledBinding,
                        isExpanded: $isGoogleCalendarsExpanded,
                        calendars: store.googleCalendars()
                    )

                    calendarProviderSection(
                        title: "Apple / Device Calendars",
                        description: "Turn Apple and other device-synced calendars on or off as a group, then expand to fine-tune individual calendars.",
                        isEnabled: deviceCalendarsEnabledBinding,
                        isExpanded: $isDeviceCalendarsExpanded,
                        calendars: store.deviceCalendars()
                    )
                }

                if store.upcomingEvents.isEmpty {
                    Text("Upcoming events from your selected calendars will appear here.")
                        .font(.caption)
                        .foregroundStyle(FloTimeTheme.mutedText)
                } else {
                    upcomingEventsSection
                }
            }
        }
        .floTimeCard()
    }

    private var upcomingEventsSection: some View {
        DisclosureGroup(isExpanded: $isUpcomingEventsExpanded) {
            VStack(spacing: 12) {
                ForEach(groupedUpcomingEvents) { group in
                    DisclosureGroup(
                        isExpanded: bindingForExpandedEventCalendar(group.id)
                    ) {
                        VStack(spacing: 10) {
                            ForEach(group.events) { event in
                                EventPreferenceRow(
                                    event: event,
                                    preference: store.preference(for: event),
                                    onChange: { muteDuringEvent, promptToLogAfter in
                                        Task {
                                            await store.updateEventPreference(
                                                for: event,
                                                muteDuringEvent: muteDuringEvent,
                                                promptToLogAfter: promptToLogAfter
                                            )
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FloTimeTheme.text)
                                Text(group.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(FloTimeTheme.mutedText)
                            }
                            Spacer()
                            Text("\(group.events.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FloTimeTheme.mutedText)
                        }
                    }
                    .tint(FloTimeTheme.primary)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Choose Event Behavior")
                    .font(.headline)
                    .foregroundStyle(FloTimeTheme.text)
                Spacer()
                Text("\(store.upcomingEvents.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FloTimeTheme.mutedText)
            }
        }
        .tint(FloTimeTheme.primary)
    }

    private func calendarProviderSection(
        title: String,
        description: String,
        isEnabled: Binding<Bool>,
        isExpanded: Binding<Bool>,
        calendars: [DeviceCalendarSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isEnabled) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(FloTimeTheme.text)
            }
            .tint(FloTimeTheme.primary)

            Text(description)
                .font(.caption)
                .foregroundStyle(FloTimeTheme.mutedText)

            if !calendars.isEmpty {
                DisclosureGroup(isExpanded: isExpanded) {
                    VStack(spacing: 10) {
                        ForEach(calendars) { calendar in
                            CalendarSelectionRow(
                                calendar: calendar,
                                isSelected: store.isCalendarSelected(calendar),
                                isEnabled: isEnabled.wrappedValue
                            ) { isSelected in
                                Task {
                                    await store.setCalendarSelection(calendar.id, isSelected: isSelected)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text("\(calendars.count) calendars")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FloTimeTheme.text)
                        Spacer()
                    }
                }
                .tint(FloTimeTheme.primary)
            }
        }
        .padding(14)
        .background(FloTimeTheme.accent.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { store.settings.notificationsEnabled },
            set: { value in
                Task {
                    await store.setNotificationsEnabled(value)
                }
            }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { store.settings.promptIntervalMinutes },
            set: { value in
                Task {
                    await store.updateInterval(to: value)
                }
            }
        )
    }

    private var calendarSyncBinding: Binding<Bool> {
        Binding(
            get: { store.settings.calendarSyncEnabled },
            set: { value in
                Task {
                    await store.setCalendarSyncEnabled(value)
                }
            }
        )
    }

    private var deviceCalendarsEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.deviceCalendarsEnabled },
            set: { value in
                Task {
                    await store.setDeviceCalendarsEnabled(value)
                }
            }
        )
    }

    private var googleCalendarsEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.googleCalendarsEnabled },
            set: { value in
                Task {
                    await store.setGoogleCalendarsEnabled(value)
                }
            }
        )
    }

    private var suppressDuringEventBinding: Binding<Bool> {
        Binding(
            get: { store.settings.suppressDuringSelectedEvents },
            set: { value in
                Task {
                    await store.setSuppressDuringSelectedEvents(value)
                }
            }
        )
    }

    private var promptAfterEventBinding: Binding<Bool> {
        Binding(
            get: { store.settings.promptAfterSelectedEvents },
            set: { value in
                Task {
                    await store.setPromptAfterSelectedEvents(value)
                }
            }
        )
    }

    private var calendarStatusText: String {
        if !store.settings.calendarSyncEnabled {
            return "Turn this on if you want FloTime to mute reminders during events and ask whether to log them after they end."
        }

        switch store.calendarPermissionState {
        case .unknown:
            return "FloTime can use Apple calendars already on your iPhone, plus a direct Google Calendar login if you connect one below."
        case .authorized:
            return "Apple calendar access is on. You can also connect Google directly below."
        case .denied:
            return "Apple calendar access is unavailable right now, but the Google connection below can still be used."
        }
    }

    private var googleStatusText: String {
        switch store.googleConnectionState {
        case .disconnected:
            return "Tap the button below to sign in with Google and connect your calendar."
        case .connecting:
            return "Opening Google sign-in..."
        case .connected:
            return "Google Calendar is connected. Your Google calendars will appear below when calendar-aware reminders are enabled."
        case .failed(let message):
            return message
        }
    }

    private var googleSetupIssue: String? {
        guard !store.googleConnectionState.isConnected else { return nil }
        return store.googleConfigurationIssueMessage()
    }

    private var connectButtonLabel: String {
        switch store.googleConnectionState {
        case .connected:
            return "Reconnect"
        case .connecting:
            return "Connecting..."
        case .disconnected, .failed:
            return "Sign in with Google"
        }
    }

    private var isConnectingGoogle: Bool {
        if case .connecting = store.googleConnectionState {
            return true
        }
        return false
    }

    private var hasAvailableCalendarSources: Bool {
        store.calendarPermissionState == .authorized || store.googleConnectionState.isConnected || !store.availableCalendars.isEmpty
    }

    private var groupedUpcomingEvents: [EventCalendarGroup] {
        let grouped = Dictionary(grouping: store.upcomingEvents, by: \.calendarIdentifier)
        return grouped.values
            .compactMap { events in
                guard let first = events.first else { return nil }
                return EventCalendarGroup(
                    id: first.calendarIdentifier,
                    title: first.calendarTitle,
                    subtitle: "\(first.provider.displayName) • \(first.sourceTitle)",
                    events: events.sorted { $0.startDate < $1.startDate }
                )
            }
            .sorted {
                if $0.title == $1.title {
                    return $0.subtitle < $1.subtitle
                }
                return $0.title < $1.title
            }
    }

    private func presentGoogleAlert(_ message: String) {
        googleAlertMessage = message
        isShowingGoogleAlert = true
    }

    private func bindingForExpandedEventCalendar(_ calendarID: String) -> Binding<Bool> {
        Binding(
            get: { expandedEventCalendarIDs.contains(calendarID) },
            set: { isExpanded in
                if isExpanded {
                    expandedEventCalendarIDs.insert(calendarID)
                } else {
                    expandedEventCalendarIDs.remove(calendarID)
                }
            }
        )
    }

    private func intervalOptionLabel(for minutes: Int) -> String {
        switch minutes {
        case 60:
            return "1h"
        case 120:
            return "2h"
        default:
            return "\(minutes)m"
        }
    }
}

private struct EventCalendarGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let events: [CalendarEventSnapshot]
}

struct QuietWindowEditor: View {
    @State private var draft: QuietWindow
    let onChange: (QuietWindow) -> Void

    init(window: QuietWindow, onChange: @escaping (QuietWindow) -> Void) {
        _draft = State(initialValue: window)
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(draft.name, isOn: $draft.isEnabled)
                .tint(FloTimeTheme.primary)

            HStack {
                DatePicker(
                    "Start",
                    selection: startBinding,
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "End",
                    selection: endBinding,
                    displayedComponents: .hourAndMinute
                )
            }
            .datePickerStyle(.compact)
        }
        .padding(14)
        .background(FloTimeTheme.accent.opacity(0.26))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: draft) { _, updated in
            onChange(updated)
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { date(from: draft.startMinutes) },
            set: { draft.startMinutes = minutes(from: $0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { date(from: draft.endMinutes) },
            set: { draft.endMinutes = minutes(from: $0) }
        )
    }

    private func date(from minutes: Int) -> Date {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
    }

    private func minutes(from date: Date) -> Int {
        let calendar = Calendar.current
        return (calendar.component(.hour, from: date) * 60) + calendar.component(.minute, from: date)
    }
}

struct EventPreferenceRow: View {
    let event: CalendarEventSnapshot
    @State private var muteDuringEvent: Bool
    @State private var promptToLogAfter: Bool
    let onChange: (Bool, Bool) -> Void

    init(
        event: CalendarEventSnapshot,
        preference: CalendarEventPreference,
        onChange: @escaping (Bool, Bool) -> Void
    ) {
        self.event = event
        _muteDuringEvent = State(initialValue: preference.muteDuringEvent)
        _promptToLogAfter = State(initialValue: preference.promptToLogAfter)
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(FloTimeTheme.text)

                    Text("\(event.provider.displayName) • \(event.calendarTitle)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FloTimeTheme.mutedText)
                }

                Spacer()
            }

            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(FloTimeTheme.mutedText)

            Toggle("Do not disturb during this event", isOn: $muteDuringEvent)
                .tint(FloTimeTheme.primary)
            Toggle("Ask to log after it ends", isOn: $promptToLogAfter)
                .tint(FloTimeTheme.primary)
        }
        .padding(14)
        .background(FloTimeTheme.accent.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: muteDuringEvent) { _, updated in
            onChange(updated, promptToLogAfter)
        }
        .onChange(of: promptToLogAfter) { _, updated in
            onChange(muteDuringEvent, updated)
        }
    }
}

struct CalendarSelectionRow: View {
    let calendar: DeviceCalendarSnapshot
    let isSelected: Bool
    let isEnabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isSelected }, set: onChange)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(calendar.title)
                    .foregroundStyle(FloTimeTheme.text)
                Text(calendar.sourceTitle)
                    .font(.caption)
                    .foregroundStyle(FloTimeTheme.mutedText)
            }
        }
        .tint(FloTimeTheme.primary)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .padding(14)
        .background(FloTimeTheme.accent.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
