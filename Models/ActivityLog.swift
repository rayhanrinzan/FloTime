import Foundation

struct ActivityLog: Identifiable, Codable, Hashable {
    let id: UUID
    var timestamp: Date
    var note: String
    var rating: Int
    var source: ActivitySource
    var calendarEventID: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        note: String,
        rating: Int,
        source: ActivitySource = .manual,
        calendarEventID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.note = note
        self.rating = rating
        self.source = source
        self.calendarEventID = calendarEventID
    }
}

enum ActivitySource: String, Codable, CaseIterable, Hashable {
    case manual
    case calendarEvent
}
