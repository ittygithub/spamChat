//
//  SpamChatListView.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import SwiftUI

struct SpamChatListView: View {
    @State private var spamChats: [SpamChat] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading spam chats...")
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
                    List {
                        ForEach(spamChats) { chat in
                            SpamChatRow(chat: chat)
                        }
                        .onDelete(perform: deleteSpamChats)
                    }
                }
            }
            .navigationTitle("Spam Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: fetchSpamChats) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                fetchSpamChats()
            }
        }
    }
    
    private func fetchSpamChats() {
        isLoading = true
        // Simulate API call - replace with actual API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Mock data for now
            spamChats = [
                SpamChat(id: "1", sender: "+1234567890", message: "You won a prize! Click here", timestamp: Date()),
                SpamChat(id: "2", sender: "+0987654321", message: "Congratulations! You're eligible for a loan", timestamp: Date().addingTimeInterval(-3600)),
                SpamChat(id: "3", sender: "+1122334455", message: "Limited time offer! Act now!", timestamp: Date().addingTimeInterval(-7200))
            ]
            isLoading = false
        }
    }
    
    private func deleteSpamChats(at offsets: IndexSet) {
        spamChats.remove(atOffsets: offsets)
    }
}

struct SpamChatRow: View {
    let chat: SpamChat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.sender)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(chat.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(chat.formattedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// Model for Spam Chat
struct SpamChat: Identifiable {
    let id: String
    let sender: String
    let message: String
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }
}

#Preview {
    SpamChatListView()
}

