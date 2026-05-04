import EventKit
import Foundation

final class CalendarService {
    private let store = EKEventStore()

    func requestAccessIfNeeded() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            return true
        case .fullAccess:
            return true
        case .writeOnly:
            return false
        case .denied, .restricted:
            return false
        case .notDetermined:
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    store.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    func availableCalendars() -> [DeviceCalendarSnapshot] {
        store.calendars(for: .event)
            .map(calendarSnapshot(from:))
            .sorted {
                if $0.provider == $1.provider {
                    if $0.sourceTitle == $1.sourceTitle {
                        return $0.title < $1.title
                    }
                    return $0.sourceTitle < $1.sourceTitle
                }
                return $0.provider.rawValue < $1.provider.rawValue
            }
    }

    func fetchEvents(
        from startDate: Date,
        to endDate: Date,
        calendarIdentifiers: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        let selectedCalendars: [EKCalendar]? = calendarIdentifiers.isEmpty
            ? nil
            : store.calendars(for: .event).filter { calendarIdentifiers.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                let provider = provider(for: $0.calendar)
                return CalendarEventSnapshot(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    calendarIdentifier: $0.calendar.calendarIdentifier,
                    calendarTitle: $0.calendar.title,
                    sourceTitle: $0.calendar.source.title,
                    provider: provider
                )
            }
    }

    private func calendarSnapshot(from calendar: EKCalendar) -> DeviceCalendarSnapshot {
        DeviceCalendarSnapshot(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            provider: provider(for: calendar)
        )
    }

    private func provider(for calendar: EKCalendar) -> CalendarProvider {
        let sourceText = "\(calendar.source.title) \(calendar.title)".lowercased()

        if sourceText.contains("google") || sourceText.contains("gmail") {
            return .google
        }

        switch calendar.source.sourceType {
        case .local, .birthdays, .mobileMe:
            return .apple
        default:
            return .other
        }
    }
}
