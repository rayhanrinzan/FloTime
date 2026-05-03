import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ActivityStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    reminderCard
                    quietHoursCard
                    calendarCard
                }
                .padding(20)
            }
            .background(FloTimeTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
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
                Text("Use Device Calendar")
                    .foregroundStyle(FloTimeTheme.text)
            }
            .tint(FloTimeTheme.primary)

            Text(calendarStatusText)
                .font(.caption)
                .foregroundStyle(FloTimeTheme.mutedText)

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

            if store.upcomingEvents.isEmpty {
                Text("Upcoming events will appear here after calendar access is granted.")
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
        .floTimeCard()
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
        switch store.calendarPermissionState {
        case .unknown:
            return "FloTime can read synced Apple or Google calendar events on your device."
        case .authorized:
            return "Calendar connected. Select events that should pause reminders or trigger follow-up prompts."
        case .denied:
            return "Calendar access is unavailable. You can re-enable it later in iPhone Settings."
        }
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
            Text(event.title)
                .font(.headline)
                .foregroundStyle(FloTimeTheme.text)

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
