import Foundation
import GoogleSignIn
import UIKit

enum GoogleCalendarConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

enum GoogleOAuthError: LocalizedError {
    case missingClientID
    case missingCallbackScheme
    case missingCalendarScope
    case notSignedIn
    case invalidResponse
    case tokenExchangeFailed(String)
    case presentationContextUnavailable

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google sign-in is not configured in this build yet."
        case .missingCallbackScheme:
            return "FloTime still needs the reversed Google client ID URL scheme in Info.plist."
        case .missingCalendarScope:
            return "FloTime still needs permission to read your Google Calendar."
        case .notSignedIn:
            return "Sign in with Google first."
        case .invalidResponse:
            return "Google returned an unexpected response."
        case .tokenExchangeFailed(let message):
            return message
        case .presentationContextUnavailable:
            return "FloTime couldn't find a screen to present Google sign-in."
        }
    }
}

@MainActor
final class GoogleOAuthService {
    static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    func hasStoredSession() -> Bool {
        GIDSignIn.sharedInstance.currentUser != nil || GIDSignIn.sharedInstance.hasPreviousSignIn()
    }

    func configurationIssue() -> GoogleOAuthError? {
        if configuredClientID() == nil {
            return .missingClientID
        }

        if !hasConfiguredCallbackScheme() {
            return .missingCallbackScheme
        }

        return nil
    }

    func configuredClientID() -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "REPLACE_WITH_GOOGLE_IOS_CLIENT_ID" else {
            return nil
        }

        return trimmed
    }

    func restorePreviousSignInIfPossible() async {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }

        do {
            _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        } catch {
            GIDSignIn.sharedInstance.signOut()
        }
    }

    func authorizeCalendarAccess() async throws {
        guard let presentingViewController = topViewController() else {
            throw GoogleOAuthError.presentationContextUnavailable
        }

        if let configurationIssue = configurationIssue() {
            throw configurationIssue
        }

        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            if currentUser.grantedScopes?.contains(Self.calendarScope) == true {
                _ = try await currentUser.refreshTokensIfNeeded()
                return
            }

            _ = try await currentUser.addScopes(
                [Self.calendarScope],
                presenting: presentingViewController
            )
            return
        }

        guard let clientID = configuredClientID() else {
            throw GoogleOAuthError.missingClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        _ = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: [Self.calendarScope]
        )
    }

    func validAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleOAuthError.notSignedIn
        }

        let refreshedUser = try await currentUser.refreshTokensIfNeeded()
        guard refreshedUser.grantedScopes?.contains(Self.calendarScope) == true else {
            throw GoogleOAuthError.missingCalendarScope
        }

        return refreshedUser.accessToken.tokenString
    }

    func disconnect() async throws {
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            GIDSignIn.sharedInstance.signOut()
            return
        }

        try await GIDSignIn.sharedInstance.disconnect()
    }

    private func topViewController() -> UIViewController? {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in activeScenes {
            if let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController {
                return topViewController(from: rootViewController)
            }
        }

        return nil
    }

    private func topViewController(from rootViewController: UIViewController) -> UIViewController {
        if let presentedViewController = rootViewController.presentedViewController {
            return topViewController(from: presentedViewController)
        }

        if let navigationController = rootViewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return topViewController(from: visibleViewController)
        }

        if let tabBarController = rootViewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(from: selectedViewController)
        }

        return rootViewController
    }

    private func hasConfiguredCallbackScheme() -> Bool {
        guard
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else {
            return false
        }

        let schemes = urlTypes
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return schemes.contains { !$0.isEmpty && $0 != "REPLACE_WITH_REVERSED_GOOGLE_CLIENT_ID" }
    }
}
