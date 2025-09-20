import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var fontManager: FontManager
    @State private var selectedLanguage = "en-US"
    @State private var notificationsEnabled = true
    @State private var autoSyncEnabled = true
    @State private var voiceActivationEnabled = true
    @State private var apiKey = Config.anthropicAPIKey
    @State private var showingAPIKeyAlert = false
    @State private var isAPIKeyVisible = false

    private var sizeCategory: ContentSizeCategory {
        switch fontManager.currentFontSize {
        case .small:
            return .small
        case .medium:
            return .medium
        case .large:
            return .large
        case .extraLarge:
            return .extraLarge
        }
    }

    var body: some View {
        Form {
                Section("Permissions") {
                    PermissionRow(
                        title: "Calendar Access",
                        systemImage: "calendar",
                        status: calendarManager.hasCalendarAccess ? .granted : .notGranted,
                        action: {
                            calendarManager.requestCalendarAccess()
                        }
                    )

                    PermissionRow(
                        title: "Microphone Access",
                        systemImage: "mic",
                        status: voiceManager.hasRecordingPermission ? .granted : .notGranted,
                        action: {
                            // Voice manager handles this automatically
                        }
                    )

                    PermissionRow(
                        title: "Speech Recognition",
                        systemImage: "waveform",
                        status: voiceManager.hasRecordingPermission ? .granted : .notGranted,
                        action: {
                            // Voice manager handles this automatically
                        }
                    )
                }

                Section("Display Settings") {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.blue)
                        Text("Font Size")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Picker("Font Size", selection: $fontManager.currentFontSize) {
                            Text("Small").tag(FontSize.small)
                            Text("Medium").tag(FontSize.medium)
                            Text("Large").tag(FontSize.large)
                            Text("Extra Large").tag(FontSize.extraLarge)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 200)
                    }
                }

                Section("AI Integration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            Text("Anthropic API Key")
                                .dynamicFont(size: 16, fontManager: fontManager)
                            Spacer()
                            Image(systemName: Config.hasValidAPIKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(Config.hasValidAPIKey ? .green : .orange)
                        }

                        HStack {
                            if isAPIKeyVisible {
                                TextField("Enter your Anthropic API key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: apiKey) { newValue in
                                        Config.anthropicAPIKey = newValue
                                    }
                            } else {
                                SecureField("Enter your Anthropic API key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: apiKey) { newValue in
                                        Config.anthropicAPIKey = newValue
                                    }
                            }

                            Button(action: {
                                isAPIKeyVisible.toggle()
                            }) {
                                Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }

                        if !Config.hasValidAPIKey && !apiKey.isEmpty {
                            Text("Invalid API key format. Should start with 'sk-ant-'")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if Config.hasValidAPIKey {
                            Text("✓ API key configured - AI features enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Add your Anthropic API key to enable AI-powered calendar features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            showingAPIKeyAlert = true
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                                Text("How to get API key")
                                    .foregroundColor(.blue)
                                    .dynamicFont(size: 14, fontManager: fontManager)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Voice Settings") {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Language")
                        Spacer()
                        Picker("Language", selection: $selectedLanguage) {
                            Text("English (US)").tag("en-US")
                            Text("English (UK)").tag("en-GB")
                            Text("Spanish").tag("es-ES")
                            Text("French").tag("fr-FR")
                            Text("German").tag("de-DE")
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    Toggle(isOn: $voiceActivationEnabled) {
                        HStack {
                            Image(systemName: "mic.badge.plus")
                                .foregroundColor(.blue)
                            Text("Voice Activation")
                        }
                    }
                }

                Section("Sync & Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                            Text("Event Notifications")
                        }
                    }

                    Toggle(isOn: $autoSyncEnabled) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Auto Sync Calendar")
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
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                        Text("Developer")
                        Spacer()
                        Text("CalAI Team")
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        // Open privacy policy
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Section("Data") {
                    Button(action: {
                        // Clear cache
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cache")
                                .foregroundColor(.red)
                        }
                    }

                    Button(action: {
                        // Reset all settings
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset Settings")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .environment(\.sizeCategory, sizeCategory)
            .alert("Get Anthropic API Key", isPresented: $showingAPIKeyAlert) {
                Button("Open Console", action: {
                    if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                        UIApplication.shared.open(url)
                    }
                })
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("1. Go to console.anthropic.com\n2. Sign up or log in\n3. Navigate to 'API Keys'\n4. Create a new API key\n5. Copy and paste it here")
            }
    }
}

struct PermissionRow: View {
    let title: String
    let systemImage: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
            Text(title)
            Spacer()

            Button(action: action) {
                HStack {
                    Image(systemName: status.iconName)
                        .foregroundColor(status.color)
                    Text(status.text)
                        .foregroundColor(status.color)
                        .font(.caption)
                }
            }
            .disabled(status == .granted)
        }
    }
}

enum FontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var scaleFactor: CGFloat {
        switch self {
        case .small:
            return 0.8
        case .medium:
            return 1.0
        case .large:
            return 1.2
        case .extraLarge:
            return 1.4
        }
    }
}

enum PermissionStatus {
    case granted
    case notGranted
    case unknown

    var iconName: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .notGranted:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted:
            return .green
        case .notGranted:
            return .red
        case .unknown:
            return .orange
        }
    }

    var text: String {
        switch self {
        case .granted:
            return "Granted"
        case .notGranted:
            return "Denied"
        case .unknown:
            return "Unknown"
        }
    }
}