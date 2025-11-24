import SwiftUI

struct MainTabView: View {
    
    var body: some View {
        CustomTabView()
    }
}

struct CustomTabView: View {
    @State private var selectedTab: Int = 0
    @State private var regularTabSize: CGFloat = 30 // Tab icon size
    @State private var tabBarHeight: CGFloat = 60
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var webSocketService = WebSocketService.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SpamChatListView()
                    .tag(0)

                SettingView()
                    .tag(1)
            }
            .tabViewStyle(DefaultTabViewStyle())
            .onChange(of: selectedTab) { oldValue, newValue in
                // Dismiss keyboard when switching tabs
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Handle app lifecycle for WebSocket
                switch newPhase {
                case .active:
                    print("🔍 App became active")
                    // Reconnect WebSocket if disconnected
                    if !webSocketService.isConnected {
                        print("🔄 Reconnecting WebSocket...")
                    }
                case .background:
                    print("📱 App went to background - keeping WebSocket connected")
                    // Keep connection alive in background for notifications
                case .inactive:
                    print("⏸️ App became inactive")
                @unknown default:
                    break
                }
            }
            .onAppear {
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
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
        }
        .ignoresSafeArea(.keyboard)
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
        return UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}
