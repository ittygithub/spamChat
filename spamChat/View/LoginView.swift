//
//  LoginView.swift
//  spamChat
//

import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var isSigningInOten = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / Title
            VStack(spacing: 12) {
                Image(systemName: "message.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Spam Chat")
                    .font(.system(size: 32, weight: .bold))

                Text("Monitor and manage spam messages")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                // Oten Sign-In Button
                Button(action: handleOtenSignIn) {
                    HStack(spacing: 12) {
                        if isSigningInOten {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.title2)
                        }
                        Text(isSigningInOten ? "Signing in..." : "Sign in with Oten")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSigningInOten)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 60)
        }
    }

    private func handleGoogleSignIn() {
        guard let rootVC = getRootViewController() else {
            errorMessage = "Unable to present sign-in"
            return
        }

        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                let idToken = try await GoogleSignInHelper.shared.signIn(presenting: rootVC)
                print("✅ Google Sign-In success, sending to backend...")

                try await authService.loginWithGoogle(idToken: idToken)
                await MainActor.run { isSigningIn = false }
            } catch let error as GIDSignInError where error.code == .canceled {
                // User cancelled - don't show error
                await MainActor.run { isSigningIn = false }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleOtenSignIn() {
        isSigningInOten = true
        errorMessage = nil

        Task {
            do {
                let result = try await OtenAuthService.shared.signIn()
                print("✅ Oten Sign-In success, sending code to backend...")

                try await authService.loginWithOten(code: result.code, codeVerifier: result.codeVerifier)
                await MainActor.run { isSigningInOten = false }
            } catch OtenAuthError.cancelled {
                // User cancelled - don't show error
                await MainActor.run { isSigningInOten = false }
            } catch {
                await MainActor.run {
                    isSigningInOten = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
