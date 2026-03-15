//
//  AppPasswordManager.swift
//  spamChat
//

import Foundation
import Security

class AppPasswordManager {
    static let shared = AppPasswordManager()

    private let serviceName = "com.spamchat.apppassword"
    private let appPasswordKey = "app_password"
    private let duressPasswordKey = "duress_password"

    private init() {}

    // MARK: - Public API

    var isPasswordRegistered: Bool {
        return getPassword(for: appPasswordKey) != nil
    }

    func registerPasswords(appPassword: String, duressPassword: String) -> Bool {
        let savedApp = savePassword(appPassword, for: appPasswordKey)
        let savedDuress = savePassword(duressPassword, for: duressPasswordKey)
        return savedApp && savedDuress
    }

    /// Returns: .appPassword, .duressPassword, or .invalid
    func verifyPassword(_ password: String) -> PasswordResult {
        if let appPwd = getPassword(for: appPasswordKey), password == appPwd {
            return .appPassword
        }
        if let duressPwd = getPassword(for: duressPasswordKey), password == duressPwd {
            return .duressPassword
        }
        return .invalid
    }

    func clearPasswords() {
        deletePassword(for: appPasswordKey)
        deletePassword(for: duressPasswordKey)
        resetLockout()
        clearRecheckSchedule()
    }

    // MARK: - Lockout Management

    private let failedAttemptsKey = "pwd_failed_attempts"
    private let lockoutUntilKey = "pwd_lockout_until"
    private let lockoutLevelKey = "pwd_lockout_level"

    /// Progressive lockout durations in seconds: 1min, 5min, 10min, 30min, 1hr, 5hr
    private let lockoutDurations: [TimeInterval] = [60, 300, 600, 1800, 3600, 18000]

    var failedAttempts: Int {
        get { UserDefaults.standard.integer(forKey: failedAttemptsKey) }
        set { UserDefaults.standard.set(newValue, forKey: failedAttemptsKey) }
    }

    var lockoutLevel: Int {
        get { UserDefaults.standard.integer(forKey: lockoutLevelKey) }
        set { UserDefaults.standard.set(newValue, forKey: lockoutLevelKey) }
    }

    var lockoutUntil: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: lockoutUntilKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lockoutUntilKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lockoutUntilKey)
            }
        }
    }

    var isLockedOut: Bool {
        guard Env.shared.isLockoutEnabled else { return false }
        guard let until = lockoutUntil else { return false }
        return Date() < until
    }

    var remainingLockoutSeconds: Int {
        guard let until = lockoutUntil else { return 0 }
        return max(0, Int(until.timeIntervalSinceNow))
    }

    /// Call on failed password attempt. Returns the lockout duration if lockout triggered, nil otherwise.
    func recordFailedAttempt() -> TimeInterval? {
        guard Env.shared.isLockoutEnabled else { return nil }

        failedAttempts += 1

        // Trigger lockout every 3 failed attempts
        if failedAttempts % 3 == 0 {
            let level = min(lockoutLevel, lockoutDurations.count - 1)
            let duration = lockoutDurations[level]
            lockoutUntil = Date().addingTimeInterval(duration)
            lockoutLevel += 1
            return duration
        }
        return nil
    }

    func resetLockout() {
        failedAttempts = 0
        lockoutLevel = 0
        lockoutUntil = nil
    }

    // MARK: - Periodic Recheck

    private let lastVerifiedKey = "pwd_last_verified"
    private let nextRecheckKey = "pwd_next_recheck"

    private let earlyReminderDismissedKey = "pwd_early_reminder_dismissed"

    /// Recheck deadline interval: from Env days config, or override seconds for testing
    private var recheckInterval: TimeInterval {
        let override = Env.shared.recheckIntervalOverride
        if override > 0 { return override }
        return Env.shared.recheckDeadlineDays * 86400
    }

    /// Early reminder threshold: from Env days config, or 40% of override for testing
    private var earlyReminderThreshold: TimeInterval {
        let override = Env.shared.recheckIntervalOverride
        if override > 0 { return override * 0.4 }
        return Env.shared.recheckEarlyReminderDays * 86400
    }

    var lastVerifiedDate: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: lastVerifiedKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastVerifiedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastVerifiedKey)
            }
        }
    }

    var nextRecheckDate: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: nextRecheckKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: nextRecheckKey)
            } else {
                UserDefaults.standard.removeObject(forKey: nextRecheckKey)
            }
        }
    }

    /// Schedule next recheck from now
    func scheduleNextRecheck() {
        lastVerifiedDate = Date()
        nextRecheckDate = Date().addingTimeInterval(recheckInterval)
        earlyReminderDismissed = false
    }

    /// Whether user tapped "Later" on the early (day 4) reminder
    var earlyReminderDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: earlyReminderDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: earlyReminderDismissedKey) }
    }

    /// True if recheck deadline has passed
    var isRecheckDue: Bool {
        guard let next = nextRecheckDate else { return false }
        return Date() >= next
    }

    /// Seconds until recheck is due (negative if overdue)
    var timeUntilRecheck: TimeInterval {
        guard let next = nextRecheckDate else { return .infinity }
        return next.timeIntervalSinceNow
    }

    /// True if early reminder should show (4+ days elapsed, user hasn't dismissed yet)
    var isEarlyReminder: Bool {
        guard let lastVerified = lastVerifiedDate else { return false }
        let elapsed = Date().timeIntervalSince(lastVerified)
        let remaining = timeUntilRecheck
        return elapsed >= earlyReminderThreshold && remaining > 0 && !earlyReminderDismissed
    }

    /// True if within 1 hour of deadline (or 10% of override interval for testing)
    var isFinalWarning: Bool {
        let remaining = timeUntilRecheck
        let override = Env.shared.recheckIntervalOverride
        let threshold = override > 0 ? override * 0.1 : 3600.0 // 1 hour or 10% of override
        return remaining > 0 && remaining <= threshold
    }

    /// True if banner should show (either early reminder or final warning)
    var isRecheckWarning: Bool {
        return isEarlyReminder || isFinalWarning
    }

    /// Formatted remaining time for display
    var recheckRemainingText: String {
        let remaining = timeUntilRecheck
        if remaining <= 0 { return "now" }
        if remaining > 86400 {
            let days = Int(remaining / 86400)
            return "\(days) day\(days == 1 ? "" : "s")"
        }
        if remaining > 3600 {
            let hours = Int(remaining / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        if remaining > 60 {
            let minutes = Int(remaining / 60)
            return "\(minutes) min"
        }
        let seconds = max(1, Int(remaining))
        return "\(seconds) sec"
    }

    /// Verify both passwords for recheck. Returns true only if both correct.
    func verifyBothPasswords(appPassword: String, duressPassword: String) -> Bool {
        guard let storedApp = getPassword(for: appPasswordKey),
              let storedDuress = getPassword(for: duressPasswordKey) else { return false }
        return appPassword == storedApp && duressPassword == storedDuress
    }

    func clearRecheckSchedule() {
        lastVerifiedDate = nil
        nextRecheckDate = nil
        earlyReminderDismissed = false
    }

    // MARK: - Keychain Operations

    private func savePassword(_ password: String, for key: String) -> Bool {
        deletePassword(for: key)

        guard let data = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getPassword(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deletePassword(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum PasswordResult {
        case appPassword
        case duressPassword
        case invalid
    }
}
