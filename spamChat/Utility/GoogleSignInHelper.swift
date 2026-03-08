//
//  GoogleSignInHelper.swift
//  spamChat
//

import Foundation
import GoogleSignIn
import UIKit

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()

    private let clientID = Env.shared.googleClientID

    private init() {}

    func configure() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    func signIn(presenting viewController: UIViewController) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: GoogleSignInError.noIDToken)
                    return
                }

                continuation.resume(returning: idToken)
            }
        }
    }

    func handleURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // The reversed client ID for URL scheme
    // e.g. clientID "286618882607-abc123.apps.googleusercontent.com"
    // becomes URL scheme "com.googleusercontent.apps.286618882607-abc123"
    var reversedClientID: String {
        let parts = clientID.components(separatedBy: ".")
        return parts.reversed().joined(separator: ".")
    }
}

enum GoogleSignInError: Error, LocalizedError {
    case noIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noIDToken: return "Failed to get Google ID token"
        case .cancelled: return "Sign in was cancelled"
        }
    }
}
