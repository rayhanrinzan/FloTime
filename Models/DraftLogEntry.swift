import Foundation

struct DraftLogEntry: Identifiable, Hashable {
    let id: UUID
    var title: String
    var prompt: String
    var note: String
    var rating: Int
    var timestamp: Date
    var source: ActivitySource
    var calendarEventID: String?

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        note: String = "",
        rating: Int = 7,
        timestamp: Date = .now,
        source: ActivitySource = .manual,
        calendarEventID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.note = note
        self.rating = rating
        self.timestamp = timestamp
        self.source = source
        self.calendarEventID = calendarEventID
    }
}
