//
//  APIService.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case encryptionError
    case decryptionError
    case serverError(String)
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .encryptionError:
            return "Failed to encrypt data"
        case .decryptionError:
            return "Failed to decrypt response"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

class APIService {
    static let shared = APIService()
    private init() {}
    
    private let baseURL = Env.shared.apiBackend
    private let apiKey = Env.shared.apiKeyNoHu
    
    // MARK: - Get Spam Chat List
    
    func getSpamChatList(agencyId: Int? = nil, userId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> SpamChatListResponse {
        let endpoint = "\(baseURL)/spam-chats"
        
        let requestBody = SpamChatListRequest(
            agencyId: agencyId,
            userId: userId,
            startDate: nil,
            endDate: nil,
            status: nil,
            limit: limit,
            offset: offset
        )
        
        let response: SpamChatListResponse = try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Lock Chat
    
    func lockChat(userId: Int, agencyId: String, status: LockChatStatus) async throws -> GenericResponse {
        let endpoint = "\(baseURL)/lock-chat"
        
        let requestBody = LockChatRequest(
            userId: userId,
            agencyId: agencyId,
            lockChatStatus: status.rawValue
        )
        
        let response: GenericResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Unlock Chat
    
    func unlockChat(userId: Int, agencyId: String) async throws -> GenericResponse {
        let endpoint = "\(baseURL)/unlock-chat"
        
        let requestBody = LockChatRequest(
            userId: userId,
            agencyId: agencyId,
            lockChatStatus: "ACTIVE"
        )
        
        let response: GenericResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Lock Account
    
    func lockAccount(userId: Int, agencyId: String, status: AccountStatus) async throws -> GenericResponse {
        let endpoint = "\(baseURL)/lock-account"
        
        let requestBody = LockAccountRequest(
            userId: userId,
            agencyId: agencyId,
            accountStatus: status.rawValue
        )
        
        let response: GenericResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Unlock Account
    
    func unlockAccount(userId: Int, agencyId: String) async throws -> GenericResponse {
        let endpoint = "\(baseURL)/unlock-account"
        
        let requestBody = LockAccountRequest(
            userId: userId,
            agencyId: agencyId,
            accountStatus: "ACTIVE"
        )
        
        let response: GenericResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Save FCM Token
    
    func saveFCMToken(fcmToken: String) async throws -> SaveTokenResponse {
        let endpoint = "\(baseURL)/save-token"
        
        let requestBody = SaveTokenRequest(fcmToken: fcmToken)
        
        let response: SaveTokenResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: requestBody
        )
        
        return response
    }
    
    // MARK: - Generic Request with Encrypted Response
    
    private func makeRequest<T: Codable, R: Codable>(
        endpoint: String,
        method: String,
        body: T
    ) async throws -> R {
        // Generate timestamp and token for authentication
        let time = "\(Int(Date().timeIntervalSince1970))"
        let token = md5("\(apiKey)\(time)")
        
        // Encode body to dictionary and add time + token
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(body)
        guard var bodyDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw APIError.encryptionError
        }
        
        // Add time and token
        bodyDict["time"] = time
        bodyDict["token"] = token
        
        var request: URLRequest
        
        if method == "GET" {
            // For GET requests, send parameters as query string
            guard var urlComponents = URLComponents(string: endpoint) else {
                throw APIError.invalidURL
            }
            
            var queryItems: [URLQueryItem] = []
            for (key, value) in bodyDict {
                if let stringValue = value as? String {
                    queryItems.append(URLQueryItem(name: key, value: stringValue))
                } else if let intValue = value as? Int {
                    queryItems.append(URLQueryItem(name: key, value: "\(intValue)"))
                } else if let doubleValue = value as? Double {
                    queryItems.append(URLQueryItem(name: key, value: "\(doubleValue)"))
                } else {
                    // Convert complex types to JSON string
                    if let jsonData = try? JSONSerialization.data(withJSONObject: value, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        queryItems.append(URLQueryItem(name: key, value: jsonString))
                    }
                }
            }
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
                throw APIError.invalidURL
            }
            
            request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            print("📤 GET Request to: \(url.absoluteString)")
        } else {
            // For POST/PUT/DELETE, send parameters in body
            guard let url = URL(string: endpoint) else {
                throw APIError.invalidURL
            }
            
            request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Convert to JSON data
            let finalJsonData = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
            request.httpBody = finalJsonData
            
            print("📤 \(method) Request to: \(endpoint)")
            if let jsonString = String(data: finalJsonData, encoding: .utf8) {
                print("📤 Request body: \(jsonString)")
            }
        }
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        print("📥 Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Server returned status code: \(httpResponse.statusCode)")
        }
        
        // Decode encrypted response from backend
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        print("📥 Encrypted response received, decrypting...")
        
        // Decrypt using existing Helper function
        guard let decryptedDict = decryptAES256(encryptedText: apiResponse.encrypted) else {
            print("❌ Decryption failed")
            throw APIError.decryptionError
        }
        
        print("✅ Decryption successful")
        
        // Convert dictionary back to Data for decoding
        let decryptedData = try JSONSerialization.data(withJSONObject: decryptedDict, options: [])
        
        if let jsonString = String(data: decryptedData, encoding: .utf8) {
            print("📥 Decrypted response: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(R.self, from: decryptedData)
        
        return result
    }
}

