import Foundation

struct AppSettings: Codable, Hashable {
    var promptIntervalMinutes: Int
    var notificationsEnabled: Bool
    var quietWindows: [QuietWindow]
    var calendarSyncEnabled: Bool
    var suppressDuringSelectedEvents: Bool
    var promptAfterSelectedEvents: Bool
    var selectedEventPreferences: [CalendarEventPreference]

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
        selectedEventPreferences: []
    )
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
