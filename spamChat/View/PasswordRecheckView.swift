//
//  PasswordRecheckView.swift
//  spamChat
//
//  Periodic password re-verification popup.
//  User must enter both app password and duress password.
//

import SwiftUI

struct PasswordRecheckView: View {
    @State private var appPassword = ""
    @State private var duressPassword = ""
    @State private var showAppPassword = false
    @State private var showDuressPassword = false
    @State private var errorMessage: String?
    @State private var isVerifying = false
    @Environment(\.colorScheme) private var colorScheme

    var deadline: Date?
    var isOverdue: Bool = false
    var onVerified: () -> Void
    var onDismiss: () -> Void

    private var deadlineText: String {
        guard let deadline = deadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM/yyyy"
        return formatter.string(from: deadline)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                if !isOverdue {
                    Button(action: onDismiss) {
                        Text("Later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("")
                        .frame(width: 50)
                }

                Spacer()

                Text("Password Recheck")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Text("")
                    .frame(width: 50)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)

                        Image(systemName: "key.viewfinder")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.orange.opacity(0.3), radius: 10, y: 4)
                    .padding(.top, 16)

                    // Title
                    VStack(spacing: 8) {
                        Text("Confirm Your Passwords")
                            .font(.system(size: 20, weight: .bold))

                        Text("Please re-enter your passwords to keep your account secure.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Warning about deadline
                    if let deadline = deadline, deadline.timeIntervalSinceNow > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .foregroundColor(.orange)
                            Text("Complete before **\(deadlineText)**, otherwise the system will log you out.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }

                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 6) {
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
                        .padding(.horizontal, 20)
                    }

                    // App Password
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Application Password", systemImage: "key.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        passwordField("Enter app password", text: $appPassword, isVisible: $showAppPassword)
                    }
                    .padding(.horizontal, 20)

                    // Duress Password
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Label("Duress Password", systemImage: "exclamationmark.shield.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        Text("Re-enter your duress password to confirm you still remember it.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        passwordField("Enter duress password", text: $duressPassword, isVisible: $showDuressPassword)
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 8)
                }
            }

            // Confirm Button
            Button(action: handleVerify) {
                HStack(spacing: 8) {
                    if isVerifying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text(isVerifying ? "Verifying..." : "Confirm")
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
            .disabled(!isFormValid || isVerifying)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        !appPassword.isEmpty && !duressPassword.isEmpty
    }

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

    private func handleVerify() {
        errorMessage = nil
        isVerifying = true

        let success = AppPasswordManager.shared.verifyBothPasswords(
            appPassword: appPassword,
            duressPassword: duressPassword
        )

        if success {
            AppPasswordManager.shared.scheduleNextRecheck()
            onVerified()
        } else {
            isVerifying = false
            appPassword = ""
            duressPassword = ""
            errorMessage = "One or both passwords are incorrect. Please try again."
        }
    }
}
