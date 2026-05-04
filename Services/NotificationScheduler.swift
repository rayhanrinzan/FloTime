import Foundation
import UserNotifications

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedulePrompts(settings: AppSettings, events: [CalendarEventSnapshot]) async {
        center.removeAllPendingNotificationRequests()

        guard settings.notificationsEnabled else { return }

        let plannedDates = nextPromptDates(settings: settings, events: events, from: .now, maximumCount: 48)
        for (index, date) in plannedDates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "FloTime Check-In"
            content.body = "What have you been up to in the last \(intervalDescription(minutes: settings.promptIntervalMinutes))?"
            content.sound = .default
            content.categoryIdentifier = FloTimeNotificationRoute.checkInCategoryID
            content.userInfo = [
                "type": "checkin",
                "intervalMinutes": settings.promptIntervalMinutes
            ]

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: "checkin-\(index)", content: content, trigger: trigger)
            try? await add(request)
        }

        guard settings.promptAfterSelectedEvents else { return }

        let preferenceMap = Dictionary(uniqueKeysWithValues: settings.selectedEventPreferences.map { ($0.eventIdentifier, $0) })
        for event in events {
            guard let preference = preferenceMap[event.id], preference.promptToLogAfter else { continue }
            guard event.endDate > .now else { continue }
            guard !isRestDay(date: event.endDate, restDayIdentifiers: settings.restDayIdentifiers) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Log This Event?"
            content.body = "\"\(event.title)\" just ended. Want to save it as an activity?"
            content.sound = .default
            content.categoryIdentifier = FloTimeNotificationRoute.eventCategoryID
            content.userInfo = [
                "type": "eventFollowup",
                "eventID": event.id,
                "eventTitle": event.title,
                "eventEndTimestamp": event.endDate.timeIntervalSince1970
            ]

            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.endDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(identifier: "event-\(event.id)", content: content, trigger: trigger)
            try? await add(request)
        }
    }

    private func nextPromptDates(
        settings: AppSettings,
        events: [CalendarEventSnapshot],
        from startDate: Date,
        maximumCount: Int
    ) -> [Date] {
        var results: [Date] = []
        var cursor = startDate
        let interval = TimeInterval(settings.promptIntervalMinutes * 60)
        let mutedEventIDs = Set(
            settings.selectedEventPreferences
                .filter(\.muteDuringEvent)
                .map(\.eventIdentifier)
        )

        while results.count < maximumCount {
            cursor = cursor.addingTimeInterval(interval)
            if isRestDay(date: cursor, restDayIdentifiers: settings.restDayIdentifiers) {
                continue
            }
            if shouldMute(date: cursor, quietWindows: settings.quietWindows) {
                continue
            }

            if settings.calendarSyncEnabled && settings.suppressDuringSelectedEvents {
                let overlapsMutedEvent = events.contains { event in
                    mutedEventIDs.contains(event.id) && cursor >= event.startDate && cursor <= event.endDate
                }

                if overlapsMutedEvent {
                    continue
                }
            }

            results.append(cursor)
        }

        return results
    }

    private func shouldMute(date: Date, quietWindows: [QuietWindow]) -> Bool {
        let calendar = Calendar.current
        let minutes = (calendar.component(.hour, from: date) * 60) + calendar.component(.minute, from: date)

        return quietWindows.contains { window in
            guard window.isEnabled else { return false }

            if window.startMinutes <= window.endMinutes {
                return minutes >= window.startMinutes && minutes < window.endMinutes
            } else {
                return minutes >= window.startMinutes || minutes < window.endMinutes
            }
        }
    }

    private func isRestDay(date: Date, restDayIdentifiers: [String]) -> Bool {
        let identifier = NotificationScheduler.dayFormatter.string(from: date)
        return restDayIdentifiers.contains(identifier)
    }

    private func intervalDescription(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        }

        let hours = Double(minutes) / 60.0
        if hours.rounded() == hours {
            return "\(Int(hours)) hour" + (hours == 1 ? "" : "s")
        }

        return String(format: "%.1f hours", hours)
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension NotificationScheduler {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
