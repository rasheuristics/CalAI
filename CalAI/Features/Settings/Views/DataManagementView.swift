import SwiftUI

struct DataManagementView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var showingClearCacheAlert = false
    @State private var showingResetAlert = false
    @State private var showingSyncConfirmation = false

    var body: some View {
        Form {
            Section(header: Text("Sync Operations"),
                   footer: Text("Manually sync your calendar data or force a complete refresh from all connected services.")) {

                Button(action: {
                    showingSyncConfirmation = true
                    calendarManager.loadEvents()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("Sync Now")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("Refresh all calendars")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    // Force full sync implementation
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                        Text("Force Complete Sync")
                            .foregroundColor(.orange)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("Re-download all data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Cache Management"),
                   footer: Text("Clear cached data to free up storage space. This will not delete your calendar events, but will require re-downloading some data.")) {

                Button(action: {
                    showingClearCacheAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.orange)
                        Text("Clear Cache")
                            .foregroundColor(.orange)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text(getCacheSize())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.gray)
                        Text("Storage Usage")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("• Cached events:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2.3 MB")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("• Image cache:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("850 KB")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("• Temporary files:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("120 KB")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("• Total cache size:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            Spacer()
                            Text(getCacheSize())
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }

            Section(header: Text("Reset Options"),
                   footer: Text("Reset settings will restore CalAI to its default configuration. This action cannot be undone. Your calendar data will not be affected.")) {

                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Reset All Settings")
                            .foregroundColor(.red)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("Restore defaults")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("What will be reset")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Display preferences (font size, theme)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• AI integration settings")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Notification preferences")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Calendar auto-routing rules")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• App permissions (will need to re-grant)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()
                            .padding(.vertical, 4)

                        Text("✓ Calendar connections will be preserved")
                            .font(.caption)
                            .foregroundColor(.green)

                        Text("✓ Your event data will not be affected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Section(header: Text("Data Information")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Data Privacy")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• All data is stored locally on your device")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Calendar sync only transfers event metadata")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• No personal data is shared with third parties")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Cache clearing is safe and reversible")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear all cached data (\(getCacheSize())). You may need to re-download some information. Your calendar events will not be affected.")
        }
        .alert("Reset All Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will restore all settings to their default values. This action cannot be undone. Your calendar data and connections will be preserved.")
        }
        .alert("Sync Complete", isPresented: $showingSyncConfirmation) {
            Button("OK") { }
        } message: {
            Text("Calendar sync completed successfully. All connected calendars have been refreshed.")
        }
    }

    private func getCacheSize() -> String {
        return "3.3 MB"
    }

    private func clearCache() {
        // Implementation for clearing cache
        print("🗑️ Clearing cache...")
    }

    private func resetAllSettings() {
        // Implementation for resetting settings
        print("🔄 Resetting all settings...")
    }
}

#Preview {
    NavigationView {
        DataManagementView(
            calendarManager: CalendarManager(),
            fontManager: FontManager()
        )
    }
}