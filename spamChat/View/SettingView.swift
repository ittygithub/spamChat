//
//  SettingView.swift
//  spamChat
//
//  Created by ty on 11/14/25.
//

import SwiftUI

struct SettingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var webSocketService = WebSocketService.shared
    @ObservedObject private var authService = AuthService.shared
    @State private var showLogoutConfirmation = false
    
    // Get version and build number from Bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? 
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "SpamChat"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("APP INFORMATION")) {
                    SettingRow(label: "App Name", value: appName)
                    SettingRow(label: "Version", value: appVersion)
                    SettingRow(label: "Build", value: buildNumber)
                   
                }
                
                // Section(header: Text("CONNECTION STATUS")) {
                //     HStack {
                //         Text("WebSocket")
                //             .foregroundColor(.primary)
                //         Spacer()
                //         HStack(spacing: 6) {
                //             Circle()
                //                 .fill(webSocketService.isConnected ? Color.green : Color.red)
                //                 .frame(width: 10, height: 10)
                //             Text(webSocketService.isConnected ? "Connected" : "Disconnected")
                //                 .foregroundColor(webSocketService.isConnected ? .green : .red)
                //                 .font(.subheadline)
                //         }
                //     }
                    
                //     if let error = webSocketService.lastError {
                //         VStack(alignment: .leading, spacing: 4) {
                //             Text("Last Error")
                //                 .foregroundColor(.primary)
                //             Text(error)
                //                 .font(.caption)
                //                 .foregroundColor(.red)
                //                 .lineLimit(3)
                //         }
                //     }
                // }
                
                
                
                if let user = authService.currentUser {
                    Section(header: Text("ACCOUNT")) {
                        SettingRow(label: "Name", value: user.name)
                        SettingRow(label: "Email", value: user.email)
                    }
                }

                Section(header: Text("ABOUT")) {
                    SettingRow(label: "Developer", value: "Spam Chat Team")
                }

                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Logout", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    GoogleSignInHelper.shared.signOut()
                    authService.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
}

struct SettingRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingView()
}

