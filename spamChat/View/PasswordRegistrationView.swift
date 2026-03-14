//
//  PasswordRegistrationView.swift
//  spamChat
//

import SwiftUI

struct PasswordRegistrationView: View {
    @State private var appPassword = ""
    @State private var appPasswordRepeat = ""
    @State private var duressPassword = ""
    @State private var duressPasswordRepeat = ""
    @State private var errorMessage: String?
    @State private var isRegistering = false
    @State private var showAppPassword = false
    @State private var showAppPasswordRepeat = false
    @State private var showDuressPassword = false
    @State private var showDuressPasswordRepeat = false
    @Environment(\.colorScheme) private var colorScheme

    var onRegistered: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with gradient icon
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.blue.opacity(0.3), radius: 12, y: 6)

                        Text("Set Up Security")
                            .font(.system(size: 26, weight: .bold))

                        Text("Create passwords to protect your data.\nKeep them safe and memorable.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                    // Error banner
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                    }

                    // Application Password Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "key.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Application Password")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Used for normal access")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        passwordField("Enter password", text: $appPassword, isVisible: $showAppPassword)
                        passwordField("Confirm password", text: $appPasswordRepeat, isVisible: $showAppPasswordRepeat)

                        // Match indicator
                        if !appPassword.isEmpty && !appPasswordRepeat.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: appPassword == appPasswordRepeat ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(appPassword == appPasswordRepeat ? "Passwords match" : "Passwords do not match")
                                    .font(.caption)
                            }
                            .foregroundColor(appPassword == appPasswordRepeat ? .green : .red)
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    // Duress Password Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Duress Password")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Shows fake data to protect real info")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        passwordField("Enter duress password", text: $duressPassword, isVisible: $showDuressPassword)
                        passwordField("Confirm duress password", text: $duressPasswordRepeat, isVisible: $showDuressPasswordRepeat)

                        // Match indicator
                        if !duressPassword.isEmpty && !duressPasswordRepeat.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: duressPassword == duressPasswordRepeat ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(duressPassword == duressPasswordRepeat ? "Passwords match" : "Passwords do not match")
                                    .font(.caption)
                            }
                            .foregroundColor(duressPassword == duressPasswordRepeat ? .green : .red)
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    // Requirements
                    VStack(alignment: .leading, spacing: 6) {
                        requirementRow("Minimum 4 characters", met: appPassword.count >= 4 && duressPassword.count >= 4)
                        requirementRow("Passwords must match their confirmations",
                                       met: (appPassword == appPasswordRepeat && !appPassword.isEmpty) &&
                                            (duressPassword == duressPasswordRepeat && !duressPassword.isEmpty))
                        requirementRow("App and duress passwords must differ",
                                       met: !appPassword.isEmpty && !duressPassword.isEmpty && appPassword != duressPassword)
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 16)
                }
            }

            // Register Button
            Button(action: handleRegister) {
                HStack(spacing: 8) {
                    if isRegistering {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text(isRegistering ? "Saving..." : "Set Up Security")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isFormValid
                    ? LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!isFormValid || isRegistering)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Components

    private func passwordField(_ placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack(spacing: 0) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 16))
            .autocapitalization(.none)
            .disableAutocorrection(true)

            Button(action: { isVisible.wrappedValue.toggle() }) {
                Image(systemName: isVisible.wrappedValue ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(met ? .green : .gray.opacity(0.5))
            Text(text)
                .font(.caption)
                .foregroundColor(met ? .primary : .secondary)
        }
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color.white.opacity(0.06)
            } else {
                Color.white
            }
        }
    }

    private var isFormValid: Bool {
        !appPassword.isEmpty &&
        !appPasswordRepeat.isEmpty &&
        !duressPassword.isEmpty &&
        !duressPasswordRepeat.isEmpty
    }

    private func handleRegister() {
        errorMessage = nil

        guard appPassword.count >= 4 else {
            errorMessage = "Application password must be at least 4 characters"
            return
        }
        guard appPassword == appPasswordRepeat else {
            errorMessage = "Application passwords do not match"
            return
        }
        guard duressPassword.count >= 4 else {
            errorMessage = "Duress password must be at least 4 characters"
            return
        }
        guard duressPassword == duressPasswordRepeat else {
            errorMessage = "Duress passwords do not match"
            return
        }
        guard appPassword != duressPassword else {
            errorMessage = "Application password and duress password must be different"
            return
        }

        isRegistering = true

        let success = AppPasswordManager.shared.registerPasswords(
            appPassword: appPassword,
            duressPassword: duressPassword
        )

        if success {
            onRegistered()
        } else {
            errorMessage = "Failed to save passwords. Please try again."
            isRegistering = false
        }
    }
}
