import SwiftUI

/// Settings view for Morning Briefing configuration
struct MorningBriefingSettingsView: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var briefingService = MorningBriefingService.shared
    @ObservedObject var weatherService = WeatherService.shared

    @State private var settings: MorningBriefingSettings
    @State private var weatherAPIKey: String
    @State private var isWeatherAPIKeyVisible = false
    @State private var showingTestNotification = false

    init(fontManager: FontManager) {
        self.fontManager = fontManager
        _settings = State(initialValue: MorningBriefingService.shared.settings)
        _weatherAPIKey = State(initialValue: UserDefaults.standard.string(forKey: "openWeatherMapAPIKey") ?? "")
    }

    var body: some View {
        Form {
            // Enable/Disable Section
            Section(footer: Text("Receive a daily morning briefing with weather and your schedule")) {
                Toggle(isOn: $settings.isEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Enable Morning Briefing")
                            .dynamicFont(size: 16, fontManager: fontManager)
                    }
                }
                .onChange(of: settings.isEnabled) { _ in
                    saveSettings()
                }
            }

            if settings.isEnabled {
                // Time Settings
                Section(header: Text("Schedule")) {
                    DatePicker(
                        "Briefing Time",
                        selection: $settings.briefingTime,
                        displayedComponents: .hourAndMinute
                    )
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .onChange(of: settings.briefingTime) { _ in
                        saveSettings()
                    }

                    Text("Applies to all days (weekdays and weekends)")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                // Notification Settings
                Section(header: Text("Notification")) {
                    Toggle(isOn: $settings.soundEnabled) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text("Notification Sound")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                    .onChange(of: settings.soundEnabled) { _ in
                        saveSettings()
                    }
                }

                // Voice Settings
                Section(header: Text("Voice Read-Out")) {
                    Toggle(isOn: $settings.voiceAutoPlay) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                            Text("Auto-Play Voice")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                    .onChange(of: settings.voiceAutoPlay) { _ in
                        saveSettings()
                    }

                    Text("Automatically read briefing aloud when opened")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                // Weather API Configuration
                Section(header: Text("Weather Configuration"),
                       footer: Text("Get your free API key from openweathermap.org/api. Required for weather data.")) {
                    HStack {
                        if isWeatherAPIKeyVisible {
                            TextField("API Key", text: $weatherAPIKey)
                                .autocapitalization(.none)
                                .dynamicFont(size: 14, fontManager: fontManager)
                        } else {
                            SecureField("API Key", text: $weatherAPIKey)
                                .dynamicFont(size: 14, fontManager: fontManager)
                        }

                        Button(action: {
                            isWeatherAPIKeyVisible.toggle()
                        }) {
                            Image(systemName: isWeatherAPIKeyVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: weatherAPIKey) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "openWeatherMapAPIKey")
                        weatherService.setAPIKey(newValue)
                    }

                    if weatherService.hasAPIKey() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Weather API Configured")
                                .dynamicFont(size: 14, fontManager: fontManager)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Weather API Not Configured")
                                .dynamicFont(size: 14, fontManager: fontManager)
                                .foregroundColor(.orange)
                        }
                    }

                    Button(action: {
                        if let url = URL(string: "https://openweathermap.org/api") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("Get Free API Key")
                                .dynamicFont(size: 14, fontManager: fontManager)
                        }
                    }
                }

                // Testing Section
                Section(header: Text("Testing")) {
                    Button(action: {
                        briefingService.generateTestBriefing()
                    }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Generate Test Briefing")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }

                    Button(action: {
                        briefingService.sendTestNotification()
                        showingTestNotification = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                            showingTestNotification = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Send Test Notification")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }

                    if showingTestNotification {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Test notification will appear in 5 seconds...")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Info Section
                Section(header: Text("What's Included")) {
                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(icon: "cloud.sun.fill", title: "Weather Forecast", description: "Current conditions, high/low, precipitation")
                        featureRow(icon: "calendar", title: "Today's Events", description: "All events from all your calendars")
                        featureRow(icon: "lightbulb.fill", title: "Daily Insights", description: "Schedule density and time gaps")
                        featureRow(icon: "speaker.wave.2.fill", title: "Voice Readout", description: "Option to hear your briefing")
                    }
                }
            }
        }
        .navigationTitle("Morning Briefing")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                Text(description)
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helper Methods

    private func saveSettings() {
        briefingService.updateSettings(settings)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        MorningBriefingSettingsView(fontManager: FontManager())
    }
}
