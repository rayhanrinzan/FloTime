import Foundation

@MainActor
struct GoogleCalendarService {
    private let oauthService: GoogleOAuthService

    init(oauthService: GoogleOAuthService) {
        self.oauthService = oauthService
    }

    func isConnected() -> Bool {
        oauthService.hasStoredSession()
    }

    func disconnect() async throws {
        try await oauthService.disconnect()
    }

    func fetchCalendars() async throws -> [DeviceCalendarSnapshot] {
        let token = try await oauthService.validAccessToken()
        let response: GoogleCalendarListResponse = try await request(
            url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader")!,
            accessToken: token
        )

        return response.items
            .filter { $0.deleted != true }
            .map {
                DeviceCalendarSnapshot(
                    id: Self.prefixedCalendarID($0.id),
                    title: $0.summaryOverride ?? $0.summary,
                    sourceTitle: "Direct Google Calendar",
                    provider: .google
                )
            }
    }

    func fetchEvents(
        calendarIdentifiers: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CalendarEventSnapshot] {
        guard !calendarIdentifiers.isEmpty else { return [] }

        let token = try await oauthService.validAccessToken()
        var allEvents: [CalendarEventSnapshot] = []

        for identifier in calendarIdentifiers {
            let rawCalendarID = Self.unprefixedCalendarID(identifier)
            let encodedCalendarID = rawCalendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawCalendarID

            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarID)/events")
            components?.queryItems = [
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "timeMin", value: Self.isoFormatter.string(from: startDate)),
                URLQueryItem(name: "timeMax", value: Self.isoFormatter.string(from: endDate))
            ]

            guard let url = components?.url else { continue }
            let response: GoogleEventsResponse = try await request(url: url, accessToken: token)
            let calendarTitle = response.summary

            let events = response.items.compactMap { event -> CalendarEventSnapshot? in
                guard let start = event.start.resolvedDate else { return nil }
                guard let end = event.end.resolvedDate ?? event.start.resolvedDate else { return nil }

                return CalendarEventSnapshot(
                    id: "google-event:\(rawCalendarID):\(event.id)",
                    title: event.summary ?? "Untitled Event",
                    startDate: start,
                    endDate: end,
                    isAllDay: event.start.date != nil,
                    calendarIdentifier: identifier,
                    calendarTitle: calendarTitle,
                    sourceTitle: "Direct Google Calendar",
                    provider: .google
                )
            }

            allEvents.append(contentsOf: events)
        }

        return allEvents.sorted { $0.startDate < $1.startDate }
    }

    private func request<Response: Decodable>(url: URL, accessToken: String) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let apiError = try? JSONDecoder().decode(GoogleAPIErrorResponse.self, from: data)
            throw GoogleOAuthError.tokenExchangeFailed(
                apiError?.error.message ?? "Google Calendar request failed."
            )
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func prefixedCalendarID(_ calendarID: String) -> String {
        "google:\(calendarID)"
    }

    private static func unprefixedCalendarID(_ calendarID: String) -> String {
        calendarID.replacingOccurrences(of: "google:", with: "")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarListEntry]
}

private struct GoogleCalendarListEntry: Decodable {
    let id: String
    let summary: String
    let summaryOverride: String?
    let deleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case summary
        case summaryOverride = "summaryOverride"
        case deleted
    }
}

private struct GoogleEventsResponse: Decodable {
    let summary: String
    let items: [GoogleEvent]
}

private struct GoogleEvent: Decodable {
    let id: String
    let summary: String?
    let start: GoogleEventDate
    let end: GoogleEventDate
}

private struct GoogleEventDate: Decodable {
    let date: String?
    let dateTime: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date)

        if let rawDateTime = try container.decodeIfPresent(String.self, forKey: .dateTime) {
            dateTime = GoogleEventDate.dateTimeFormatter.date(from: rawDateTime)
                ?? GoogleEventDate.fractionalDateTimeFormatter.date(from: rawDateTime)
        } else {
            dateTime = nil
        }
    }

    var resolvedDate: Date? {
        if let dateTime {
            return dateTime
        }

        guard let date else { return nil }
        return GoogleEventDate.dayFormatter.date(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private enum CodingKeys: String, CodingKey {
        case date
        case dateTime
    }
}

private struct GoogleAPIErrorResponse: Decodable {
    let error: GoogleAPIError
}

private struct GoogleAPIError: Decodable {
    let message: String
}
