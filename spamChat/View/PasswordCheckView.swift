//
//  PasswordCheckView.swift
//  spamChat
//

import SwiftUI

struct PasswordCheckView: View {
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var isLockedOut = false
    @State private var remainingSeconds = 0
    @State private var shakeOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var onAuthenticated: (AppPasswordManager.PasswordResult) -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let manager = AppPasswordManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        isLockedOut
                        ? LinearGradient(colors: [Color.red, Color.red.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.blue, Color.blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: isLockedOut ? "lock.trianglebadge.exclamationmark.fill" : "lock.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.white)
            }
            .shadow(color: (isLockedOut ? Color.red : Color.blue).opacity(0.3), radius: 12, y: 6)
            .padding(.bottom, 20)

            Text(isLockedOut ? "Temporarily Locked" : "Welcome Back")
                .font(.system(size: 26, weight: .bold))
                .padding(.bottom, 6)

            Text(isLockedOut
                 ? "Too many failed attempts"
                 : "Enter your password to unlock")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 28)

            // Lockout countdown
            if isLockedOut {
                VStack(spacing: 10) {
                    Text("Try again in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(formatDuration(remainingSeconds))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                                .frame(height: 4)

                            Capsule()
                                .fill(Color.red)
                                .frame(width: max(0, geo.size.width * lockoutProgress), height: 4)
                                .animation(.linear(duration: 1), value: remainingSeconds)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }

            // Error
            if let error = errorMessage, !isLockedOut {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.subheadline)
                }
                .foregroundColor(.red)
                .padding(.bottom, 16)
            }

            // Password field (hidden when locked)
            if !isLockedOut {
                VStack(spacing: 14) {
                    passwordField("Enter password", text: $password, isVisible: $showPassword)
                        .offset(x: shakeOffset)

                    Button(action: handleVerify) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                            Text("Unlock")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            password.isEmpty
                            ? LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(password.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            Spacer()
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            checkLockoutState()
        }
        .onReceive(timer) { _ in
            if isLockedOut {
                remainingSeconds = manager.remainingLockoutSeconds
                if remainingSeconds <= 0 {
                    isLockedOut = false
                    errorMessage = nil
                }
            }
        }
    }

    // MARK: - Password field with eye toggle

    private func passwordField(_ placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack(spacing: 0) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 17))
            .autocapitalization(.none)
            .disableAutocorrection(true)

            Button(action: { isVisible.wrappedValue.toggle() }) {
                Image(systemName: isVisible.wrappedValue ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    errorMessage != nil ? Color.red.opacity(0.4) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Lockout progress
    private var lockoutProgress: CGFloat {
        guard let until = manager.lockoutUntil else { return 0 }
        let level = max(0, manager.lockoutLevel - 1)
        let durations: [TimeInterval] = [60, 300, 600, 1800, 3600, 18000]
        let totalDuration = durations[min(level, durations.count - 1)]
        let elapsed = totalDuration - until.timeIntervalSinceNow
        return max(0, min(1, CGFloat(elapsed / totalDuration)))
    }

    private func checkLockoutState() {
        if manager.isLockedOut {
            isLockedOut = true
            remainingSeconds = manager.remainingLockoutSeconds
        }
    }

    private func handleVerify() {
        let result = manager.verifyPassword(password)

        switch result {
        case .appPassword, .duressPassword:
            manager.resetLockout()
            onAuthenticated(result)
        case .invalid:
            password = ""
            // Shake animation
            withAnimation(.default) {
                shakeOffset = -12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.3)) {
                    shakeOffset = 0
                }
            }

            if let lockDuration = manager.recordFailedAttempt() {
                isLockedOut = true
                remainingSeconds = Int(lockDuration)
                errorMessage = nil
            } else {
                let attemptsInCycle = manager.failedAttempts % 3
                let remaining = attemptsInCycle == 0 ? 3 : 3 - attemptsInCycle
                errorMessage = "Wrong password. \(remaining) attempt\(remaining == 1 ? "" : "s") before lockout."
            }
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
