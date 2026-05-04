import AuthenticationServices
import CryptoKit
import Foundation
import Security
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
    case canceled
    case invalidRedirect
    case invalidState
    case missingAuthorizationCode
    case missingRefreshToken
    case unableToStart
    case invalidResponse
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google sign-in is not configured in this build yet."
        case .canceled:
            return "Google sign-in was canceled."
        case .invalidRedirect:
            return "Google redirected back with an invalid response."
        case .invalidState:
            return "Google sign-in state verification failed."
        case .missingAuthorizationCode:
            return "Google did not return an authorization code."
        case .missingRefreshToken:
            return "Google did not return a refresh token. Try reconnecting and approving access again."
        case .unableToStart:
            return "FloTime could not start the Google sign-in flow."
        case .invalidResponse:
            return "Google returned an unexpected response."
        case .tokenExchangeFailed(let message):
            return message
        }
    }
}

struct GoogleOAuthTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

@MainActor
final class GoogleOAuthService: NSObject {
    static let clientIDInfoPlistKey = "GoogleOAuthClientID"
    static let callbackScheme = "com.rayhanrinzan.flotime.oauth"
    static let redirectURI = "\(callbackScheme):/oauth2redirect/google"
    static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    private let tokenStore = KeychainStore(service: "com.rayhanrinzan.flotime.google")
    private var authenticationSession: ASWebAuthenticationSession?

    func hasStoredSession() -> Bool {
        storedTokens() != nil
    }

    func storedTokens() -> GoogleOAuthTokens? {
        guard let data = tokenStore.read(account: "google-oauth-tokens") else { return nil }
        return try? JSONDecoder().decode(GoogleOAuthTokens.self, from: data)
    }

    func configuredClientID() -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: Self.clientIDInfoPlistKey) as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "REPLACE_WITH_GOOGLE_CLIENT_ID" else {
            return nil
        }

        return trimmed
    }

    func authorize(clientID: String) async throws -> GoogleOAuthTokens {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            throw GoogleOAuthError.missingClientID
        }

        let codeVerifier = Self.codeVerifier()
        let state = UUID().uuidString
        let authorizationURL = try authorizationURL(
            clientID: trimmedClientID,
            state: state,
            codeVerifier: codeVerifier
        )

        let callbackURL = try await beginAuthentication(at: authorizationURL)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw GoogleOAuthError.invalidRedirect
        }

        let queryItems = components.queryItems ?? []
        let responseState = queryItems.first(where: { $0.name == "state" })?.value
        guard responseState == state else {
            throw GoogleOAuthError.invalidState
        }

        if let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value {
            throw GoogleOAuthError.tokenExchangeFailed(errorDescription)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw GoogleOAuthError.missingAuthorizationCode
        }

        var tokens = try await exchangeAuthorizationCode(
            code,
            clientID: trimmedClientID,
            codeVerifier: codeVerifier
        )

        if tokens.refreshToken.isEmpty {
            if let existingRefreshToken = storedTokens()?.refreshToken, !existingRefreshToken.isEmpty {
                tokens.refreshToken = existingRefreshToken
            } else {
                throw GoogleOAuthError.missingRefreshToken
            }
        }

        save(tokens: tokens)
        return tokens
    }

    func validAccessToken(clientID: String) async throws -> String {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GoogleOAuthError.missingClientID
        }

        guard let stored = storedTokens() else {
            throw GoogleOAuthError.missingRefreshToken
        }

        if stored.expiresAt > Date().addingTimeInterval(60) {
            return stored.accessToken
        }

        let refreshed = try await refreshAccessToken(
            refreshToken: stored.refreshToken,
            clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        save(tokens: refreshed)
        return refreshed.accessToken
    }

    func disconnect() {
        tokenStore.delete(account: "google-oauth-tokens")
    }

    private func authorizationURL(clientID: String, state: String, codeVerifier: String) throws -> URL {
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.calendarScope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components?.url else {
            throw GoogleOAuthError.invalidResponse
        }
        return url
    }

    private func beginAuthentication(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                self.authenticationSession = nil

                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleOAuthError.canceled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: GoogleOAuthError.invalidRedirect)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session

            guard session.start() else {
                self.authenticationSession = nil
                continuation.resume(throwing: GoogleOAuthError.unableToStart)
                return
            }
        }
    }

    private func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        codeVerifier: String
    ) async throws -> GoogleOAuthTokens {
        let bodyItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI)
        ]

        return try await performTokenRequest(bodyItems: bodyItems)
    }

    private func refreshAccessToken(refreshToken: String, clientID: String) async throws -> GoogleOAuthTokens {
        let bodyItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]

        var refreshed = try await performTokenRequest(bodyItems: bodyItems)
        refreshed.refreshToken = refreshToken
        return refreshed
    }

    private func performTokenRequest(bodyItems: [URLQueryItem]) async throws -> GoogleOAuthTokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyItems
            .map { item in
                let name = item.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.name
                let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(name)=\(value)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let tokenError = try? JSONDecoder().decode(GoogleTokenErrorResponse.self, from: data)
            throw GoogleOAuthError.tokenExchangeFailed(
                tokenError?.errorDescription ?? tokenError?.error ?? "Google token request failed."
            )
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return GoogleOAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    private func save(tokens: GoogleOAuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        tokenStore.write(data: data, account: "google-oauth-tokens")
    }

    private static func codeVerifier() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<96).compactMap { _ in characters.randomElement() })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension GoogleOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let window = windowScene.windows.first(where: \.isKeyWindow) {
                return window
            }
        }

        return ASPresentationAnchor()
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct GoogleTokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct KeychainStore {
    let service: String

    func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func write(data: Data, account: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertQuery = baseQuery
            insertQuery[kSecValueData as String] = data
            SecItemAdd(insertQuery as CFDictionary, nil)
        }
    }

    func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
