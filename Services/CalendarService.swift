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

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEventSnapshot] {
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEventSnapshot(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay
                )
            }
    }
}
