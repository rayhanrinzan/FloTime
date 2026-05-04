import Foundation

struct AppSettings: Codable, Hashable {
    var promptIntervalMinutes: Int
    var notificationsEnabled: Bool
    var quietWindows: [QuietWindow]
    var calendarSyncEnabled: Bool
    var deviceCalendarsEnabled: Bool
    var googleCalendarsEnabled: Bool
    var suppressDuringSelectedEvents: Bool
    var promptAfterSelectedEvents: Bool
    var selectedEventPreferences: [CalendarEventPreference]
    var selectedCalendarIdentifiers: [String]
    var restDayIdentifiers: [String]
    var hasInitializedCalendarSelections: Bool

    static let `default` = AppSettings(
        promptIntervalMinutes: 30,
        notificationsEnabled: true,
        quietWindows: [
            QuietWindow(name: "Sleep", startMinutes: 22 * 60, endMinutes: 7 * 60, isEnabled: true),
            QuietWindow(name: "Work / School", startMinutes: 9 * 60, endMinutes: 17 * 60, isEnabled: false)
        ],
        calendarSyncEnabled: false,
        deviceCalendarsEnabled: true,
        googleCalendarsEnabled: true,
        suppressDuringSelectedEvents: true,
        promptAfterSelectedEvents: true,
        selectedEventPreferences: [],
        selectedCalendarIdentifiers: [],
        restDayIdentifiers: [],
        hasInitializedCalendarSelections: false
    )

    enum CodingKeys: String, CodingKey {
        case promptIntervalMinutes
        case notificationsEnabled
        case quietWindows
        case calendarSyncEnabled
        case deviceCalendarsEnabled
        case googleCalendarsEnabled
        case suppressDuringSelectedEvents
        case promptAfterSelectedEvents
        case selectedEventPreferences
        case selectedCalendarIdentifiers
        case restDayIdentifiers
        case hasInitializedCalendarSelections
    }

    init(
        promptIntervalMinutes: Int,
        notificationsEnabled: Bool,
        quietWindows: [QuietWindow],
        calendarSyncEnabled: Bool,
        deviceCalendarsEnabled: Bool,
        googleCalendarsEnabled: Bool,
        suppressDuringSelectedEvents: Bool,
        promptAfterSelectedEvents: Bool,
        selectedEventPreferences: [CalendarEventPreference],
        selectedCalendarIdentifiers: [String],
        restDayIdentifiers: [String],
        hasInitializedCalendarSelections: Bool
    ) {
        self.promptIntervalMinutes = promptIntervalMinutes
        self.notificationsEnabled = notificationsEnabled
        self.quietWindows = quietWindows
        self.calendarSyncEnabled = calendarSyncEnabled
        self.deviceCalendarsEnabled = deviceCalendarsEnabled
        self.googleCalendarsEnabled = googleCalendarsEnabled
        self.suppressDuringSelectedEvents = suppressDuringSelectedEvents
        self.promptAfterSelectedEvents = promptAfterSelectedEvents
        self.selectedEventPreferences = selectedEventPreferences
        self.selectedCalendarIdentifiers = selectedCalendarIdentifiers
        self.restDayIdentifiers = restDayIdentifiers
        self.hasInitializedCalendarSelections = hasInitializedCalendarSelections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        promptIntervalMinutes = try container.decode(Int.self, forKey: .promptIntervalMinutes)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        quietWindows = try container.decode([QuietWindow].self, forKey: .quietWindows)
        calendarSyncEnabled = try container.decode(Bool.self, forKey: .calendarSyncEnabled)
        deviceCalendarsEnabled = try container.decodeIfPresent(Bool.self, forKey: .deviceCalendarsEnabled) ?? true
        googleCalendarsEnabled = try container.decodeIfPresent(Bool.self, forKey: .googleCalendarsEnabled) ?? true
        suppressDuringSelectedEvents = try container.decode(Bool.self, forKey: .suppressDuringSelectedEvents)
        promptAfterSelectedEvents = try container.decode(Bool.self, forKey: .promptAfterSelectedEvents)
        selectedEventPreferences = try container.decode([CalendarEventPreference].self, forKey: .selectedEventPreferences)
        selectedCalendarIdentifiers = try container.decodeIfPresent([String].self, forKey: .selectedCalendarIdentifiers) ?? []
        restDayIdentifiers = try container.decodeIfPresent([String].self, forKey: .restDayIdentifiers) ?? []
        hasInitializedCalendarSelections = try container.decodeIfPresent(Bool.self, forKey: .hasInitializedCalendarSelections)
            ?? !selectedCalendarIdentifiers.isEmpty
    }
}

struct QuietWindow: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var startMinutes: Int
    var endMinutes: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        startMinutes: Int,
        endMinutes: Int,
        isEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.isEnabled = isEnabled
    }
}
