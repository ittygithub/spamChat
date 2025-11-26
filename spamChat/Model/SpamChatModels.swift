//
//  SpamChatModels.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import Foundation

// MARK: - Spam Chat List Models

struct SpamChatListRequest: Codable {
    let agencyId: Int?
    let userId: String?
    let startDate: String?
    let endDate: String?
    let status: String?
    let limit: Int?
    let offset: Int?
}

struct SpamChatListResponse: Codable {
    let success: Bool
    let data: SpamChatData
    let message: String
}

struct SpamChatData: Codable {
    let chats: [SpamChatItem]
    let totalCount: Int
    let limit: Int
    let offset: Int
    let count: Int
}

struct SpamChatItem: Codable, Identifiable {
    let id: Int
    let userId: String
    let username: String
    let message: String
    let status: String  // Keep for backward compatibility
    var chatStatus: String
    var accountStatus: String
    let createdAt: String
    let updatedAt: String
    let agencyId: Int
    let wallet: Double?  // Optional Double to support decimal amounts and null values
    let projectName: String
    
    // Optional fields
    var processedAt: String?
    var channel: String?
    var platform: String?
    var displayName: String?
    var timestamp: String?
    var totalMessages: Int?  // Total spam messages count for this user
    
    // Computed property to satisfy Identifiable with String id
    var stringId: String {
        return "\(id)"
    }
}

// MARK: - Lock Chat Models

enum LockChatStatus: String, CaseIterable {
    case active = "ACTIVE"
    case banned1Day = "BANNED_1DAY"
    case banned3Day = "BANNED_3DAY"
    case banned7Day = "BANNED_7DAY"
    case banned30Day = "BANNED_30DAY"
    case bannedForever = "BANNED_FOREVER"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .banned1Day: return "Ban 1 Day"
        case .banned3Day: return "Ban 3 Days"
        case .banned7Day: return "Ban 7 Days"
        case .banned30Day: return "Ban 30 Days"
        case .bannedForever: return "Ban Forever"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .banned1Day, .banned3Day, .banned7Day: return "orange"
        case .banned30Day, .bannedForever: return "red"
        }
    }
}

struct LockChatRequest: Codable {
    let userId: Int
    let agencyId: String
    let lockChatStatus: String
}

// MARK: - Lock Account Models

enum AccountStatus: String, CaseIterable {
    case active = "ACTIVE"
    case banned5M = "BANNED_5M"
    case banned30Day = "BANNED_30DAY"
    case bannedForever = "BANNED_FOREVER"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .banned5M: return "Ban 5 Minutes"
        case .banned30Day: return "Ban 30 Days"
        case .bannedForever: return "Ban Forever"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .banned5M: return "orange"
        case .banned30Day, .bannedForever: return "red"
        }
    }
}

struct LockAccountRequest: Codable {
    let userId: Int
    let agencyId: String
    let accountStatus: String
}

// MARK: - Save FCM Token Models

struct SaveTokenRequest: Codable {
    let fcmToken: String
    
    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
    }
}

struct SaveTokenResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - API Response Models

struct APIResponse: Codable {
    let code: Int
    let message: String
    let encrypted: String
}

struct GenericResponse: Codable {
    let success: Bool
    let message: String
    let data: [String: AnyCodable]?
}

// Helper for dynamic JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

