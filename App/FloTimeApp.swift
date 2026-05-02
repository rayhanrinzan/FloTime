import SwiftUI

@main
struct FloTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ActivityStore()

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
                .preferredColorScheme(.light)
        }
    }
}
