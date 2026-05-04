import Foundation

struct AppSettings: Codable, Hashable {
    var promptIntervalMinutes: Int
    var notificationsEnabled: Bool
    var quietWindows: [QuietWindow]
    var calendarSyncEnabled: Bool
    var suppressDuringSelectedEvents: Bool
    var promptAfterSelectedEvents: Bool
    var selectedEventPreferences: [CalendarEventPreference]
    var selectedCalendarIdentifiers: [String]
    var restDayIdentifiers: [String]

    static let `default` = AppSettings(
        promptIntervalMinutes: 30,
        notificationsEnabled: true,
        quietWindows: [
            QuietWindow(name: "Sleep", startMinutes: 22 * 60, endMinutes: 7 * 60, isEnabled: true),
            QuietWindow(name: "Work / School", startMinutes: 9 * 60, endMinutes: 17 * 60, isEnabled: false)
        ],
        calendarSyncEnabled: false,
        suppressDuringSelectedEvents: true,
        promptAfterSelectedEvents: true,
        selectedEventPreferences: [],
        selectedCalendarIdentifiers: [],
        restDayIdentifiers: []
    )

    enum CodingKeys: String, CodingKey {
        case promptIntervalMinutes
        case notificationsEnabled
        case quietWindows
        case calendarSyncEnabled
        case suppressDuringSelectedEvents
        case promptAfterSelectedEvents
        case selectedEventPreferences
        case selectedCalendarIdentifiers
        case restDayIdentifiers
    }

    init(
        promptIntervalMinutes: Int,
        notificationsEnabled: Bool,
        quietWindows: [QuietWindow],
        calendarSyncEnabled: Bool,
        suppressDuringSelectedEvents: Bool,
        promptAfterSelectedEvents: Bool,
        selectedEventPreferences: [CalendarEventPreference],
        selectedCalendarIdentifiers: [String],
        restDayIdentifiers: [String]
    ) {
        self.promptIntervalMinutes = promptIntervalMinutes
        self.notificationsEnabled = notificationsEnabled
        self.quietWindows = quietWindows
        self.calendarSyncEnabled = calendarSyncEnabled
        self.suppressDuringSelectedEvents = suppressDuringSelectedEvents
        self.promptAfterSelectedEvents = promptAfterSelectedEvents
        self.selectedEventPreferences = selectedEventPreferences
        self.selectedCalendarIdentifiers = selectedCalendarIdentifiers
        self.restDayIdentifiers = restDayIdentifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        promptIntervalMinutes = try container.decode(Int.self, forKey: .promptIntervalMinutes)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        quietWindows = try container.decode([QuietWindow].self, forKey: .quietWindows)
        calendarSyncEnabled = try container.decode(Bool.self, forKey: .calendarSyncEnabled)
        suppressDuringSelectedEvents = try container.decode(Bool.self, forKey: .suppressDuringSelectedEvents)
        promptAfterSelectedEvents = try container.decode(Bool.self, forKey: .promptAfterSelectedEvents)
        selectedEventPreferences = try container.decode([CalendarEventPreference].self, forKey: .selectedEventPreferences)
        selectedCalendarIdentifiers = try container.decodeIfPresent([String].self, forKey: .selectedCalendarIdentifiers) ?? []
        restDayIdentifiers = try container.decodeIfPresent([String].self, forKey: .restDayIdentifiers) ?? []
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
