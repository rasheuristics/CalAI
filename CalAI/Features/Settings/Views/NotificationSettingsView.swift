import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = SmartNotificationManager.shared
    @StateObject private var travelManager = TravelTimeManager.shared
    @State private var preferences: NotificationPreferences
    @State private var showingTestAlert = false
    @State private var testNotificationScheduled = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _preferences = State(initialValue: NotificationPreferences.load())
    }

    var body: some View {
        Form {
            // Main Toggle
            Section {
                Toggle("Enable Smart Notifications", isOn: $preferences.enableSmartNotifications)
                    .onChange(of: preferences.enableSmartNotifications) { _ in
                        savePreferences()
                    }

                if !notificationManager.isAuthorized {
                    Button("Request Notification Permission") {
                        notificationManager.requestNotificationPermission { granted in
                            if granted {
                                print("✅ Notification permission granted")
                                notificationManager.setupNotificationCategories()
                            } else {
                                print("❌ Notification permission denied")
                            }
                        }
                    }
                    .foregroundColor(.blue)
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Get intelligent notifications based on meeting type and location")
            }

            if preferences.enableSmartNotifications {
                // Physical Meeting Settings
                Section {
                    Toggle("Calculate Travel Time", isOn: $preferences.enableTravelTimeCalculation)
                        .onChange(of: preferences.enableTravelTimeCalculation) { _ in
                            savePreferences()
                        }

                    if preferences.enableTravelTimeCalculation {
                        Picker("Buffer Time", selection: $preferences.physicalMeetingBufferMinutes) {
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("20 minutes").tag(20)
                            Text("30 minutes").tag(30)
                        }
                        .onChange(of: preferences.physicalMeetingBufferMinutes) { _ in
                            savePreferences()
                        }

                        Picker("Minimum Travel Time", selection: $preferences.minimumTravelTimeThresholdMinutes) {
                            Text("No minimum").tag(0)
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                        }
                        .onChange(of: preferences.minimumTravelTimeThresholdMinutes) { _ in
                            savePreferences()
                        }

                        // Location permission status
                        HStack {
                            Text("Location Access")
                            Spacer()
                            Text(locationStatusText)
                                .foregroundColor(locationStatusColor)
                        }

                        if travelManager.authorizationStatus == .notDetermined {
                            Button("Request Location Permission") {
                                travelManager.requestLocationPermission()
                            }
                        } else if travelManager.authorizationStatus == .denied || travelManager.authorizationStatus == .restricted {
                            Button("Enable Location in Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Physical Meetings")
                } footer: {
                    if preferences.enableTravelTimeCalculation {
                        Text("You'll be notified when to leave based on real-time traffic. Buffer time is added to ensure you arrive early.")
                    }
                }

                // Virtual Meeting Settings
                Section {
                    Picker("Advance Notice", selection: $preferences.virtualMeetingLeadMinutes) {
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                    }
                    .onChange(of: preferences.virtualMeetingLeadMinutes) { _ in
                        savePreferences()
                    }
                } header: {
                    Text("Virtual Meetings")
                } footer: {
                    Text("Get notified before Zoom, Teams, or Google Meet calls so you have time to join.")
                }

                // Multiple Notification Options
                Section {
                    Toggle("15-Minute Reminder", isOn: $preferences.enable15MinuteReminder)
                        .onChange(of: preferences.enable15MinuteReminder) { _ in
                            savePreferences()
                        }

                    Toggle("Travel Time Alert", isOn: $preferences.enableTravelTimeReminder)
                        .onChange(of: preferences.enableTravelTimeReminder) { _ in
                            savePreferences()
                        }

                    Toggle("5-Minute Virtual Join Alert", isOn: $preferences.enable5MinuteVirtualReminder)
                        .onChange(of: preferences.enable5MinuteVirtualReminder) { _ in
                            savePreferences()
                        }
                } header: {
                    Text("Notification Types")
                } footer: {
                    Text("15-min reminder applies to all meetings. Travel alert shows when to leave for physical meetings. 5-min alert reminds you to join virtual meetings.")
                }

                // Haptic Settings
                Section {
                    Toggle("Haptic Feedback", isOn: $preferences.useHapticFeedback)
                        .onChange(of: preferences.useHapticFeedback) { _ in
                            savePreferences()
                        }

                    if preferences.useHapticFeedback {
                        Picker("Haptic Intensity", selection: $preferences.hapticIntensity) {
                            ForEach(NotificationPreferences.HapticIntensity.allCases, id: \.self) { intensity in
                                Text(intensity.rawValue).tag(intensity)
                            }
                        }
                        .onChange(of: preferences.hapticIntensity) { _ in
                            savePreferences()
                        }
                    }
                } header: {
                    Text("Haptic Feedback")
                } footer: {
                    Text("Feel distinct vibrations for different notification types")
                }

                // Test Section
                Section {
                    Button("Send Test Notification") {
                        sendTestNotification()
                    }
                    .disabled(testNotificationScheduled)

                    if testNotificationScheduled {
                        Text("Test notification scheduled in 5 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Test")
                }
            }

            // Permissions Status
            Section {
                HStack {
                    Text("Notification Permission")
                    Spacer()
                    Text(notificationManager.isAuthorized ? "Granted" : "Not Granted")
                        .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                }

                HStack {
                    Text("Location Permission")
                    Spacer()
                    Text(locationStatusText)
                        .foregroundColor(locationStatusColor)
                }
            } header: {
                Text("Permissions Status")
            }
        }
        .navigationTitle("Smart Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Test Notification", isPresented: $showingTestAlert) {
            Button("OK") {
                testNotificationScheduled = false
            }
        } message: {
            Text("A test notification will appear in 5 seconds")
        }
        .onAppear {
            notificationManager.checkAuthorization()
            travelManager.requestLocationPermission()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Re-check authorization when app becomes active (e.g., returning from Settings)
                notificationManager.checkAuthorization()
            }
        }
    }

    private var locationStatusText: String {
        switch travelManager.authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        switch travelManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private func savePreferences() {
        preferences.save()
        notificationManager.updatePreferences(preferences)
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test of CalAI's smart notification system with time-sensitive delivery."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to schedule test notification: \(error.localizedDescription)")
                } else {
                    print("✅ Test notification scheduled")
                    testNotificationScheduled = true
                    showingTestAlert = true

                    // Reset after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        testNotificationScheduled = false
                    }
                }
            }
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingsView()
        }
    }
}
