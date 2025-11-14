//
//  BlockListView.swift
//  spamChat
//
//  Created by ty on 11/13/25.
//

import SwiftUI

struct BlockListView: View {
    @State private var blockedUsers: [BlockedUser] = []
    @State private var showingAddSheet = false
    @State private var newPhoneNumber = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if blockedUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No Blocked Users")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Block spam numbers to filter messages")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding()
                } else {
                    List {
                        ForEach(blockedUsers) { user in
                            BlockedUserRow(user: user)
                        }
                        .onDelete(perform: unblockUsers)
                    }
                }
            }
            .navigationTitle("Blocked Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBlockedNumberSheet(
                    phoneNumber: $newPhoneNumber,
                    onAdd: { number in
                        addBlockedUser(number)
                        showingAddSheet = false
                    },
                    onCancel: {
                        showingAddSheet = false
                    }
                )
            }
            .onAppear {
                loadBlockedUsers()
            }
        }
    }
    
    private func loadBlockedUsers() {
        // Mock data - replace with actual data loading
        blockedUsers = [
            BlockedUser(id: "1", phoneNumber: "+1234567890", blockedDate: Date()),
            BlockedUser(id: "2", phoneNumber: "+0987654321", blockedDate: Date().addingTimeInterval(-86400)),
            BlockedUser(id: "3", phoneNumber: "+1122334455", blockedDate: Date().addingTimeInterval(-172800))
        ]
    }
    
    private func addBlockedUser(_ phoneNumber: String) {
        let newUser = BlockedUser(
            id: UUID().uuidString,
            phoneNumber: phoneNumber,
            blockedDate: Date()
        )
        blockedUsers.insert(newUser, at: 0)
        newPhoneNumber = ""
    }
    
    private func unblockUsers(at offsets: IndexSet) {
        blockedUsers.remove(atOffsets: offsets)
    }
}

struct BlockedUserRow: View {
    let user: BlockedUser
    
    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.title2)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.phoneNumber)
                    .font(.headline)
                
                Text("Blocked \(user.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddBlockedNumberSheet: View {
    @Binding var phoneNumber: String
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Block Number")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !phoneNumber.isEmpty {
                            onAdd(phoneNumber)
                        }
                    }
                    .disabled(phoneNumber.isEmpty)
                }
            }
        }
    }
}

// Model for Blocked User
struct BlockedUser: Identifiable {
    let id: String
    let phoneNumber: String
    let blockedDate: Date
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: blockedDate, relativeTo: Date())
    }
}

#Preview {
    BlockListView()
}

