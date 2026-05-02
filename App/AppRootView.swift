import SwiftUI

struct AppRootView: View {
    let store: ActivityStore
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayDashboardView(store: store, onAddLog: openManualLog)
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(AppTab.today)

            CalendarOverviewView(store: store)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(AppTab.calendar)

            SettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
        }
        .tint(FloTimeTheme.primary)
        .background(FloTimeTheme.background)
        .sheet(item: draftBinding) { draft in
            LogEntrySheet(store: store, draft: draft)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floTimeOpenCheckIn)) { notification in
            _ = FloTimeNotificationRoute.consumePendingUserInfo()
            handleCheckInNotification(notification.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floTimeOpenEventLog)) { notification in
            _ = FloTimeNotificationRoute.consumePendingUserInfo()
            handleEventNotification(notification.userInfo)
        }
        .task {
            await store.bootstrap()
            handlePendingNotificationIfNeeded()
        }
    }

    private var draftBinding: Binding<DraftLogEntry?> {
        Binding(
            get: { store.draftLogEntry },
            set: { store.draftLogEntry = $0 }
        )
    }

    private func openManualLog() {
        selectedTab = .today
        store.startManualLog()
    }

    private func handlePendingNotificationIfNeeded() {
        guard let userInfo = FloTimeNotificationRoute.consumePendingUserInfo(),
              let type = userInfo["type"] as? String else {
            return
        }

        switch type {
        case "checkin":
            handleCheckInNotification(userInfo)
        case "eventFollowup":
            handleEventNotification(userInfo)
        default:
            break
        }
    }

    private func handleCheckInNotification(_ userInfo: [AnyHashable: Any]?) {
        selectedTab = .today
        let interval = userInfo?["intervalMinutes"] as? Int ?? store.settings.promptIntervalMinutes
        store.startCheckInPrompt(intervalMinutes: interval)
    }

    private func handleEventNotification(_ userInfo: [AnyHashable: Any]?) {
        selectedTab = .today
        let eventID = userInfo?["eventID"] as? String ?? UUID().uuidString
        let eventTitle = userInfo?["eventTitle"] as? String ?? "Calendar event"
        let timestamp = (userInfo?["eventEndTimestamp"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .now
        store.startEventLog(eventID: eventID, eventTitle: eventTitle, endDate: timestamp)
    }
}

enum AppTab {
    case today
    case calendar
    case settings
}
