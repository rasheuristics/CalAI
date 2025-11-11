import SwiftUI

struct SyncNotificationSettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Binding var notificationsEnabled: Bool
    @Binding var autoSyncEnabled: Bool

    var body: some View {
        Form {
            Section(header: Text("Smart Notifications"),
                   footer: Text("Configure when and how you receive notifications for calendar events, reminders, and insights.")) {

                NavigationLink(destination: NotificationSettingsView()) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.blue)
                        Text("Notification Settings")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text(notificationsEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(notificationsEnabled ? .green : .secondary)
                    }
                }

                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.blue)
                        Text("Event Notifications")
                            .dynamicFont(size: 16, fontManager: fontManager)
                    }
                }
            }

            Section(header: Text("Calendar Sync"),
                   footer: Text("Manage how your calendars sync across devices and services. Auto-sync keeps your calendars up to date automatically.")) {

                Toggle(isOn: $autoSyncEnabled) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Auto Sync Calendar")
                            .dynamicFont(size: 16, fontManager: fontManager)
                    }
                }

                Button(action: {
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
            }

            Section(header: Text("Sync Status"),
                   footer: Text("View the current sync status for all connected calendar services.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                        Text("Sync Information")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        // iOS Calendar sync status
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .frame(width: 20)
                            Text("iOS Calendar")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Synced")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        // Google Calendar sync status (if connected)
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(width: 20)
                            Text("Google Calendar")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        // Outlook Calendar sync status (if connected)
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .frame(width: 20)
                            Text("Outlook Calendar")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        // Last sync time
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                                .font(.caption)
                                .frame(width: 20)
                            Text("Last Sync")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(getCurrentTimestamp())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }

            Section(header: Text("Sync Preferences")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                        Text("Advanced Sync Options")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("• Sync frequency:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Real-time")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("• Conflict resolution:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Last modified wins")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("• Background sync:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(autoSyncEnabled ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(autoSyncEnabled ? .green : .orange)
                        }

                        HStack {
                            Text("• Data usage:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Wi-Fi + Cellular")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .navigationTitle("Sync & Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: Date())
    }
}

#Preview {
    NavigationView {
        SyncNotificationSettingsView(
            calendarManager: CalendarManager(),
            fontManager: FontManager(),
            notificationsEnabled: .constant(true),
            autoSyncEnabled: .constant(true)
        )
    }
}