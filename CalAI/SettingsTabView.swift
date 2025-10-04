import SwiftUI

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
    @State private var showingAPIKeyAlert = false
    @State private var isAnthropicKeyVisible = false
    @State private var isOpenAIKeyVisible = false

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
                    PermissionRow(
                        title: "iOS Calendar",
                        systemImage: "calendar",
                        status: calendarManager.hasCalendarAccess ? .granted : .notGranted,
                        action: {
                            calendarManager.requestCalendarAccess()
                        }
                    )

                    PermissionRow(
                        title: "Google Calendar",
                        systemImage: "globe",
                        status: googleCalendarManager.isSignedIn ? .granted : .notGranted,
                        action: {
                            if googleCalendarManager.isSignedIn {
                                googleCalendarManager.signOut()
                            } else {
                                googleCalendarManager.signIn()
                            }
                        }
                    )

                    PermissionRow(
                        title: "Outlook Calendar",
                        systemImage: "envelope",
                        status: outlookCalendarStatus,
                        action: {
                            if outlookCalendarManager.isSignedIn {
                                if outlookCalendarManager.selectedCalendar == nil {
                                    // If signed in but no calendar selected, show calendar selection
                                    outlookCalendarManager.showCalendarSelectionSheet()
                                } else {
                                    // If fully configured, sign out
                                    outlookCalendarManager.signOut()
                                }
                            } else {
                                // If not signed in, start sign in process
                                outlookCalendarManager.signIn()
                            }
                        }
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

                    HStack {
                        Image(systemName: appearanceManager.currentMode.icon)
                            .foregroundColor(.blue)
                        Text("Appearance")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Picker("Appearance", selection: $appearanceManager.currentMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    }
                }

                Section("AI Integration") {
                    VStack(alignment: .leading, spacing: 12) {
                        // AI Provider Selection
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            Text("AI Provider")
                                .dynamicFont(size: 16, fontManager: fontManager)
                            Spacer()
                            Picker("AI Provider", selection: $selectedAIProvider) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 150)
                            .onChange(of: selectedAIProvider) { newValue in
                                Config.aiProvider = newValue
                            }
                        }

                        // Anthropic API Key Section
                        if selectedAIProvider == .anthropic {
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
                                    if isAnthropicKeyVisible {
                                        TextField("Enter your Anthropic API key", text: $anthropicAPIKey)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .onChange(of: anthropicAPIKey) { newValue in
                                                Config.anthropicAPIKey = newValue
                                            }
                                    } else {
                                        SecureField("Enter your Anthropic API key", text: $anthropicAPIKey)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .onChange(of: anthropicAPIKey) { newValue in
                                                Config.anthropicAPIKey = newValue
                                            }
                                    }

                                    Button(action: {
                                        isAnthropicKeyVisible.toggle()
                                    }) {
                                        Image(systemName: isAnthropicKeyVisible ? "eye.slash" : "eye")
                                            .foregroundColor(.blue)
                                    }
                                }

                                if !Config.hasValidAPIKey && !anthropicAPIKey.isEmpty && selectedAIProvider == .anthropic {
                                    Text("Invalid API key format. Should start with 'sk-ant-'")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        // OpenAI API Key Section
                        if selectedAIProvider == .openai {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.blue)
                                    Text("OpenAI API Key")
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                    Spacer()
                                    Image(systemName: Config.hasValidAPIKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(Config.hasValidAPIKey ? .green : .orange)
                                }

                                HStack {
                                    if isOpenAIKeyVisible {
                                        TextField("Enter your OpenAI API key", text: $openaiAPIKey)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .onChange(of: openaiAPIKey) { newValue in
                                                Config.openaiAPIKey = newValue
                                            }
                                    } else {
                                        SecureField("Enter your OpenAI API key", text: $openaiAPIKey)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .onChange(of: openaiAPIKey) { newValue in
                                                Config.openaiAPIKey = newValue
                                            }
                                    }

                                    Button(action: {
                                        isOpenAIKeyVisible.toggle()
                                    }) {
                                        Image(systemName: isOpenAIKeyVisible ? "eye.slash" : "eye")
                                            .foregroundColor(.blue)
                                    }
                                }

                                if !Config.hasValidAPIKey && !openaiAPIKey.isEmpty && selectedAIProvider == .openai {
                                    Text("Invalid API key format. Should start with 'sk-'")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        // Status and Help
                        if Config.hasValidAPIKey {
                            Text("✓ API key configured - AI features enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Add your \(selectedAIProvider.displayName) API key to enable AI-powered calendar features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            showingAPIKeyAlert = true
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                                Text("How to get \(selectedAIProvider.displayName) API key")
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
        }
        .navigationViewStyle(.stack)
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
            return "Connected"
        case .notGranted:
            return "Connect"
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