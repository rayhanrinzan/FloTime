import Foundation
import UserNotifications

enum FloTimeNotificationRoute {
    static let checkInCategoryID = "FLOTIME_CHECKIN"
    static let eventCategoryID = "FLOTIME_EVENT_FOLLOWUP"
    static let openActionID = "FLOTIME_OPEN_LOG"
    static let skipActionID = "FLOTIME_SKIP"
    private static var pendingUserInfo: [AnyHashable: Any]?

    static var categories: Set<UNNotificationCategory> {
        let openAction = UNNotificationAction(
            identifier: openActionID,
            title: "Log It",
            options: [.foreground]
        )
        let skipAction = UNNotificationAction(
            identifier: skipActionID,
            title: "Skip",
            options: []
        )

        return [
            UNNotificationCategory(
                identifier: checkInCategoryID,
                actions: [openAction, skipAction],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: eventCategoryID,
                actions: [openAction, skipAction],
                intentIdentifiers: [],
                options: []
            )
        ]
    }

    static func post(from userInfo: [AnyHashable: Any]) {
        pendingUserInfo = userInfo
        let notificationCenter = NotificationCenter.default
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "checkin":
            notificationCenter.post(
                name: .floTimeOpenCheckIn,
                object: nil,
                userInfo: userInfo
            )

        case "eventFollowup":
            notificationCenter.post(
                name: .floTimeOpenEventLog,
                object: nil,
                userInfo: userInfo
            )

        default:
            break
        }
    }

    static func consumePendingUserInfo() -> [AnyHashable: Any]? {
        let userInfo = pendingUserInfo
        pendingUserInfo = nil
        return userInfo
    }
}

extension Notification.Name {
    static let floTimeOpenCheckIn = Notification.Name("floTimeOpenCheckIn")
    static let floTimeOpenEventLog = Notification.Name("floTimeOpenEventLog")
}
