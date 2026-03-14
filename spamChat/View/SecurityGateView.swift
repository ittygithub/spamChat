//
//  SecurityGateView.swift
//  spamChat
//
//  Orchestrates the post-login security flow:
//  1. Biometric / device passcode check
//  2. Password registration (first time) or password check (returning user)
//

import SwiftUI

enum SecurityStep {
    case biometric
    case passwordCheck
    case passwordRegistration
    case verified
}

struct SecurityGateView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var step: SecurityStep = .biometric
    @State private var biometricError: String?
    @State private var isDuressMode = false

    var body: some View {
        Group {
            switch step {
            case .biometric:
                biometricView

            case .passwordRegistration:
                PasswordRegistrationView {
                    // After registration, go to password check
                    step = .passwordCheck
                }

            case .passwordCheck:
                PasswordCheckView { result in
                    switch result {
                    case .appPassword:
                        isDuressMode = false
                        // Only schedule if no existing recheck (don't reset on every login)
                        if AppPasswordManager.shared.nextRecheckDate == nil {
                            AppPasswordManager.shared.scheduleNextRecheck()
                        }
                        step = .verified
                    case .duressPassword:
                        isDuressMode = true
                        step = .verified
                    case .invalid:
                        break // handled inside PasswordCheckView
                    }
                }

            case .verified:
                MainTabView(isDuressMode: isDuressMode)
                    .task {
                        await authService.verifyToken()
                    }
            }
        }
    }

    // MARK: - Biometric View

    private var biometricView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "faceid")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Identity Verification")
                    .font(.system(size: 28, weight: .bold))

                Text("Verify with Face ID or device passcode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let error = biometricError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: performBiometric) {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .font(.title2)
                    Text("Verify Identity")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            performBiometric()
        }
    }

    private func performBiometric() {
        biometricError = nil
        Task {
            do {
                let success = try await BiometricService.shared.authenticate()
                await MainActor.run {
                    if success {
                        // Move to password step
                        if AppPasswordManager.shared.isPasswordRegistered {
                            step = .passwordCheck
                        } else {
                            step = .passwordRegistration
                        }
                    } else {
                        biometricError = "Authentication failed. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    biometricError = error.localizedDescription
                }
            }
        }
    }
}
