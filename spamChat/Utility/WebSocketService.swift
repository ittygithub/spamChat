//
//  WebSocketService.swift
//  spamChat
//
//  Created by ty on 11/14/25.
//

import Foundation
import Combine

// MARK: - WebSocket Message Models

struct WebSocketMessage: Codable {
    let type: String
    let timestamp: String
    let data: WebSocketData?
}

enum WebSocketData: Codable {
    case spamChat(SpamChatNotification)
    case statusUpdate(UserStatusUpdate)
    case welcome(WelcomeData)
    case generic([String: AnyCodable])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as SpamChatNotification first
        if let spamChat = try? container.decode(SpamChatNotification.self) {
            self = .spamChat(spamChat)
            return
        }
        
        // Try to decode as UserStatusUpdate
        if let statusUpdate = try? container.decode(UserStatusUpdate.self) {
            self = .statusUpdate(statusUpdate)
            return
        }
        
        // Try to decode as WelcomeData
        if let welcome = try? container.decode(WelcomeData.self) {
            self = .welcome(welcome)
            return
        }
        
        // Fallback to generic dictionary
        if let dict = try? container.decode([String: AnyCodable].self) {
            self = .generic(dict)
            return
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode WebSocketData")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .spamChat(let notification):
            try container.encode(notification)
        case .statusUpdate(let update):
            try container.encode(update)
        case .welcome(let welcome):
            try container.encode(welcome)
        case .generic(let dict):
            try container.encode(dict)
        }
    }
}

struct SpamChatNotification: Codable {
    let id: Int
    let userId: String
    let username: String
    let message: String
    let channel: String
    let platform: String
    let projectName: String
    let agencyId: String
    let wallet: String
    let severity: String
    let isSpam: Bool
    let confidence: Double
    let status: String
    let chatStatus: String
    let accountStatus: String
    let createdAt: String
}

struct UserStatusUpdate: Codable {
    let userId: String
    let agencyId: String
    let chatStatus: String
    let accountStatus: String
    let updatedAt: String
    let totalMessages: Int?  // Optional: Total spam messages count for this user
}

struct WelcomeData: Codable {
    let message: String
    let clientId: String
}

// MARK: - WebSocket Service

class WebSocketService: ObservableObject {
    static let shared = WebSocketService()
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var reconnectTimer: Timer?
    private var shouldReconnect = true
    private var currentAgencyId: String = "1"
    private var currentUserId: String?
    
    // Callback for new spam chat messages
    var onNewSpamChat: ((SpamChatNotification) -> Void)?
    var onStatusUpdate: ((UserStatusUpdate) -> Void)?
    var onConnected: (() -> Void)?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Connection Management
    
    func connect(agencyId: String = "1", userId: String? = nil) {
        print("🔍 DEBUG: connect() method called with agencyId: \(agencyId), userId: \(userId ?? "nil")")
        
        // Store the connection parameters for reconnection
        self.currentAgencyId = agencyId
        self.currentUserId = userId
        
        guard webSocketTask == nil else {
            print("⚠️ WebSocket already connected")
            return
        }
        
        print("🔍 DEBUG: Env.shared.apiBackend = \(Env.shared.apiBackend)")
        
        let baseURL = Env.shared.apiBackend.replacingOccurrences(of: "http://", with: "ws://")
                                          .replacingOccurrences(of: "https://", with: "wss://")
                                          .replacingOccurrences(of: "/api/v1", with: "")
        
        print("🔍 DEBUG: baseURL after transformation = \(baseURL)")
        
        let clientId = "ios_\(UUID().uuidString.prefix(8))"
        var urlString = "\(baseURL)/ws?clientId=\(clientId)&agencyId=\(agencyId)"
        
        if let userId = userId {
            urlString += "&userId=\(userId)"
        }
        
        print("🔍 DEBUG: Final WebSocket URL = \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid WebSocket URL: \(urlString)")
            lastError = "Invalid WebSocket URL"
            return
        }
        
        print("🔌 Connecting to WebSocket: \(urlString)")
        print("🔍 DEBUG: Creating URLSessionWebSocketTask...")
        
        webSocketTask = session.webSocketTask(with: url)
        print("🔍 DEBUG: WebSocketTask created, calling resume()...")
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.lastError = nil
            print("🔍 DEBUG: isConnected set to true")
        }
        
        // Start listening for messages
        print("🔍 DEBUG: Starting receiveMessage()...")
        receiveMessage()
        
        // Start ping timer to keep connection alive
        print("🔍 DEBUG: Starting ping timer...")
        startPingTimer()
        
        print("✅ WebSocket connection initiated, waiting for messages...")
    }
    
    func disconnect() {
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        print("🔌 WebSocket disconnected")
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        print("🔍 DEBUG: receiveMessage() - Waiting for WebSocket messages...")
        
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            print("🔍 DEBUG: WebSocket receive callback triggered")
            
            switch result {
            case .success(let message):
                print("🔍 DEBUG: Received WebSocket message successfully")
                switch message {
                case .string(let text):
                    print("🔍 DEBUG: Message type: string, length: \(text.count)")
                    self.handleMessage(text)
                case .data(let data):
                    print("🔍 DEBUG: Message type: data, length: \(data.count)")
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    print("🔍 DEBUG: Unknown message type")
                    break
                }
                
                // Continue listening
                print("🔍 DEBUG: Calling receiveMessage() again to continue listening...")
                self.receiveMessage()
                
            case .failure(let error):
                print("❌ WebSocket receive error: \(error.localizedDescription)")
                print("🔍 DEBUG: Error details - \(error)")
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.isConnected = false
                }
                
                // Attempt to reconnect
                if self.shouldReconnect {
                    print("🔍 DEBUG: Scheduling reconnect...")
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        print("📥 WebSocket message received: \(text)")
        print("🔍 DEBUG: Message length: \(text.count) characters")
        
        guard let data = text.data(using: .utf8) else {
            print("❌ Failed to convert message to data")
            return
        }
        
        print("🔍 DEBUG: Converted to data, attempting to decode JSON...")
        
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(WebSocketMessage.self, from: data)
            
            print("✅ Parsed message type: \(message.type)")
            print("🔍 DEBUG: Message timestamp: \(message.timestamp)")
            
            switch message.type {
            case "spam_chat_new":
                print("🔍 DEBUG: Processing spam_chat_new message...")
                if case .spamChat(let notification) = message.data {
                    print("🎯 New spam chat notification: User \(notification.username)")
                    print("🔍 DEBUG: Notification ID: \(notification.id), AgencyID: \(notification.agencyId)")
                    print("🔍 DEBUG: Calling onNewSpamChat callback...")
                    DispatchQueue.main.async {
                        self.onNewSpamChat?(notification)
                    }
                } else {
                    print("⚠️ DEBUG: Failed to extract SpamChatNotification from message.data")
                    print("🔍 DEBUG: message.data type: \(type(of: message.data))")
                }
                
            case "user_status_update":
                print("🔍 DEBUG: Processing user_status_update message...")
                if case .statusUpdate(let update) = message.data {
                    print("📊 User status update: \(update.userId)")
                    DispatchQueue.main.async {
                        self.onStatusUpdate?(update)
                    }
                }
                
            case "welcome":
                print("🔍 DEBUG: Processing welcome message...")
                if case .welcome(let welcome) = message.data {
                    print("👋 Welcome message: \(welcome.message)")
                    // Call the onConnected callback to trigger subscription
                    DispatchQueue.main.async {
                        self.onConnected?()
                    }
                }
                
            case "pong":
                print("🏓 Pong received")
                
            default:
                print("ℹ️ Unhandled message type: \(message.type)")
            }
            
        } catch {
            print("❌ Failed to decode WebSocket message: \(error)")
            print("🔍 DEBUG: Decoder error details: \(error)")
            print("Raw message: \(text)")
        }
    }
    
    private func sendMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("❌ WebSocket send error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Keep Alive
    
    private func startPingTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("❌ WebSocket ping error: \(error.localizedDescription)")
                self?.scheduleReconnect()
            }
        }
    }
    
    // MARK: - Reconnection
    
    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        
        print("🔄 Scheduling WebSocket reconnection in 5 seconds...")
        
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, self.shouldReconnect else { return }
            print("🔄 Attempting to reconnect WebSocket...")
            self.connect(agencyId: self.currentAgencyId, userId: self.currentUserId)
        }
    }
    
    // MARK: - Public Methods
    
    func subscribeToAgency(_ agencyId: String) {
        let message = """
        {
            "type": "subscribe_agency",
            "agencyId": "\(agencyId)"
        }
        """
        sendMessage(message)
        print("📡 Subscribed to agency: \(agencyId)")
    }
}

