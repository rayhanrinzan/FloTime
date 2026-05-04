import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ActivityStore

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
                        Text("\(minutes) minutes").tag(minutes)
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

                TextField("Google OAuth client ID", text: googleClientIDBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(FloTimeTheme.accent.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Redirect URI: \(GoogleOAuthService.redirectURI)")
                    .font(.caption2)
                    .foregroundStyle(FloTimeTheme.mutedText)
                    .textSelection(.enabled)

                Text(googleStatusText)
                    .font(.caption)
                    .foregroundStyle(FloTimeTheme.mutedText)

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.connectGoogleCalendar()
                        }
                    } label: {
                        Label(connectButtonLabel, systemImage: "globe")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FloTimeTheme.primary)
                    .disabled(store.settings.googleOAuthClientID.isEmpty || isConnectingGoogle)

                    if store.googleConnectionState.isConnected {
                        Button(role: .destructive) {
                            Task {
                                await store.disconnectGoogleCalendar()
                            }
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                                .font(.headline)
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
                    calendarSelectionSection(
                        title: "Google Calendars",
                        description: store.googleCalendars().isEmpty
                            ? "No Google calendars were returned for this connected account yet."
                            : "Choose which connected Google calendars FloTime should read.",
                        calendars: store.googleCalendars()
                    )

                    if !store.nonGoogleCalendars().isEmpty {
                        calendarSelectionSection(
                            title: "Apple / Other Calendars",
                            description: "Choose any other calendars FloTime should use for quiet-time detection and event logging.",
                            calendars: store.nonGoogleCalendars()
                        )
                    }
                }

                if store.upcomingEvents.isEmpty {
                    Text("Upcoming events from your selected calendars will appear here.")
                        .font(.caption)
                        .foregroundStyle(FloTimeTheme.mutedText)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Event Behavior")
                            .font(.headline)
                            .foregroundStyle(FloTimeTheme.text)

                        ForEach(store.upcomingEvents.prefix(6)) { event in
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
                }
            }
        }
        .floTimeCard()
    }

    private func calendarSelectionSection(
        title: String,
        description: String,
        calendars: [DeviceCalendarSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(FloTimeTheme.text)

            Text(description)
                .font(.caption)
                .foregroundStyle(FloTimeTheme.mutedText)

            if calendars.isEmpty {
                EmptyView()
            } else {
                ForEach(calendars) { calendar in
                    CalendarSelectionRow(
                        calendar: calendar,
                        isSelected: store.isCalendarSelected(calendar)
                    ) { isSelected in
                        Task {
                            await store.setCalendarSelection(calendar.id, isSelected: isSelected)
                        }
                    }
                }
            }
        }
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

    private var googleClientIDBinding: Binding<String> {
        Binding(
            get: { store.settings.googleOAuthClientID },
            set: { store.updateGoogleOAuthClientID($0) }
        )
    }

    private var googleStatusText: String {
        switch store.googleConnectionState {
        case .disconnected:
            return "Paste the Google OAuth client ID from your Google Cloud project that is configured for the redirect URI above, then connect. FloTime will open a secure Google sign-in page."
        case .connecting:
            return "Waiting for Google sign-in to finish..."
        case .connected:
            return "Google Calendar is connected. Direct Google calendars will appear in the selection list when calendar-aware reminders are enabled."
        case .failed(let message):
            return message
        }
    }

    private var connectButtonLabel: String {
        switch store.googleConnectionState {
        case .connected:
            return "Reconnect Google"
        case .connecting:
            return "Connecting..."
        case .disconnected, .failed:
            return "Connect Google"
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
        .padding(14)
        .background(FloTimeTheme.accent.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
