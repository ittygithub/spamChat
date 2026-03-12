//
//  AuthService.swift
//  spamChat
//

import Foundation

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false

    private let tokenKey = "auth_jwt_token"
    private let userKey = "auth_user_data"

    private init() {
        // Check stored token on init
        isLoggedIn = getToken() != nil
        currentUser = getStoredUser()
    }

    // MARK: - Token Management

    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        DispatchQueue.main.async {
            self.isLoggedIn = true
        }
    }

    func saveUser(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        DispatchQueue.main.async {
            self.currentUser = user
        }
    }

    func getStoredUser() -> AuthUser? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        DispatchQueue.main.async {
            self.isLoggedIn = false
            self.currentUser = nil
        }
    }

    // MARK: - Google Login

    func loginWithGoogle(idToken: String) async throws {
        DispatchQueue.main.async { self.isLoading = true }
        defer { DispatchQueue.main.async { self.isLoading = false } }

        let response = try await APIService.shared.googleLogin(googleIDToken: idToken)

        if response.success {
            saveToken(response.token)
            let user = AuthUser(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                avatarUrl: response.user.avatarUrl,
                status: response.user.status,
                expired: response.user.expired
            )
            saveUser(user)
        } else {
            throw APIError.serverError(response.message)
        }
    }

    // MARK: - Verify Token (check if still valid on app launch)

    func verifyToken() async {
        guard getToken() != nil else { return }

        do {
            let response = try await APIService.shared.verifyToken()
            if response.success {
                // Save refreshed token to extend session
                if !response.token.isEmpty {
                    saveToken(response.token)
                }
            } else {
                // Token invalid or user locked
                logout()
            }
        } catch {
            // Network error - keep token, user can retry
            print("⚠️ Token verification failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Auth Models

struct AuthUser: Codable {
    let id: Int
    let email: String
    let name: String
    let avatarUrl: String
    let status: Int
    let expired: Int
}

struct GoogleLoginResponse: Codable {
    let success: Bool
    let token: String
    let user: GoogleLoginUser
    let message: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        user = (try? container.decode(GoogleLoginUser.self, forKey: .user)) ?? GoogleLoginUser.empty
        message = (try? container.decode(String.self, forKey: .message)) ?? ""
    }
}

struct GoogleLoginUser: Codable {
    let id: Int
    let email: String
    let name: String
    let avatarUrl: String
    let status: Int
    let expired: Int

    static let empty = GoogleLoginUser(id: 0, email: "", name: "", avatarUrl: "", status: 0, expired: 0)
}

struct VerifyTokenResponse: Codable {
    let success: Bool
    let token: String
    let message: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        token = (try? container.decode(String.self, forKey: .token)) ?? ""
        message = (try? container.decode(String.self, forKey: .message)) ?? ""
    }
}
