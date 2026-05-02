import Foundation

struct CalendarEventSnapshot: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
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
