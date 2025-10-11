import SwiftUI

struct AnalyticsSettingsView: View {
    @State private var analyticsEnabled = AnalyticsService.shared.isEnabled
    @State private var showingExportSheet = false
    @State private var exportedData: String?
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            // Main Toggle
            Section {
                Toggle("Enable Analytics", isOn: $analyticsEnabled.onChange { enabled in
                    AnalyticsService.shared.setEnabled(enabled)
                    HapticManager.shared.light()
                })
            } header: {
                Label("Usage Analytics", systemImage: "chart.bar.fill")
            } footer: {
                Text("Help improve CalAI by sharing anonymous usage data. You can opt-out at any time.")
            }

            // What We Collect
            Section {
                InfoRow(
                    icon: "eye",
                    iconColor: .blue,
                    title: "What We Collect",
                    description: "Anonymous feature usage, screen views, and app performance metrics"
                )

                InfoRow(
                    icon: "checkmark.shield.fill",
                    iconColor: .green,
                    title: "Privacy First",
                    description: "All data is anonymized. No personal information, calendar data, or location is collected."
                )

                InfoRow(
                    icon: "person.fill.questionmark",
                    iconColor: .purple,
                    title: "Anonymous ID",
                    description: "We use a random ID that cannot be linked to you personally"
                )

                InfoRow(
                    icon: "hand.raised.fill",
                    iconColor: .orange,
                    title: "Opt-In Only",
                    description: "Analytics is disabled by default. You choose whether to participate."
                )
            } header: {
                Label("Privacy & Transparency", systemImage: "hand.raised.fill")
            }

            // What We Track
            if analyticsEnabled {
                Section {
                    DataPointRow(icon: "rectangle.stack.fill", text: "Screen views (which screens you visit)")
                    DataPointRow(icon: "star.fill", text: "Feature usage (which features you use)")
                    DataPointRow(icon: "exclamationmark.triangle.fill", text: "Error reports (app crashes and errors)")
                    DataPointRow(icon: "speedometer", text: "Performance metrics (app speed and responsiveness)")
                    DataPointRow(icon: "gear", text: "Setting changes (which preferences you adjust)")
                } header: {
                    Label("Data We Collect", systemImage: "list.bullet.clipboard")
                } footer: {
                    Text("This data helps us understand which features are most valuable and where to focus improvements.")
                }
            }

            // What We DON'T Track
            Section {
                DataPointRow(icon: "calendar", text: "Calendar event content", color: .red)
                DataPointRow(icon: "envelope.fill", text: "Personal messages or emails", color: .red)
                DataPointRow(icon: "person.fill", text: "Your name or email address", color: .red)
                DataPointRow(icon: "location.fill", text: "Your location or whereabouts", color: .red)
                DataPointRow(icon: "doc.text.fill", text: "Document or file contents", color: .red)
                DataPointRow(icon: "creditcard.fill", text: "Payment or financial information", color: .red)
            } header: {
                Label("What We DON'T Collect", systemImage: "xmark.shield.fill")
            } footer: {
                Text("We never collect personal information, calendar data, location, or any sensitive content.")
            }

            // Data Management
            if analyticsEnabled {
                Section {
                    Button(action: {
                        exportedData = AnalyticsService.shared.exportAnalyticsData()
                        showingExportSheet = true
                    }) {
                        Label("View My Analytics Data", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Label("Clear Analytics Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Label("Data Management", systemImage: "folder.fill")
                } footer: {
                    Text("You can view or delete your analytics data at any time.")
                }
            }

            // How We Use Data
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(number: "1", text: "Understand which features are most used")
                    UsageRow(number: "2", text: "Identify and fix bugs faster")
                    UsageRow(number: "3", text: "Improve app performance")
                    UsageRow(number: "4", text: "Prioritize new feature development")
                    UsageRow(number: "5", text: "Make data-driven product decisions")
                }
            } header: {
                Label("How We Use This Data", systemImage: "lightbulb.fill")
            }

            // Example Events (Debug)
            #if DEBUG
            Section {
                Button("Test Analytics Event") {
                    AnalyticsService.shared.trackEvent(.screenView(screenName: "Test Screen", parameters: ["test": true]))
                    HapticManager.shared.success()
                }

                Button("Track Feature Usage") {
                    AnalyticsService.shared.trackFeatureUsage("Test Feature", parameters: ["action": "test"])
                    HapticManager.shared.success()
                }

                Button("Track Error") {
                    let testError = NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test error"])
                    AnalyticsService.shared.trackError(testError, context: "Testing")
                    HapticManager.shared.success()
                }
            } header: {
                Label("Debug Tools", systemImage: "hammer.fill")
            } footer: {
                Text("These buttons are only visible in debug builds.")
            }
            #endif
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportedData {
                NavigationView {
                    ScrollView {
                        Text(data)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .navigationTitle("Analytics Data")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingExportSheet = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            ShareLink(item: data)
                        }
                    }
                }
            } else {
                Text("No analytics data available")
                    .foregroundColor(.secondary)
            }
        }
        .confirmationDialog(
            "Clear Analytics Data?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                AnalyticsService.shared.clearAnalyticsData()
                HapticManager.shared.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all locally stored analytics data. This action cannot be undone.")
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DataPointRow: View {
    let icon: String
    let text: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .foregroundColor(color)
        }
    }
}

struct UsageRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AnalyticsSettingsView()
    }
}
