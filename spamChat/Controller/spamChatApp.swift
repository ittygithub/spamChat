//
//  spamChatApp.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import SwiftUI
import UIKit
import Firebase
import UserNotifications
import FirebaseMessaging
@main
struct spamChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            if authService.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    @State private var fcmTokenDevice: String = ""
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GoogleSignInHelper.shared.handleURL(url)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()

        // Configure Google Sign-In
        GoogleSignInHelper.shared.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("⚠️ Running on SIMULATOR - Push notifications and FCM tokens will NOT work!")
        print("💡 To test FCM tokens, you MUST use a REAL DEVICE")
        #else
        print("✅ Running on REAL DEVICE - Push notifications should work")
        #endif
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Permission granted: \(granted)")
            if let error = error {
                print("❌ Permission error: \(error.localizedDescription)")
            }
            if granted {
                DispatchQueue.main.async {
                    print("📱 Registering for remote notifications...")
                    application.registerForRemoteNotifications()
                    print("✅ registerForRemoteNotifications() called")
                }
            } else {
                print("⚠️ Notification permission denied - FCM token won't be available")
            }
        }
        
        // Load saved token if available (don't try to fetch yet - need APNS first)
        if let savedToken = UserDefaults.standard.string(forKey: "FCMToken") {
            fcmTokenDevice = savedToken
            print("📱 Loaded saved FCM token from UserDefaults: \(savedToken.prefix(20))...")
            
            // ✅ Set FCM token for WebSocket (professional chat app pattern)
            WebSocketService.shared.setFCMToken(savedToken)
            print("✅ FCM token set for WebSocket connection")
        } else {
            print("⚠️ No saved FCM token found")
        }
        
        // Initialize PusherManager
        //terminated not working with pusher
        //        PusherManager.shared.connect()
        
        // Reset badge when app becomes active
        setupAppLifecycleObservers()
        
        return true
    }
    
    private func setupAppLifecycleObservers() {
        // Reset badge when app enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App entering foreground - resetting badge and reconnecting WebSocket")
            self?.resetBadgeImmediately()
            
            // ✅ Reconnect WebSocket when app comes to foreground
            // WebSocket will use the FCM token that was already set
            if let token = self?.fcmTokenDevice, !token.isEmpty {
                WebSocketService.shared.setFCMToken(token)
            }
        }
        
        // Reset badge when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App became active - resetting badge")
            self?.resetBadgeImmediately()
        }
        
        // Disconnect WebSocket when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 App entered background - WebSocket will be disconnected by iOS")
            // iOS automatically closes WebSocket connections in background
        }
    }
    
    private func resetBadgeImmediately() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Failed to reset badge: \(error.localizedDescription)")
            } else {
                print("✅ Badge reset to 0")
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // IMPORTANT: Set APNS token FIRST
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs token registered: \(tokenString.prefix(20))...")
        
        // NOW we can fetch FCM token (APNS token is available)
        print("📱 Fetching FCM token (APNS token is now available)...")
        fetchFCMToken { [weak self] token in
            if let token = token {
                print("✅ FCM token received: \(token.prefix(20))...")
                self?.fcmTokenDevice = token
                
                // ✅ Set FCM token for WebSocket (professional chat app pattern)
                WebSocketService.shared.setFCMToken(token)
                print("✅ FCM token set for WebSocket connection")
                
                self?.sendTokenToServer(token)
            } else {
                print("❌ Failed to get FCM token")
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("💡 This is NORMAL on iOS Simulator - use a real device for push notifications")
    }
    
    
    func resetBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Failed to reset badge count locally: \(error.localizedDescription)")
            } else {
                print("Badge count reset locally successfully")
            }
        }
        
        // Only send to server if we have a token (don't try to fetch here)
        guard !fcmTokenDevice.isEmpty else {
            print("FCM token not available yet, will sync when token is received")
            return
        }
        sendTokenToServer(fcmTokenDevice)
    }
    
    private func fetchFCMToken(completion: @escaping (String?) -> Void) {
        print("🔄 Attempting to fetch FCM token...")
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Failed to fetch FCM token: \(error.localizedDescription)")
                let nsError = error as NSError
                print("   Error code: \(nsError.code), domain: \(nsError.domain)")
                if nsError.code == 7 {
                    print("   💡 Error 7 means APNS token not set - this is expected on simulator")
                }
                completion(nil)
            } else if let token = token {
                print("✅ FCM token fetched successfully!")
                print("   Token: \(token.prefix(30))...")
                UserDefaults.standard.set(token, forKey: "FCMToken")
                
                // ✅ Set FCM token for WebSocket (professional chat app pattern)
                WebSocketService.shared.setFCMToken(token)
                print("✅ FCM token set for WebSocket connection")
                
                completion(token)
            } else {
                print("⚠️ FCM token is nil (no error but no token)")
                completion(nil)
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📬 Notification received with userInfo: \(userInfo)")
        
        // Always reset badge to 0 (ignore badge from notification)
        resetBadgeImmediately()
        
        completionHandler(.newData)
    }
    
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 Firebase Messaging delegate called: didReceiveRegistrationToken")
        
        guard let fcmToken = fcmToken else {
            print("❌ FCM token is nil in delegate callback")
            return
        }
        
        print("✅ FCM token received via delegate!")
        print("   Token: \(fcmToken.prefix(30))...")
        
        // Save token
        fcmTokenDevice = fcmToken
        UserDefaults.standard.set(fcmToken, forKey: "FCMToken")
        
        // ✅ Set FCM token for WebSocket (professional chat app pattern)
        WebSocketService.shared.setFCMToken(fcmToken)
        print("✅ FCM token set for WebSocket connection")
        
        // Send to backend
        sendTokenToServer(fcmToken)
    }
    
    
    
    private func sendTokenToServer(_ token: String) {
        print("📤 Sending FCM token to backend server...")
        Task {
            do {
                let response = try await APIService.shared.saveFCMToken(fcmToken: token)
                print("✅ FCM Token saved to backend successfully!")
                print("   Backend response: \(response.message)")
                
                // Reset badge count on success
                UNUserNotificationCenter.current().setBadgeCount(0) { error in
                    if let error = error {
                        print("❌ Failed to reset badge count: \(error.localizedDescription)")
                    } else {
                        print("✅ Badge count reset successfully")
                    }
                }
            } catch let error as APIError {
                print("❌ Failed to save FCM token to backend: \(error.localizedDescription)")
            } catch {
                print("❌ Unexpected error saving FCM token: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📬 Foreground notification: \(notification.request.content.userInfo)")
        
        // Always reset badge to 0 (ignore badge from notification)
        resetBadgeImmediately()
        
        // Show the notification as a banner even when the app is in the foreground
        completionHandler([.banner, .sound])  // Removed .badge to prevent badge updates
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 User tapped notification: \(response.notification.request.content.userInfo)")
        
        // Reset badge when user opens app from notification
        resetBadgeImmediately()
        
        completionHandler()
    }
    
    
}
