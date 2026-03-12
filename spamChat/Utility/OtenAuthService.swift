//
//  OtenAuthService.swift
//  spamChat
//

import Foundation
import AuthenticationServices
import UIKit
import CryptoKit

/// Result from Oten OAuth sign-in containing both code and PKCE verifier
struct OtenAuthResult {
    let code: String
    let codeVerifier: String
}

class OtenAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OtenAuthService()

    private let clientID = Env.shared.otenClientID
    private let issuer = Env.shared.otenIssuer
    private let redirectURI = Env.shared.otenRedirectURI

    private override init() {}

    /// Opens Oten login in a web browser and returns the authorization code + PKCE verifier
    func signIn() async throws -> OtenAuthResult {
        let state = UUID().uuidString

        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "\(issuer)/v1/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url else {
            throw OtenAuthError.invalidURL
        }

        let callbackScheme = "spamchat"

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OtenAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: OtenAuthError.authFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OtenAuthError.noAuthCode)
                    return
                }

                print("🔍 Oten callback URL: \(callbackURL.absoluteString)")

                // Try to extract code from query parameters first
                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                var code = components?.queryItems?.first(where: { $0.name == "code" })?.value
                var returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value

                // Some OAuth providers return params in the URL fragment (#) instead of query (?)
                if code == nil, let fragment = callbackURL.fragment {
                    let fragmentItems = URLComponents(string: "?\(fragment)")?.queryItems
                    code = fragmentItems?.first(where: { $0.name == "code" })?.value
                    if returnedState == nil {
                        returnedState = fragmentItems?.first(where: { $0.name == "state" })?.value
                    }
                }

                // Check for error response from Oten
                if code == nil {
                    let errorDesc = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
                    let errorCode = components?.queryItems?.first(where: { $0.name == "error" })?.value
                    let msg = errorDesc ?? errorCode ?? "Unknown error"
                    print("❌ Oten error: \(msg)")
                    continuation.resume(throwing: OtenAuthError.authFailed(msg))
                    return
                }

                guard let authCode = code else {
                    print("❌ No code found in callback URL: \(callbackURL.absoluteString)")
                    continuation.resume(throwing: OtenAuthError.noAuthCode)
                    return
                }

                // Verify state parameter to prevent CSRF
                if returnedState != state {
                    print("❌ State mismatch: expected=\(state), got=\(returnedState ?? "nil")")
                    continuation.resume(throwing: OtenAuthError.stateMismatch)
                    return
                }

                print("✅ Oten auth code received (length: \(authCode.count))")
                continuation.resume(returning: authCode)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                session.start()
            }
        }

        return OtenAuthResult(code: code, codeVerifier: codeVerifier)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Errors

enum OtenAuthError: LocalizedError {
    case invalidURL
    case cancelled
    case authFailed(String)
    case noAuthCode
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Oten authorization URL"
        case .cancelled:
            return "Login was cancelled"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .noAuthCode:
            return "No authorization code received"
        case .stateMismatch:
            return "Security validation failed"
        }
    }
}
