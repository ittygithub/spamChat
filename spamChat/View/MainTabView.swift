import SwiftUI

struct MainTabView: View {
    var isDuressMode: Bool = false

    var body: some View {
        CustomTabView(isDuressMode: isDuressMode)
    }
}

struct CustomTabView: View {
    var isDuressMode: Bool = false
    @State private var selectedTab: Int = 0
    @State private var regularTabSize: CGFloat = 30
    @State private var tabBarHeight: CGFloat = 60
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var webSocketService = WebSocketService.shared

    // Recheck state
    @State private var showRecheckSheet = false
    @State private var showRecheckOverdue = false
    @State private var showRecheckWarning = false
    @State private var recheckWarningText = ""
    @State private var showRecheckSuccess = false
    @State private var showRecheckCountdown = false
    @State private var recheckCountdownValue = 5
    @State private var recheckCountdownTimer: Timer?
    @State private var recheckHasShownCountdown = false
    private let recheckTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let manager = AppPasswordManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SpamChatListView(isDuressMode: isDuressMode)
                    .tag(0)

                SettingView(isDuressMode: isDuressMode)
                    .tag(1)
            }
            .tabViewStyle(DefaultTabViewStyle())
            .onChange(of: selectedTab) { oldValue, newValue in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    print("🔍 App became active")
                    if !webSocketService.isConnected {
                        print("🔄 Reconnecting WebSocket...")
                    }
                    // Check recheck on foreground
                    if !isDuressMode { checkRecheckStatus() }
                case .background:
                    print("📱 App went to background - keeping WebSocket connected")
                case .inactive:
                    print("⏸️ App became inactive")
                @unknown default:
                    break
                }
            }
            .onAppear {
                setupKeyboardObservers()
                if !isDuressMode { checkRecheckStatus() }
            }
            .onDisappear {
                removeKeyboardObservers()
            }
            .onReceive(recheckTimer) { _ in
                guard !isDuressMode else { return }
                checkRecheckStatus()
            }
            
            // Custom Tab Bar
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 0) {
                    TabButtonView(
                        systemName: "message.badge.fill",
                        title: "Spam Chats",
                        isSelected: selectedTab == 0,
                        size: regularTabSize
                    ) {
                        selectedTab = 0
                    }
                    .frame(maxWidth: .infinity)
                    
                    TabButtonView(
                        systemName: "gearshape.fill",
                        title: "Settings",
                        isSelected: selectedTab == 1,
                        size: regularTabSize
                    ) {
                        selectedTab = 1
                    }
                    .frame(maxWidth: .infinity)
                    
                }
                .padding(.top, 8)
                .padding(.bottom, UIApplication.safeAreaBottom > 0 ? 8 : 12)
                .frame(height: tabBarHeight)
                .background(tabBarBackground)
            }
            .offset(y: selectedTab == 0 && keyboardHeight > 0 ? keyboardHeight + tabBarHeight : 0)
            .animation(.easeOut(duration: 0.3), value: keyboardHeight)
            // Recheck warning banner (top)
            if showRecheckWarning && !isDuressMode {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 18))
                            .foregroundColor(manager.isFinalWarning ? .orange : .blue)

                        Text("Password recheck in \(recheckWarningText)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        // "Later" only for early reminder, not final warning
                        if !manager.isFinalWarning {
                            Button(action: {
                                manager.earlyReminderDismissed = true
                                withAnimation { showRecheckWarning = false }
                            }) {
                                Text("Later")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 4)
                        }

                        Button(action: { showRecheckSheet = true }) {
                            Text("Verify now")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background((manager.isFinalWarning ? Color.orange : Color.blue).opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Recheck countdown overlay
            if showRecheckCountdown && !isDuressMode {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 6)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: CGFloat(recheckCountdownValue) / 5.0)
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: recheckCountdownValue)

                            Text("\(recheckCountdownValue)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text("Password Recheck Required")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Verification screen opening...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }

            // Recheck success toast
            if showRecheckSuccess {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Password verified. Next check in \(manager.recheckRemainingText).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(10)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showRecheckSheet) {
            PasswordRecheckView(
                deadline: manager.nextRecheckDate,
                isOverdue: false,
                onVerified: {
                    showRecheckSheet = false
                    showRecheckWarning = false
                    withAnimation { showRecheckSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { showRecheckSuccess = false }
                    }
                },
                onDismiss: {
                    showRecheckSheet = false
                }
            )
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showRecheckOverdue) {
            PasswordRecheckView(
                deadline: manager.nextRecheckDate,
                isOverdue: true,
                onVerified: {
                    showRecheckOverdue = false
                    showRecheckWarning = false
                    withAnimation { showRecheckSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { showRecheckSuccess = false }
                    }
                },
                onDismiss: {
                    // Cannot dismiss when overdue — do nothing
                }
            )
        }
    }
    
   
    // MARK: - Recheck Logic

    private func checkRecheckStatus() {
        guard manager.nextRecheckDate != nil else { return }

        if manager.isRecheckDue {
            // Deadline passed — force recheck
            showRecheckWarning = false
            showRecheckSheet = false
            if !showRecheckOverdue && !showRecheckCountdown {
                if recheckHasShownCountdown {
                    // Already shown countdown before (e.g. re-entering app) — go straight to fullscreen
                    showRecheckOverdue = true
                } else {
                    // First time detecting overdue — show countdown
                    startRecheckCountdown()
                }
            }
        } else if manager.isRecheckWarning {
            // Within warning window — show banner, user can tap to open sheet
            recheckWarningText = manager.recheckRemainingText
            if !showRecheckWarning {
                withAnimation(.easeInOut(duration: 0.3)) { showRecheckWarning = true }
            }
        } else {
            showRecheckWarning = false
        }
    }

    private func startRecheckCountdown() {
        recheckCountdownValue = 5
        recheckHasShownCountdown = true
        withAnimation { showRecheckCountdown = true }

        recheckCountdownTimer?.invalidate()
        recheckCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                if recheckCountdownValue > 1 {
                    withAnimation { recheckCountdownValue -= 1 }
                } else {
                    timer.invalidate()
                    recheckCountdownTimer = nil
                    withAnimation { showRecheckCountdown = false }
                    showRecheckOverdue = true
                }
            }
        }
    }

    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // Tab bar background that adapts to color scheme
    private var tabBarBackground: some View {
        Group {
            if colorScheme == .dark {
                Color.black
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -3)
            } else {
                Color(UIColor.systemBackground)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -3)
            }
        }
    }
}

// Custom Tab Button Component
struct TabButtonView: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let size: CGFloat
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: isSelected ? size * 0.7 : size * 0.6))
                    .foregroundColor(isSelected ? .blue : colorScheme == .dark ? .gray.opacity(0.8) : .gray)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .blue : colorScheme == .dark ? .gray.opacity(0.8) : .gray)
            }
            .frame(width: size * 1.5, height: size)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Safe area helper to handle bottom insets correctly
extension UIApplication {
    static var safeAreaBottom: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
}
