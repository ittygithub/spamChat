//
//  SpamChatListView.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import SwiftUI
import Combine

enum ActionSheetType {
    case lockChat
    case lockAccount
}

// Wrapper struct for sheet presentation
struct SheetItem: Identifiable {
    let id = UUID()
    let chat: SpamChatItem
    let type: ActionSheetType
}

struct SpamChatListView: View {
    @State private var spamChats: [SpamChatItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sheetItem: SheetItem?
    @StateObject private var webSocketService = WebSocketService.shared
    @State private var newlyAddedChatIds: Set<Int> = []
    @State private var animatingChatId: Int? = nil
    
    // Pagination state
    @State private var currentOffset = 0
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    @State private var showScrollToBottom = false
    @State private var shouldScrollToBottom = false
    @State private var hasInitiallyLoaded = false
    private let pageSize = 50
    
    // Auto-refresh timer (every 5 minutes)
    private let autoRefreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    @State private var lastRefreshTime = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading spam chats...")
                        .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red.opacity(0.5))
                        Text("Error")
                            .font(.title2)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            fetchSpamChats()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if spamChats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No Spam Chats")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Spam messages will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding()
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        ScrollViewReader { scrollProxy in
                            List {
                                // Loading indicator at the top for loading older messages
                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding()
                                        Spacer()
                                    }
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .id("loading")
                                }
                                
                                ForEach(Array(spamChats.enumerated()), id: \.element.id) { index, chat in
                                    SpamChatGroupView(
                                        chat: chat,
                                        onLockChat: {
                                            sheetItem = SheetItem(chat: chat, type: .lockChat)
                                        },
                                        onLockAccount: {
                                            sheetItem = SheetItem(chat: chat, type: .lockAccount)
                                        },
                                        isNew: newlyAddedChatIds.contains(chat.id)
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .overlay(
                                        // New message highlight overlay
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(newlyAddedChatIds.contains(chat.id) ? Color.blue : Color.clear, lineWidth: 2)
                                            .opacity(newlyAddedChatIds.contains(chat.id) ? 0.6 : 0)
                                    )
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0), value: spamChats.map { $0.id })
                                    .id(index == spamChats.count - 1 ? "bottom" : "item_\(chat.id)")
                                    .onAppear {
                                        // Show scroll to bottom button when scrolled up from bottom
                                        if index < spamChats.count - 6 {
                                            showScrollToBottom = true
                                        } else if index >= spamChats.count - 3 {
                                            showScrollToBottom = false
                                        }
                                        
                                        // Load more older messages when scrolling UP and reaching the top
                                        // Only load if we've completed the initial load (prevent auto-loading on first render)
                                        if hasInitiallyLoaded && index < 5 && !isLoadingMore && hasMoreData {
                                            loadMoreChats()
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spamChats.count)
                            .refreshable {
                                await refreshData()
                            }
                            .onChange(of: shouldScrollToBottom) {
                                if shouldScrollToBottom {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            shouldScrollToBottom = false
                                        }
                                    }
                                }
                            }
                            .onAppear {
                                // Ensure we scroll to bottom when the ScrollView appears
                                if !spamChats.isEmpty {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                            
                            // Scroll to bottom button
                            if showScrollToBottom {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                    // Trigger haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.blue)
                                        .background(
                                            Circle()
                                                .fill(Color(UIColor.systemBackground))
                                                .frame(width: 36, height: 36)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showScrollToBottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spam Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(webSocketService.isConnected ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(webSocketService.isConnected ? "Live" : "Offline")
                                .font(.caption)
                                .foregroundColor(webSocketService.isConnected ? .green : .gray)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchSpamChats) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if spamChats.isEmpty {
                    fetchSpamChats()
                } else {
                    // Scroll to bottom when view appears if we have data
                    shouldScrollToBottom = true
                }
                // Only setup WebSocket if not already connected
                if !webSocketService.isConnected {
                    setupWebSocket()
                }
                // Record initial load time
                lastRefreshTime = Date()
            }
            .onReceive(autoRefreshTimer) { _ in
                // Auto-refresh every 5 minutes
                lastRefreshTime = Date()
                
                // Perform silent refresh without showing loading indicator
                Task {
                    await refreshData()
                }
            }
            .sheet(item: $sheetItem) { item in
                Group {
                    if item.type == .lockChat {
                        LockChatOptionsSheet(
                            chat: item.chat,
                            onDismiss: { newStatus in
                                sheetItem = nil
                                // Update only this chat's status locally
                                if let newStatus = newStatus {
                                    updateChatStatusLocally(chatId: item.chat.id, newChatStatus: newStatus)
                                }
                            }
                        )
                    } else {
                        LockAccountOptionsSheet(
                            chat: item.chat,
                            onDismiss: { newStatus in
                                sheetItem = nil
                                // Update only this chat's status locally
                                if let newStatus = newStatus {
                                    updateChatStatusLocally(chatId: item.chat.id, newAccountStatus: newStatus)
                                }
                            }
                        )
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // Helper function to update chat status locally without full reload
    private func updateChatStatusLocally(chatId: Int, newChatStatus: String? = nil, newAccountStatus: String? = nil) {
        if let index = spamChats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = spamChats[index]
            if let newChatStatus = newChatStatus {
                updatedChat.chatStatus = newChatStatus
            }
            if let newAccountStatus = newAccountStatus {
                updatedChat.accountStatus = newAccountStatus
            }
            spamChats[index] = updatedChat
        }
    }
    
    private func fetchSpamChats() {
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        hasMoreData = true
        hasInitiallyLoaded = false
        lastRefreshTime = Date()
        
        Task {
            do {
                let response = try await APIService.shared.getSpamChatList(limit: pageSize, offset: 0)
                await MainActor.run {
                    let rawChats = response.data.chats
                    
                    // Check if backend is sending ASC or DESC
                    let firstId = rawChats.first?.id ?? 0
                    let lastId = rawChats.last?.id ?? 0
                    let isBackendAscending = firstId < lastId
                    
                    // For chat UI: We need oldest at TOP (index 0), newest at BOTTOM (last index)
                    // If backend sends ASC [1,2,3...]: already correct order
                    // If backend sends DESC [3,2,1...]: need to reverse to [1,2,3...]
                    spamChats = isBackendAscending ? rawChats : rawChats.reversed()
                    
                    currentOffset = pageSize
                    hasMoreData = rawChats.count >= pageSize
                    isLoading = false
                    
                    // Mark as initially loaded to allow pagination
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hasInitiallyLoaded = true
                    }
                    
                    // Scroll to bottom after loading (like a normal chat)
                    shouldScrollToBottom = true
                }
            } catch let error as APIError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    print("❌ Error fetching chats: \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    isLoading = false
                    print("❌ Error fetching chats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadMoreChats() {
        guard !isLoadingMore && hasMoreData else {
            return
        }
        
        isLoadingMore = true
        
        Task {
            do {
                let response = try await APIService.shared.getSpamChatList(limit: pageSize, offset: currentOffset)
                await MainActor.run {
                    let newChats = response.data.chats
                    
                    // Check backend order and normalize to oldest→newest
                    let isBackendAscending = (newChats.first?.id ?? 0) < (newChats.last?.id ?? 0)
                    let normalizedChats = isBackendAscending ? newChats : newChats.reversed()
                    
                    // Filter out duplicates
                    let uniqueNewChats = normalizedChats.filter { newChat in
                        !spamChats.contains(where: { $0.id == newChat.id })
                    }
                    
                    if !uniqueNewChats.isEmpty {
                        // Insert older messages at the TOP (index 0)
                        spamChats.insert(contentsOf: uniqueNewChats, at: 0)
                    }
                    
                    currentOffset += pageSize
                    hasMoreData = newChats.count >= pageSize
                    isLoadingMore = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    print("❌ Error loading more chats: \(error.localizedDescription)")
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error loading more chats: \(error.localizedDescription)")
                    isLoadingMore = false
                }
            }
        }
    }
    
    private func refreshData() async {
        currentOffset = 0
        hasMoreData = true
        hasInitiallyLoaded = false
        
        await MainActor.run {
            lastRefreshTime = Date()
        }
        
        do {
            let response = try await APIService.shared.getSpamChatList(limit: pageSize, offset: 0)
            await MainActor.run {
                let rawChats = response.data.chats
                
                // Check backend order and normalize to oldest→newest
                let isBackendAscending = (rawChats.first?.id ?? 0) < (rawChats.last?.id ?? 0)
                spamChats = isBackendAscending ? rawChats : rawChats.reversed()
                
                currentOffset = pageSize
                hasMoreData = rawChats.count >= pageSize
                errorMessage = nil
                
                // Re-enable pagination after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasInitiallyLoaded = true
                }
                
                // Scroll to bottom after refresh
                shouldScrollToBottom = true
            }
        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupWebSocket() {
        // Handle connection established (when welcome message is received)
        webSocketService.onConnected = {
            webSocketService.subscribeToAgency("1")
        }
        
        // Handle new spam chat notifications
        webSocketService.onNewSpamChat = { [self] notification in
            // Convert notification to SpamChatItem
            let newChat = convertNotificationToSpamChatItem(notification)
            
            // Check if this chat already exists (avoid duplicates)
            if !spamChats.contains(where: { $0.id == newChat.id }) {
                // Trigger haptic feedback for new message
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Add visual highlight animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    // Append at the end of the array (bottom of the list) like normal chat
                    spamChats.append(newChat)
                    
                    // Mark as newly added for highlight effect
                    newlyAddedChatIds.insert(newChat.id)
                }
                
                // Auto-scroll to bottom for new messages
                shouldScrollToBottom = true
                
                // Remove highlight after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        _ = newlyAddedChatIds.remove(newChat.id)
                    }
                }
                
                // Show brief notification badge
                animatingChatId = newChat.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        if animatingChatId == newChat.id {
                            animatingChatId = nil
                        }
                    }
                }
            }
        }
        
        // Handle status updates
        webSocketService.onStatusUpdate = { [self] update in
            // Find and update the chat in the list
            if let index = spamChats.firstIndex(where: { $0.userId == update.userId }) {
                // Update the status fields
                var mutableChat = spamChats[index]
                mutableChat.chatStatus = update.chatStatus
                mutableChat.accountStatus = update.accountStatus
                if let totalMessages = update.totalMessages {
                    mutableChat.totalMessages = totalMessages
                }
                
                spamChats[index] = mutableChat
            }
        }
        
        // Connect to WebSocket (will trigger onConnected callback when welcome message is received)
        webSocketService.connect(agencyId: "1")
    }
    
    private func convertNotificationToSpamChatItem(_ notification: SpamChatNotification) -> SpamChatItem {
        // Convert wallet string to Double
        let walletValue = Double(notification.wallet)
        
        // Convert agencyId string to Int
        let agencyIdValue = Int(notification.agencyId) ?? 1
        
        return SpamChatItem(
            id: notification.id,
            userId: notification.userId,
            username: notification.username,
            message: notification.message,
            status: notification.status,
            chatStatus: notification.chatStatus,
            accountStatus: notification.accountStatus,
            createdAt: notification.createdAt,
            updatedAt: notification.createdAt, // Use createdAt as updatedAt if not provided
            agencyId: agencyIdValue,
            wallet: walletValue,
            projectName: notification.projectName,
            processedAt: nil,
            channel: notification.channel,
            platform: notification.platform,
            displayName: notification.username,
            timestamp: notification.createdAt,
            totalMessages: nil,  // Not provided in real-time notifications
            spamType: notification.spamType,
            spamScore: notification.spamScore,
            gameId: notification.gameId
        )
    }
}

// MARK: - Spam Chat Group View

struct SpamChatGroupView: View {
    let chat: SpamChatItem
    let onLockChat: () -> Void
    let onLockAccount: () -> Void
    var isNew: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with project name and timestamp
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(chat.projectName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // NEW badge for recently added messages
                        if isNew {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("NEW")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    Text(chat.displayName ?? chat.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(chat.timestamp ?? chat.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // User Info
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(label: "User ID", value: chat.userId)
                InfoRow(label: "Agency ID", value: "\(chat.agencyId)")
                InfoRow(label: "Wallet", value: formatWallet(chat.wallet))
                if let totalMessages = chat.totalMessages {
                    InfoRow(label: "Total Spam", value: "\(totalMessages) messages")
                }
            }
            
            // Spam Detection Info (if available)
            if chat.spamScore != nil || chat.spamType != nil {
                SpamScoreView(spamType: chat.spamType, spamScore: chat.spamScore, gameId: chat.gameId)
            }
            
            // Message
            VStack(alignment: .leading, spacing: 6) {
                Text("Message:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(chat.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.98))
                    )
            }
            .padding(.vertical, 4)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Check chat_status for Lock/Unlock Chat button
                if chat.chatStatus.uppercased().contains("BANNED") || chat.chatStatus.uppercased().contains("LOCKED") {
                    Button(action: onLockChat) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Unlock Chat")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: onLockChat) {
                        HStack {
                            Image(systemName: "message.badge.fill")
                            Text("Lock Chat")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Check account_status for Lock/Unlock Account button
                if chat.accountStatus.uppercased().contains("BANNED") || chat.accountStatus.uppercased().contains("LOCKED") {
                    Button(action: onLockAccount) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("Unlock Account")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: onLockAccount) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                            Text("Lock Account")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
        
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try parsing with fractional seconds first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = isoFormatter.date(from: dateString)
        
        // If that fails, try without fractional seconds
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        
        // If still fails, try standard DateFormatter
        if date == nil {
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            date = fallbackFormatter.date(from: dateString)
        }
        
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            // Display in user's local timezone
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func formatWallet(_ amount: Double?) -> String {
        guard let amount = amount else {
            return "N/A"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Spam Score View

struct SpamScoreView: View {
    let spamType: String?
    let spamScore: Double?
    let gameId: String?
    @Environment(\.colorScheme) private var colorScheme
    
    private var scoreColor: Color {
        guard let score = spamScore else { return .gray }
        if score >= 0.9 { return .red }
        if score >= 0.7 { return .orange }
        if score >= 0.5 { return .yellow }
        return .green
    }
    
    private var scorePercentage: String {
        guard let score = spamScore else { return "N/A" }
        return String(format: "%.1f%%", score * 100)
    }
    
    private var severityText: String {
        guard let score = spamScore else { return "Unknown" }
        if score >= 0.9 { return "Critical" }
        if score >= 0.7 { return "High" }
        if score >= 0.5 { return "Medium" }
        return "Low"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(scoreColor)
                    .font(.system(size: 14))
                
                Text("Spam Detection")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Spam Score with progress indicator
                if let score = spamScore {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Score")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            // Circular progress indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                    .frame(width: 28, height: 28)
                                
                                Circle()
                                    .trim(from: 0, to: score)
                                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 28, height: 28)
                                    .rotationEffect(.degrees(-90))
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(scorePercentage)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(scoreColor)
                                
                                Text(severityText)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(scoreColor.opacity(0.1))
                    )
                }
                
                // Spam Type badge
                if let type = spamType, !type.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(formatSpamType(type))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.purple)
                            )
                    }
                }
                
                // Game ID (if available)
                if let game = gameId, !game.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(game)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.9))
                            )
                    }
                }
                
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(scoreColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatSpamType(_ type: String) -> String {
        // Convert snake_case to Title Case
        return type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Lock Chat Options Sheet

struct LockChatOptionsSheet: View {
    let chat: SpamChatItem
    let onDismiss: (String?) -> Void  // Now accepts optional status string
    
    @State private var selectedStatus: LockChatStatus = .bannedForever
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Success"
    @State private var isError = false
    
    // Check if this is an unlock action (current chat status is banned)
    private var isUnlockAction: Bool {
        chat.chatStatus.uppercased().contains("BANNED") || chat.chatStatus.uppercased().contains("LOCKED")
    }
    
    private var availableStatuses: [LockChatStatus] {
        isUnlockAction ? LockChatStatus.allCases : LockChatStatus.allCases.filter { $0 != .active }
    }
    
    init(chat: SpamChatItem, onDismiss: @escaping (String?) -> Void) {
        self.chat = chat
        self.onDismiss = onDismiss
        // Pre-select current status if it's a banned status, otherwise default to bannedForever
        if let currentStatus = LockChatStatus(rawValue: chat.chatStatus), 
           currentStatus != .active {
            _selectedStatus = State(initialValue: currentStatus)
        } else {
            _selectedStatus = State(initialValue: .bannedForever)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(alertOverlay)
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                onDismiss(nil)
            }
            .disabled(isSubmitting)
            
            Spacer()
            
            Text(isUnlockAction ? "Unlock Chat" : "Lock Chat")
                .font(.headline)
            
            Spacer()
            
            Button("Cancel") {
                onDismiss(nil)
            }
            .disabled(isSubmitting)
            .opacity(0)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                userInfoView
                statusOptionsView
                submitButton
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User: \(chat.username)")
                .font(.headline)
            Text("User ID: \(chat.userId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isUnlockAction ? "Change Chat Status:" : "Select Lock Chat Status:")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(availableStatuses, id: \.self) { status in
                statusButton(for: status)
            }
        }
    }
    
    private func statusButton(for status: LockChatStatus) -> some View {
        Button(action: {
            selectedStatus = status
        }) {
            HStack(spacing: 12) {
                Image(systemName: selectedStatus == status ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedStatus == status ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(status.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedStatus == status ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedStatus == status ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var submitButton: some View {
        Button(action: submitLockChat) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isSubmitting ? "Submitting..." : "Submit")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSubmitting ? Color.gray : (selectedStatus == .active ? Color.green : Color.orange))
            .cornerRadius(10)
        }
        .disabled(isSubmitting)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var alertOverlay: some View {
        if showAlert {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss on background tap for errors only
                        if isError {
                            showAlert = false
                            onDismiss(nil)
                        }
                    }
                
                VStack(spacing: 0) {
                    // Icon at top
                    ZStack {
                        Circle()
                            .fill(isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(isError ? .red : .green)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    // Title
                    Text(alertTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    
                    // Message
                    Text(alertMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    
                    // Divider
                    Divider()
                    
                    // OK Button
                    Button(action: {
                        showAlert = false
                        if !isError {
                            onDismiss(selectedStatus.rawValue)
                        } else {
                            onDismiss(nil)
                        }
                    }) {
                        Text("OK")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isError ? .red : .green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .frame(width: 320)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
                .scaleEffect(showAlert ? 1 : 0.8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAlert)
            }
        }
    }
    
    private func submitLockChat() {
        // Extract numeric userId from string (e.g., "test_user_203" → 203)
        let userIdNumber: Int
        if let directInt = Int(chat.userId) {
            // If userId is already a number string like "203"
            userIdNumber = directInt
        } else if chat.userId.contains("_") {
            // Extract number from format like "test_user_203"
            let components = chat.userId.components(separatedBy: "_")
            guard let lastComponent = components.last, let extractedId = Int(lastComponent) else {
                isError = true
                alertTitle = "Error"
                alertMessage = "Invalid user ID format: \(chat.userId)"
                showAlert = true
                return
            }
            userIdNumber = extractedId
        } else {
            isError = true
            alertTitle = "Error"
            alertMessage = "Invalid user ID format: \(chat.userId)"
            showAlert = true
            return
        }
        
        let agencyId = "\(chat.agencyId)"
        isSubmitting = true
        
        Task {
            do {
                let _ = try await APIService.shared.lockChat(
                    userId: userIdNumber,
                    agencyId: agencyId,
                    status: selectedStatus
                )
                
                await MainActor.run {
                    isSubmitting = false
                    isError = false
                    alertTitle = "Success"
                    alertMessage = "Chat status updated to \(selectedStatus.displayName)"
                    showAlert = true
                }
            } catch let error as APIError {
                await MainActor.run {
                    isSubmitting = false
                    isError = true
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isError = true
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Lock Account Options Sheet

struct LockAccountOptionsSheet: View {
    let chat: SpamChatItem
    let onDismiss: (String?) -> Void  // Now accepts optional status string
    
    @State private var selectedStatus: AccountStatus = .bannedForever
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Success"
    @State private var isError = false
    
    // Check if this is an unlock action (current account status is banned)
    private var isUnlockAction: Bool {
        chat.accountStatus.uppercased().contains("BANNED") || chat.accountStatus.uppercased().contains("LOCKED")
    }
    
    private var availableStatuses: [AccountStatus] {
        isUnlockAction ? AccountStatus.allCases : AccountStatus.allCases.filter { $0 != .active }
    }
    
    init(chat: SpamChatItem, onDismiss: @escaping (String?) -> Void) {
        self.chat = chat
        self.onDismiss = onDismiss
        // Pre-select current status if it's a banned status, otherwise default to bannedForever
        if let currentStatus = AccountStatus(rawValue: chat.accountStatus), 
           currentStatus != .active {
            _selectedStatus = State(initialValue: currentStatus)
        } else {
            _selectedStatus = State(initialValue: .bannedForever)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(alertOverlay)
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                onDismiss(nil)
            }
            .disabled(isSubmitting)
            
            Spacer()
            
            Text(isUnlockAction ? "Unlock Account" : "Lock Account")
                .font(.headline)
            
            Spacer()
            
            Button("Cancel") {
                onDismiss(nil)
            }
            .disabled(isSubmitting)
            .opacity(0)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                userInfoView
                statusOptionsView
                submitButton
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User: \(chat.username)")
                .font(.headline)
            Text("User ID: \(chat.userId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isUnlockAction ? "Change Account Status:" : "Select Account Status:")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(availableStatuses, id: \.self) { status in
                statusButton(for: status)
            }
        }
    }
    
    private func statusButton(for status: AccountStatus) -> some View {
        Button(action: {
            selectedStatus = status
        }) {
            HStack(spacing: 12) {
                Image(systemName: selectedStatus == status ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedStatus == status ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(status.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedStatus == status ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedStatus == status ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var submitButton: some View {
        Button(action: submitLockAccount) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(isSubmitting ? "Submitting..." : "Submit")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSubmitting ? Color.gray : (selectedStatus == .active ? Color.green : Color.red))
            .cornerRadius(10)
        }
        .disabled(isSubmitting)
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var alertOverlay: some View {
        if showAlert {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss on background tap for errors only
                        if isError {
                            showAlert = false
                            onDismiss(nil)
                        }
                    }
                
                VStack(spacing: 0) {
                    // Icon at top
                    ZStack {
                        Circle()
                            .fill(isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(isError ? .red : .green)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    // Title
                    Text(alertTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    
                    // Message
                    Text(alertMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    
                    // Divider
                    Divider()
                    
                    // OK Button
                    Button(action: {
                        showAlert = false
                        if !isError {
                            onDismiss(selectedStatus.rawValue)
                        } else {
                            onDismiss(nil)
                        }
                    }) {
                        Text("OK")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isError ? .red : .green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .frame(width: 320)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
                .scaleEffect(showAlert ? 1 : 0.8)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAlert)
            }
        }
    }
    
    private func submitLockAccount() {
        // Extract numeric userId from string (e.g., "test_user_203" → 203)
        let userIdNumber: Int
        if let directInt = Int(chat.userId) {
            // If userId is already a number string like "203"
            userIdNumber = directInt
        } else if chat.userId.contains("_") {
            // Extract number from format like "test_user_203"
            let components = chat.userId.components(separatedBy: "_")
            guard let lastComponent = components.last, let extractedId = Int(lastComponent) else {
                isError = true
                alertTitle = "Error"
                alertMessage = "Invalid user ID format: \(chat.userId)"
                showAlert = true
                return
            }
            userIdNumber = extractedId
        } else {
            isError = true
            alertTitle = "Error"
            alertMessage = "Invalid user ID format: \(chat.userId)"
            showAlert = true
            return
        }
        
        let agencyId = "\(chat.agencyId)"
        isSubmitting = true
        
        Task {
            do {
                let _ = try await APIService.shared.lockAccount(
                    userId: userIdNumber,
                    agencyId: agencyId,
                    status: selectedStatus
                )
                
                await MainActor.run {
                    isSubmitting = false
                    isError = false
                    alertTitle = "Success"
                    alertMessage = "Account status updated to \(selectedStatus.displayName)"
                    showAlert = true
                }
            } catch let error as APIError {
                await MainActor.run {
                    isSubmitting = false
                    isError = true
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isError = true
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    SpamChatListView()
}

