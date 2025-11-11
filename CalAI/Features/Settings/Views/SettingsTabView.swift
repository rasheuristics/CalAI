import SwiftUI
import CoreLocation
import UserNotifications

struct SettingsTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var googleCalendarManager: GoogleCalendarManager
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager
    @ObservedObject var appearanceManager: AppearanceManager
    @State private var selectedLanguage = "en-US"
    @State private var notificationsEnabled = true
    @State private var autoSyncEnabled = true
    @State private var voiceActivationEnabled = true
    @State private var anthropicAPIKey = Config.anthropicAPIKey
    @State private var openaiAPIKey = Config.openaiAPIKey
    @State private var selectedAIProvider = Config.aiProvider
    @State private var selectedProcessingMode = Config.aiProcessingMode
    @State private var showingAPIKeyAlert = false
    @State private var isAnthropicKeyVisible = false
    @State private var isOpenAIKeyVisible = false
    @State private var defaultWorkCalendar = UserDefaults.standard.string(forKey: "defaultWorkCalendar") ?? "Outlook"
    @State private var defaultPersonalCalendar = UserDefaults.standard.string(forKey: "defaultPersonalCalendar") ?? "iOS"
    @State private var defaultFallbackCalendar = UserDefaults.standard.string(forKey: "defaultFallbackCalendar") ?? "iOS"
    @State private var hasLocationPermission: Bool = false
    @State private var hasNotificationPermission: Bool = false

    // Calendar connection status tracking
    @State private var iOSCalendarLastRequested: Date? = UserDefaults.standard.object(forKey: "iOSCalendarLastRequested") as? Date
    @State private var iOSCalendarConnectedAt: Date? = UserDefaults.standard.object(forKey: "iOSCalendarConnectedAt") as? Date
    @State private var googleCalendarLastRequested: Date? = UserDefaults.standard.object(forKey: "googleCalendarLastRequested") as? Date
    @State private var googleCalendarConnectedAt: Date? = UserDefaults.standard.object(forKey: "googleCalendarConnectedAt") as? Date
    @State private var outlookCalendarLastRequested: Date? = UserDefaults.standard.object(forKey: "outlookCalendarLastRequested") as? Date
    @State private var outlookCalendarConnectedAt: Date? = UserDefaults.standard.object(forKey: "outlookCalendarConnectedAt") as? Date

    /// Check if FoundationModels framework is available for Apple Intelligence
    private func checkFoundationModels() -> Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// Format date for connection status display
    private func formatConnectionDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatCalendarName(_ calendar: String) -> String {
        switch calendar {
        case "iOS":
            return "iOS"
        case "Google":
            return "Google"
        case "Outlook":
            return "Outlook"
        default:
            return "iOS"
        }
    }

    private func getLanguageDisplayName(_ languageCode: String) -> String {
        switch languageCode {
        case "en-US":
            return "English (US)"
        case "en-GB":
            return "English (UK)"
        case "es-ES":
            return "Spanish"
        case "fr-FR":
            return "French"
        case "de-DE":
            return "German"
        default:
            return "English (US)"
        }
    }

    /// Update connection status timestamps
    private func updateConnectionStatus(for service: String, requested: Bool = true, connected: Bool = false) {
        let now = Date()

        switch service {
        case "iOS":
            if requested {
                iOSCalendarLastRequested = now
                UserDefaults.standard.set(now, forKey: "iOSCalendarLastRequested")
            }
            if connected {
                iOSCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "iOSCalendarConnectedAt")
            }
        case "Google":
            if requested {
                googleCalendarLastRequested = now
                UserDefaults.standard.set(now, forKey: "googleCalendarLastRequested")
            }
            if connected {
                googleCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "googleCalendarConnectedAt")
            }
        case "Outlook":
            if requested {
                outlookCalendarLastRequested = now
                UserDefaults.standard.set(now, forKey: "outlookCalendarLastRequested")
            }
            if connected {
                outlookCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "outlookCalendarConnectedAt")
            }
        default:
            break
        }
    }

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

    private var outlookCalendarStatus: PermissionStatus {
        if outlookCalendarManager.isSignedIn && outlookCalendarManager.selectedCalendar != nil {
            return .granted
        } else if outlookCalendarManager.isSignedIn && outlookCalendarManager.selectedCalendar == nil {
            return .unknown
        } else {
            return .notGranted
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Transparent background to show main gradient
                Color.clear
                    .ignoresSafeArea(.all)

                Form {
                Section("Calendar Connections") {
                    CalendarPermissionRow(
                        title: "iOS Calendar",
                        systemImage: "calendar",
                        status: calendarManager.hasCalendarAccess ? .granted : .notGranted,
                        lastRequested: calendarManager.hasCalendarAccess ? (iOSCalendarLastRequested ?? iOSCalendarConnectedAt) : iOSCalendarLastRequested,
                        connectedAt: calendarManager.hasCalendarAccess ? iOSCalendarConnectedAt : nil,
                        action: {
                            // Always update the last requested timestamp
                            updateConnectionStatus(for: "iOS", requested: true)

                            if calendarManager.hasCalendarAccess {
                                // Already granted - just update connected timestamp if missing
                                if iOSCalendarConnectedAt == nil {
                                    updateConnectionStatus(for: "iOS", requested: false, connected: true)
                                }
                            } else {
                                // Request permission
                                calendarManager.requestCalendarAccess()

                                // Check connection status after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    if calendarManager.hasCalendarAccess {
                                        updateConnectionStatus(for: "iOS", requested: false, connected: true)
                                    }
                                }
                            }
                        },
                        showSettingsButton: true
                    )

                    CalendarPermissionRow(
                        title: "Google Calendar",
                        systemImage: "globe",
                        status: googleCalendarManager.isSignedIn ? .granted : .notGranted,
                        lastRequested: googleCalendarManager.isSignedIn ? (googleCalendarLastRequested ?? googleCalendarConnectedAt) : googleCalendarLastRequested,
                        connectedAt: googleCalendarManager.isSignedIn ? googleCalendarConnectedAt : nil,
                        action: {
                            if googleCalendarManager.isSignedIn {
                                googleCalendarManager.signOut()
                                // Clear connected timestamp when signing out
                                googleCalendarConnectedAt = nil
                                UserDefaults.standard.removeObject(forKey: "googleCalendarConnectedAt")
                            } else {
                                updateConnectionStatus(for: "Google", requested: true)
                                googleCalendarManager.signIn()

                                // Check connection status after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    if googleCalendarManager.isSignedIn {
                                        updateConnectionStatus(for: "Google", requested: false, connected: true)
                                    }
                                }
                            }
                        },
                        showSettingsButton: false
                    )

                    CalendarPermissionRow(
                        title: "Outlook Calendar",
                        systemImage: "envelope",
                        status: outlookCalendarStatus,
                        lastRequested: outlookCalendarStatus == .granted ? (outlookCalendarLastRequested ?? outlookCalendarConnectedAt) : outlookCalendarLastRequested,
                        connectedAt: outlookCalendarStatus == .granted ? outlookCalendarConnectedAt : nil,
                        action: {
                            if outlookCalendarManager.isSignedIn {
                                if outlookCalendarManager.selectedCalendar == nil {
                                    // If signed in but no calendar selected, show calendar selection
                                    updateConnectionStatus(for: "Outlook", requested: true)
                                    outlookCalendarManager.showCalendarSelectionSheet()
                                } else {
                                    // If fully configured, sign out
                                    outlookCalendarManager.signOut()
                                    // Clear connected timestamp when signing out
                                    outlookCalendarConnectedAt = nil
                                    UserDefaults.standard.removeObject(forKey: "outlookCalendarConnectedAt")
                                }
                            } else {
                                // If not signed in, start sign in process
                                updateConnectionStatus(for: "Outlook", requested: true)
                                outlookCalendarManager.signIn()

                                // Check connection status after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    if outlookCalendarStatus == .granted {
                                        updateConnectionStatus(for: "Outlook", requested: false, connected: true)
                                    }
                                }
                            }
                        },
                        showSettingsButton: false
                    )

                    // Outlook Account & Calendar Management
                    if outlookCalendarManager.isSignedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            // Account Information
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                    Text("Outlook Account")
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                    Spacer()
                                    Button("Manage") {
                                        outlookCalendarManager.showAccountManagementSheet()
                                    }
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                }

                                if let account = outlookCalendarManager.currentAccount {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(account.shortDisplayName)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text(account.email)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                    }
                                    .padding(.leading, 20)
                                }
                            }

                            Divider()

                            // Calendar Selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                        .foregroundColor(.blue)
                                    Text("Selected Calendar")
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                    Spacer()
                                    Button("Change") {
                                        outlookCalendarManager.showCalendarSelectionSheet()
                                    }
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                }

                                if let selectedCalendar = outlookCalendarManager.selectedCalendar {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: selectedCalendar.color ?? "#0078d4"))
                                            .frame(width: 12, height: 12)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedCalendar.displayName)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text("Owner: \(selectedCalendar.owner)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                } else {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("No calendar selected")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("App Permissions") {
                    NavigationLink(destination: AppPermissionsView(voiceManager: voiceManager, fontManager: fontManager)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.blue)
                                Text("App Permissions")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status icons row (content display area)
                            HStack(spacing: 16) {
                                // Microphone status
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(voiceManager.hasRecordingPermission ? .green : .red)
                                        .font(.caption)
                                    Text("Mic")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Location status
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(hasLocationPermission ? .green : .red)
                                        .font(.caption)
                                    Text("Location")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Notification status
                                HStack(spacing: 4) {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(hasNotificationPermission ? .green : .red)
                                        .font(.caption)
                                    Text("Notifications")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("Smart Notifications") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.blue)
                            Text("Notification Settings")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                }

                Section("Event Tasks") {
                    NavigationLink(destination: TaskSettingsView(fontManager: fontManager)) {
                        HStack {
                            Image(systemName: "checklist")
                                .foregroundColor(.blue)
                            Text("Event Tasks & Preparation")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                }

                Section("Morning Briefing") {
                    NavigationLink(destination: MorningBriefingSettingsView(fontManager: fontManager)) {
                        HStack {
                            Image(systemName: "sun.horizon.fill")
                                .foregroundColor(.orange)
                            Text("Daily Briefing Settings")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }

                    NavigationLink(destination: MorningBriefingView(calendarManager: calendarManager, fontManager: fontManager)) {
                        HStack {
                            Image(systemName: "newspaper.fill")
                                .foregroundColor(.blue)
                            Text("View Today's Briefing")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                }

                Section("Calendar Auto-Routing") {
                    NavigationLink(destination: CalendarAutoRoutingView(fontManager: fontManager)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(.blue)
                                Text("Calendar Auto-Routing")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            VStack(alignment: .leading, spacing: 6) {
                                // Work calendar status
                                HStack(spacing: 8) {
                                    Image(systemName: "briefcase.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                    Text("Work:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCalendarName(defaultWorkCalendar))
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // Personal calendar status
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.green)
                                        .font(.caption2)
                                    Text("Personal:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCalendarName(defaultPersonalCalendar))
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // Default calendar status
                                HStack(spacing: 8) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption2)
                                    Text("Default:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCalendarName(defaultFallbackCalendar))
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("Display Settings") {
                    NavigationLink(destination: DisplaySettingsView(fontManager: fontManager, appearanceManager: appearanceManager, selectedLanguage: $selectedLanguage)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .foregroundColor(.blue)
                                Text("Display Settings")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            VStack(alignment: .leading, spacing: 6) {
                                // Font size status
                                HStack(spacing: 8) {
                                    Image(systemName: "textformat.size")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                    Text("Font:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(fontManager.currentFontSize.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // Appearance status
                                HStack(spacing: 8) {
                                    Image(systemName: appearanceManager.currentMode.icon)
                                        .foregroundColor(.purple)
                                        .font(.caption2)
                                    Text("Theme:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(appearanceManager.currentMode.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // Language status
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.green)
                                        .font(.caption2)
                                    Text("Language:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(getLanguageDisplayName(selectedLanguage))
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("AI Integration") {
                    NavigationLink(destination: AIIntegrationSettingsView(
                        fontManager: fontManager,
                        selectedAIProvider: $selectedAIProvider,
                        selectedProcessingMode: $selectedProcessingMode,
                        anthropicAPIKey: $anthropicAPIKey,
                        openaiAPIKey: $openaiAPIKey,
                        isAnthropicKeyVisible: $isAnthropicKeyVisible,
                        isOpenAIKeyVisible: $isOpenAIKeyVisible,
                        showingAPIKeyAlert: $showingAPIKeyAlert
                    )) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.blue)
                                Text("AI Integration")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            VStack(alignment: .leading, spacing: 6) {
                                // AI Provider status
                                HStack(spacing: 8) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.blue)
                                        .font(.caption2)
                                    Text("Provider:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(selectedAIProvider.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // Processing mode status
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu")
                                        .foregroundColor(.purple)
                                        .font(.caption2)
                                    Text("Mode:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(selectedProcessingMode.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }

                                // API Key status
                                HStack(spacing: 8) {
                                    Image(systemName: Config.hasValidAPIKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(Config.hasValidAPIKey ? .green : .orange)
                                        .font(.caption2)
                                    Text("API Key:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(Config.hasValidAPIKey ? "Configured" : "Required")
                                        .font(.caption2)
                                        .foregroundColor(Config.hasValidAPIKey ? .green : .orange)
                                    Spacer()
                                }
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("Voice Settings") {
                    NavigationLink(destination: AISettingsView()) {
                        HStack {
                            Image(systemName: "waveform.circle")
                                .foregroundColor(.purple)
                            Text("Voice & Output Settings")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
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
                    NavigationLink(destination: SyncNotificationSettingsView(
                        calendarManager: calendarManager,
                        fontManager: fontManager,
                        notificationsEnabled: $notificationsEnabled,
                        autoSyncEnabled: $autoSyncEnabled
                    )) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                Text("Sync & Notifications")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            HStack(spacing: 16) {
                                // Auto sync status
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(autoSyncEnabled ? .green : .orange)
                                        .font(.caption)
                                    Text("Auto Sync")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Notifications status
                                HStack(spacing: 4) {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(notificationsEnabled ? .green : .orange)
                                        .font(.caption)
                                    Text("Notifications")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.cyan.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("About App") {
                    NavigationLink(destination: AboutAppView(fontManager: fontManager)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("About CalAI")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            HStack(spacing: 16) {
                                // Version info
                                HStack(spacing: 4) {
                                    Image(systemName: "gear")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Text("v1.0.0")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Developer info
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("CalAI Team")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.indigo.opacity(0.05))
                        .cornerRadius(10)
                    }
                }

                Section("Data Management") {
                    NavigationLink(destination: DataManagementView(
                        calendarManager: calendarManager,
                        fontManager: fontManager
                    )) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "internaldrive")
                                    .foregroundColor(.blue)
                                Text("Data Management")
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            // Status indicators row (content display area)
                            HStack(spacing: 16) {
                                // Sync status
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Sync")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                // Cache status
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Cache: 3.3 MB")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
            }
            .background(Color.clear)
            .environment(\.sizeCategory, sizeCategory)
        }
        .alert("Get \(selectedAIProvider.displayName) API Key", isPresented: $showingAPIKeyAlert) {
                Button("Open Console", action: {
                    let url: String
                    switch selectedAIProvider {
                    case .anthropic:
                        url = "https://console.anthropic.com/settings/keys"
                    case .openai:
                        url = "https://platform.openai.com/api-keys"
                    case .onDevice:
                        url = "https://www.apple.com/ios/apple-intelligence/"
                    }
                    if let consoleURL = URL(string: url) {
                        UIApplication.shared.open(consoleURL)
                    }
                })
                Button("Cancel", role: .cancel) { }
            } message: {
                switch selectedAIProvider {
                case .anthropic:
                    Text("1. Go to console.anthropic.com\n2. Sign up or log in\n3. Navigate to 'API Keys'\n4. Create a new API key\n5. Copy and paste it here")
                case .openai:
                    Text("1. Go to platform.openai.com\n2. Sign up or log in\n3. Navigate to 'API Keys'\n4. Create a new API key\n5. Copy and paste it here")
                case .onDevice:
                    Text("On-Device AI uses Apple Intelligence Foundation Models and doesn't require an API key.\n\nRequirements:\n• iOS 26.0 or later\n• Apple Intelligence enabled\n• A17 Pro or M-series chip")
                }
            }
            .sheet(isPresented: $outlookCalendarManager.showCalendarSelection) {
                OutlookCalendarSelectionView(outlookCalendarManager: outlookCalendarManager)
            }
            .sheet(isPresented: $outlookCalendarManager.showAccountManagement) {
                OutlookAccountManagementView(outlookCalendarManager: outlookCalendarManager)
            }
            .sheet(isPresented: $outlookCalendarManager.showCredentialInput) {
                OutlookCredentialInputView(outlookCalendarManager: outlookCalendarManager)
            }
            .onAppear {
                PerformanceMonitor.shared.startMeasuring("Settings Tab Load")

                // Defer permission checks to avoid blocking UI
                DispatchQueue.main.async {
                    checkPermissions()
                    PerformanceMonitor.shared.stopMeasuring("Settings Tab Load")
                    MemoryMonitor.logMemoryUsage(context: "Settings Tab Loaded")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Permission Methods

    private func checkPermissions() {
        // Check permissions asynchronously to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Check location permission (synchronous but fast)
            DispatchQueue.main.async {
                self.checkLocationPermission()
            }

            // Check notification permission (already async)
            self.checkNotificationPermission()
        }

        // Defer calendar access check to avoid blocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Refresh calendar access status (this checks current status without prompting)
            self.calendarManager.requestCalendarAccess()
        }

        // Initialize connection timestamps for already connected services
        initializeConnectionTimestamps()

        // Google and Outlook managers' isSignedIn properties are already @Published
        // and will automatically update the UI when they change

        // VoiceManager's hasRecordingPermission is already @Published and updates automatically
        // It's checked in the init() method
    }

    private func initializeConnectionTimestamps() {
        let now = Date()

        // iOS Calendar - if already connected but no timestamps, set both to now
        if calendarManager.hasCalendarAccess {
            if iOSCalendarConnectedAt == nil {
                iOSCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "iOSCalendarConnectedAt")
            }
            // If connected but no request timestamp, set it to the connected time
            if iOSCalendarLastRequested == nil {
                let requestTime = iOSCalendarConnectedAt ?? now
                iOSCalendarLastRequested = requestTime
                UserDefaults.standard.set(requestTime, forKey: "iOSCalendarLastRequested")
            }
        }

        // Google Calendar - if already signed in but no timestamps, set both to now
        if googleCalendarManager.isSignedIn {
            if googleCalendarConnectedAt == nil {
                googleCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "googleCalendarConnectedAt")
            }
            // If connected but no request timestamp, set it to the connected time
            if googleCalendarLastRequested == nil {
                let requestTime = googleCalendarConnectedAt ?? now
                googleCalendarLastRequested = requestTime
                UserDefaults.standard.set(requestTime, forKey: "googleCalendarLastRequested")
            }
        }

        // Outlook Calendar - if already connected but no timestamps, set both to now
        if outlookCalendarStatus == .granted {
            if outlookCalendarConnectedAt == nil {
                outlookCalendarConnectedAt = now
                UserDefaults.standard.set(now, forKey: "outlookCalendarConnectedAt")
            }
            // If connected but no request timestamp, set it to the connected time
            if outlookCalendarLastRequested == nil {
                let requestTime = outlookCalendarConnectedAt ?? now
                outlookCalendarLastRequested = requestTime
                UserDefaults.standard.set(requestTime, forKey: "outlookCalendarLastRequested")
            }
        }
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

struct OutlookCalendarSelectionView: View {
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(outlookCalendarManager.availableCalendars) { calendar in
                        CalendarRow(
                            calendar: calendar,
                            isSelected: outlookCalendarManager.selectedCalendar?.id == calendar.id
                        ) {
                            outlookCalendarManager.selectCalendar(calendar)
                        }
                    }
                } header: {
                    Text("Select Outlook Calendar")
                } footer: {
                    Text("Choose which Outlook calendar you want to sync with CalAI.")
                }
            }
            .navigationTitle("Outlook Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CalendarRow: View {
    let calendar: OutlookCalendar
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(Color(hex: calendar.color ?? "#0078d4"))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(calendar.owner)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OutlookAccountManagementView: View {
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if let account = outlookCalendarManager.currentAccount {
                    Section {
                        // Account Info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.shortDisplayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(account.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let tenantId = account.tenantId {
                                    Text("Tenant: \(tenantId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Text("●")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Current Account")
                    }

                    Section {
                        Button(action: {
                            outlookCalendarManager.switchAccount()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Switch Account")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        Button(action: {
                            outlookCalendarManager.signOut()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "power")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } header: {
                        Text("Account Actions")
                    } footer: {
                        Text("Switching accounts will sign you out and allow you to sign in with a different Outlook account.")
                    }
                }
            }
            .navigationTitle("Account Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OutlookCredentialInputView: View {
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sign in to Outlook")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Enter your Microsoft account credentials to connect your Outlook calendar.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                TextField("Enter your email address", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .keyboardType(.emailAddress)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack {
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }

                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        if let error = outlookCalendarManager.signInError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        }

                        VStack(spacing: 12) {
                            Button(action: {
                                signInTapped()
                            }) {
                                HStack {
                                    if outlookCalendarManager.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "envelope")
                                    }
                                    Text(outlookCalendarManager.isLoading ? "Signing In..." : "Sign In with Credentials")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSignIn ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(!canSignIn || outlookCalendarManager.isLoading)

                            Text("OR")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                signInWithOAuth()
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Sign In with Microsoft OAuth")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(outlookCalendarManager.isLoading)
                        }
                        .padding(.top, 16)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your credentials are processed securely and are not stored by CalAI.")

                        Text("For demo purposes, any valid email format and password (6+ characters) will work.")
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Outlook Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private func signInTapped() {
        outlookCalendarManager.signInWithCredentials(email: email, password: password)
    }

    private func signInWithOAuth() {
        dismiss() // Close the credential input sheet
        outlookCalendarManager.signInWithOAuth() // Start OAuth flow
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

struct CalendarPermissionRow: View {
    let title: String
    let systemImage: String
    let status: PermissionStatus
    let lastRequested: Date?
    let connectedAt: Date?
    let action: () -> Void
    let showSettingsButton: Bool

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            // Sub-status rows
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Last requested:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(lastRequested))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 24)

                HStack {
                    Text("Connected at:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(connectedAt))
                        .font(.caption)
                        .foregroundColor(connectedAt != nil ? .green : .secondary)
                }
                .padding(.leading, 24)

                // Show Settings button only when permission is denied, last requested is not nil, AND showSettingsButton is true
                if status == .notGranted && lastRequested != nil && showSettingsButton {
                    HStack {
                        Text("Need access?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .padding(.leading, 24)
                }
            }
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
            return .yellow
        case .unknown:
            return .orange
        }
    }

    var text: String {
        switch self {
        case .granted:
            return "Connected"
        case .notGranted:
            return "Click here to connect"
        case .unknown:
            return "Setup"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}