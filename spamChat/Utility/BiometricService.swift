//
//  BiometricService.swift
//  spamChat
//

import Foundation
import LocalAuthentication

class BiometricService {
    static let shared = BiometricService()

    private init() {}

    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"

        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)

        guard canEvaluate else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Verify your identity to access Spam Chat"
            )
            return success
        } catch {
            throw BiometricError.failed(error.localizedDescription)
        }
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available"
        case .failed(let message):
            return message
        }
    }
}
