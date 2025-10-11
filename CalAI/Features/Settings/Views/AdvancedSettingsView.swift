import SwiftUI

/// Advanced app customization and preferences
struct AdvancedSettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = false
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("reducedMotion") private var reducedMotion = false
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 15
    @AppStorage("defaultEventDuration") private var defaultEventDuration = 60
    @AppStorage("calendarStartDay") private var calendarStartDay = 0 // 0 = Sunday
    @AppStorage("timeFormat24Hour") private var timeFormat24Hour = false
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("notificationSound") private var notificationSound = "Default"
    @AppStorage("badgeCount") private var badgeCount = true

    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                // Appearance Section
                Section {
                    Toggle("Compact Mode", isOn: $compactMode)
                    Toggle("Animations", isOn: $animationsEnabled)
                    Toggle("Reduced Motion", isOn: $reducedMotion)
                    Toggle("Show Week Numbers", isOn: $showWeekNumbers)
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                } footer: {
                    Text("Customize the visual appearance of CalAI")
                }

                // Feedback Section
                Section {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled.onChange(handleHapticsToggle))
                    Toggle("Sound Effects", isOn: $soundEffectsEnabled)

                    Picker("Notification Sound", selection: $notificationSound) {
                        Text("Default").tag("Default")
                        Text("Chime").tag("Chime")
                        Text("Bell").tag("Bell")
                        Text("None").tag("None")
                    }
                } header: {
                    Label("Feedback", systemImage: "speaker.wave.2")
                } footer: {
                    Text("Control haptic and audio feedback")
                }

                // Calendar Preferences
                Section {
                    Picker("Week Starts On", selection: $calendarStartDay) {
                        Text("Sunday").tag(0)
                        Text("Monday").tag(1)
                        Text("Saturday").tag(6)
                    }

                    Picker("Default Event Duration", selection: $defaultEventDuration) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }

                    Toggle("24-Hour Time Format", isOn: $timeFormat24Hour)
                } header: {
                    Label("Calendar", systemImage: "calendar")
                } footer: {
                    Text("Customize calendar display and defaults")
                }

                // Sync & Performance
                Section {
                    Picker("Auto-Refresh Interval", selection: $autoRefreshInterval) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("Manual").tag(0)
                    }

                    Toggle("Badge Count", isOn: $badgeCount)

                    Button("Clear Cache") {
                        clearCache()
                    }
                    .foregroundColor(.blue)
                } header: {
                    Label("Sync & Performance", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text("Configure sync and app performance settings")
                }

                // Accessibility
                Section {
                    NavigationLink(destination: AccessibilitySettingsView()) {
                        Label("Accessibility Options", systemImage: "accessibility")
                    }

                    NavigationLink(destination: TutorialLauncherView()) {
                        Label("View Tutorials", systemImage: "graduationcap")
                    }
                } header: {
                    Label("Help & Accessibility", systemImage: "person.fill.questionmark")
                }

                // Privacy & Security
                Section {
                    NavigationLink(destination: CrashReportingSettingsView()) {
                        Label("Crash Reporting", systemImage: "exclamationmark.triangle")
                    }

                    NavigationLink(destination: AnalyticsSettingsView()) {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }

                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    NavigationLink(destination: TermsOfServiceView()) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                } header: {
                    Label("Privacy & Security", systemImage: "lock.shield")
                }

                // Advanced
                Section {
                    NavigationLink(destination: DiagnosticsView()) {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }

                    NavigationLink(destination: AboutView()) {
                        Label("About CalAI", systemImage: "info.circle")
                    }

                    Button("Reset All Settings") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Label("Advanced", systemImage: "gearshape.2")
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Reset All Settings?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetAllSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func handleHapticsToggle(_ enabled: Bool) {
        HapticManager.shared.setEnabled(enabled)
        if enabled {
            HapticManager.shared.success()
        }
    }

    private func clearCache() {
        CacheManager.shared.clearAll()
        AssetOptimizer.shared.clearAllImages()
        HapticManager.shared.success()
    }

    private func resetAllSettings() {
        hapticsEnabled = true
        soundEffectsEnabled = false
        animationsEnabled = true
        reducedMotion = false
        autoRefreshInterval = 15
        defaultEventDuration = 60
        calendarStartDay = 0
        timeFormat24Hour = false
        showWeekNumbers = false
        compactMode = false
        notificationSound = "Default"
        badgeCount = true

        TutorialCoordinator.shared.resetAllProgress()

        HapticManager.shared.success()
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettingsView: View {
    @AppStorage("largeText") private var largeText = false
    @AppStorage("boldText") private var boldText = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("colorBlindMode") private var colorBlindMode = false
    @AppStorage("voiceOverOptimized") private var voiceOverOptimized = false

    var body: some View {
        Form {
            Section {
                Toggle("Large Text", isOn: $largeText)
                Toggle("Bold Text", isOn: $boldText)
                Toggle("High Contrast", isOn: $highContrast)
            } header: {
                Text("Visual")
            } footer: {
                Text("Adjust visual elements for better readability")
            }

            Section {
                Toggle("Color Blind Mode", isOn: $colorBlindMode)
                Picker("Color Scheme", selection: $colorBlindMode) {
                    Text("Standard").tag(false)
                    Text("Deuteranopia").tag(true)
                }
            } header: {
                Text("Color Adjustments")
            }

            Section {
                Toggle("VoiceOver Optimizations", isOn: $voiceOverOptimized)
            } header: {
                Text("Screen Reader")
            } footer: {
                Text("Enable additional optimizations for VoiceOver users")
            }

            Section {
                Link("iOS Accessibility Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .foregroundColor(.blue)
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @State private var metrics: PerformanceMetrics?
    @State private var cacheStats: CacheStats?

    var body: some View {
        Form {
            Section("Performance Metrics") {
                if let metrics = metrics {
                    LabeledContent("Memory Usage", value: metrics.formattedMemory)
                    LabeledContent("CPU Usage", value: metrics.formattedCPU)
                } else {
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }

                Button("Refresh Metrics") {
                    loadMetrics()
                }
            }

            Section("Cache Statistics") {
                if let stats = cacheStats {
                    LabeledContent("Disk Cache Size", value: stats.formattedDiskSize)
                    LabeledContent("Cache Location", value: stats.diskCacheURL.lastPathComponent)
                } else {
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }

                Button("Clear All Caches") {
                    clearAllCaches()
                }
                .foregroundColor(.red)
            }

            Section("App Information") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
            }

            Section("Debug Actions") {
                Button("Generate Test Data") {
                    generateTestData()
                }

                Button("Export Logs") {
                    exportLogs()
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMetrics()
            loadCacheStats()
        }
    }

    private func loadMetrics() {
        metrics = AppLaunchOptimizer.shared.monitorPerformance()
    }

    private func loadCacheStats() {
        cacheStats = CacheManager.shared.getCacheStats()
    }

    private func clearAllCaches() {
        CacheManager.shared.clearAll()
        AssetOptimizer.shared.clearAllImages()
        loadCacheStats()
        HapticManager.shared.success()
    }

    private func generateTestData() {
        print("📊 Generating test data...")
        HapticManager.shared.light()
    }

    private func exportLogs() {
        print("📤 Exporting logs...")
        HapticManager.shared.light()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("CalAI")
                        .font(.title.bold())

                    Text("Your Intelligent Calendar Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section("Features") {
                FeatureRow(icon: "brain.head.profile", title: "AI-Powered", description: "Smart event suggestions")
                FeatureRow(icon: "calendar.circle", title: "Multi-Calendar", description: "iOS, Google, Outlook")
                FeatureRow(icon: "bell.badge", title: "Smart Notifications", description: "Context-aware alerts")
                FeatureRow(icon: "waveform", title: "Voice Input", description: "Natural language processing")
            }

            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://calai.app/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://calai.app/terms")!)
                Link("Open Source Licenses", destination: URL(string: "https://calai.app/licenses")!)
            }

            Section("Support") {
                Link("Help Center", destination: URL(string: "https://help.calai.app")!)
                Link("Report a Bug", destination: URL(string: "mailto:support@calai.app?subject=Bug%20Report")!)
                Link("Request a Feature", destination: URL(string: "mailto:support@calai.app?subject=Feature%20Request")!)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Binding Extension for onChange

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

// MARK: - Preview

#Preview("Advanced Settings") {
    AdvancedSettingsView()
}

#Preview("Accessibility Settings") {
    NavigationView {
        AccessibilitySettingsView()
    }
}

#Preview("Diagnostics") {
    NavigationView {
        DiagnosticsView()
    }
}

#Preview("About") {
    NavigationView {
        AboutView()
    }
}
