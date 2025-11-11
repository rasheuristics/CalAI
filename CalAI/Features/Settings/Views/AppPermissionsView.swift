import SwiftUI
import CoreLocation
import UserNotifications

struct AppPermissionsView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var fontManager: FontManager
    @State private var hasLocationPermission: Bool = false
    @State private var hasNotificationPermission: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Microphone Access"),
                   footer: Text("Required for voice commands and AI interactions. CalAI processes voice data locally when possible to protect your privacy.")) {
                PermissionRow(
                    title: "Microphone Access",
                    systemImage: "mic",
                    status: voiceManager.hasRecordingPermission ? .granted : .notGranted,
                    action: {
                        // Voice manager handles this automatically
                    }
                )
            }

            Section(header: Text("Location Access"),
                   footer: Text("Used to provide location-based event suggestions and travel time calculations. Location data is processed locally and not shared with third parties.")) {
                PermissionRow(
                    title: "Location Access",
                    systemImage: "location.fill",
                    status: hasLocationPermission ? .granted : .notGranted,
                    action: {
                        requestLocationPermission()
                    }
                )
            }

            Section(header: Text("Notification Access"),
                   footer: Text("Enables smart notifications for upcoming events, reminders, and calendar insights. You can customize notification preferences in the notification settings.")) {
                PermissionRow(
                    title: "Notification Access",
                    systemImage: "bell.badge.fill",
                    status: hasNotificationPermission ? .granted : .notGranted,
                    action: {
                        requestNotificationPermission()
                    }
                )
            }

            Section(header: Text("Privacy Information")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                        Text("Data Protection")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Voice data processed locally when possible")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Location data never leaves your device")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Calendar data encrypted and secured")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• No personal data sold or shared")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("App Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissions()
        }
    }

    // MARK: - Permission Methods

    private func checkPermissions() {
        checkLocationPermission()
        checkNotificationPermission()
    }

    private func checkLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        hasLocationPermission = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasNotificationPermission = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func requestLocationPermission() {
        // Open app settings for the user to grant location permission
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                hasNotificationPermission = granted
            }
        }
    }
}

#Preview {
    NavigationView {
        AppPermissionsView(
            voiceManager: VoiceManager(),
            fontManager: FontManager()
        )
    }
}