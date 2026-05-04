import Foundation

struct CalendarEventSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarIdentifier: String
    var calendarTitle: String
    var sourceTitle: String
    var provider: CalendarProvider
}

struct CalendarEventPreference: Identifiable, Codable, Hashable {
    var id: String { eventIdentifier }
    var eventIdentifier: String
    var title: String
    var startDate: Date
    var endDate: Date
    var muteDuringEvent: Bool
    var promptToLogAfter: Bool
}

enum CalendarPermissionState: String {
    case unknown
    case denied
    case authorized
}

enum CalendarProvider: String, Codable, Hashable {
    case apple
    case google
    case other

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .other:
            return "Other"
        }
    }
}

struct DeviceCalendarSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var sourceTitle: String
    var provider: CalendarProvider
}
