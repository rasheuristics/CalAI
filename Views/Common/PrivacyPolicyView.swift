import SwiftUI

/// Privacy Policy view that can be shown in Settings or during onboarding
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false

    let showDoneButton: Bool

    init(showDoneButton: Bool = true) {
        self.showDoneButton = showDoneButton
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.system(size: 32, weight: .bold))

                    Text("Last Updated: November 10, 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 10)

                // Key Principle
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Privacy First")
                                .font(.headline)
                            Text("Most data processing happens on your device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }

                Divider()

                // Calendar Data
                PrivacySection(
                    icon: "calendar",
                    iconColor: .blue,
                    title: "Calendar Data",
                    subtitle: "Stored Locally Only"
                ) {
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Calendar events stay on YOUR device", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "We do NOT upload events to our servers", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "We do NOT sell or share your calendar data", positive: true)
                }

                // AI Processing
                PrivacySection(
                    icon: "brain",
                    iconColor: .purple,
                    title: "AI Features",
                    subtitle: "Minimal Data Sent to Cloud"
                ) {
                    Text("When you use voice commands, we send:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    PrivacyPoint(icon: "arrow.up.circle", text: "Your voice command transcript")
                    PrivacyPoint(icon: "arrow.up.circle", text: "Minimal calendar context (e.g., \"3 events today\")")

                    Text("We do NOT send:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    PrivacyPoint(icon: "xmark.circle", text: "Full calendar event details", positive: false)
                    PrivacyPoint(icon: "xmark.circle", text: "Personal information", positive: false)
                    PrivacyPoint(icon: "xmark.circle", text: "Participant names or emails", positive: false)
                }

                // Weather/Location
                PrivacySection(
                    icon: "cloud.sun.fill",
                    iconColor: .orange,
                    title: "Weather & Location",
                    subtitle: "Used Only for Weather Forecasts"
                ) {
                    PrivacyPoint(icon: "location", text: "Approximate location (city level)")
                    PrivacyPoint(icon: "hand.raised", text: "Only when you request weather")
                    PrivacyPoint(icon: "xmark", text: "No continuous tracking", positive: false)
                }

                // Crash Reporting
                PrivacySection(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    title: "Crash Reporting",
                    subtitle: "Optional - You Control It"
                ) {
                    PrivacyPoint(icon: "hand.raised.fill", text: "OPT-IN only (disabled by default)")
                    PrivacyPoint(icon: "checkmark", text: "Helps us fix bugs and improve stability")
                    PrivacyPoint(icon: "xmark", text: "No calendar event details collected", positive: false)

                    Text("You can disable in Settings → Advanced → Crash Reporting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                Divider()

                // Third Party Services
                VStack(alignment: .leading, spacing: 12) {
                    Text("Third-Party Services We Use")
                        .font(.headline)

                    ThirdPartyService(name: "Google Calendar", purpose: "Sync your Google calendars")
                    ThirdPartyService(name: "Microsoft Outlook", purpose: "Sync your Outlook calendars")
                    ThirdPartyService(name: "OpenAI", purpose: "AI assistant features")
                    ThirdPartyService(name: "Apple WeatherKit", purpose: "Weather forecasts")

                    Text("We do NOT share data with advertisers, data brokers, or marketing companies.")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }

                Divider()

                // Your Rights
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Rights")
                        .font(.headline)

                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Access your data (stored locally)", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Delete your data anytime", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Opt-out of crash reporting", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Revoke calendar permissions", positive: true)
                    PrivacyPoint(icon: "checkmark.circle.fill", text: "Disable AI features", positive: true)
                }

                Divider()

                // Contact
                VStack(alignment: .leading, spacing: 12) {
                    Text("Questions About Privacy?")
                        .font(.headline)

                    Link(destination: URL(string: "mailto:privacy@rasheuristics.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("privacy@rasheuristics.com")
                        }
                        .foregroundColor(.blue)
                    }

                    Link(destination: URL(string: "https://rasheuristics.com/calai/privacy")!) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Full Privacy Policy")
                        }
                        .foregroundColor(.blue)
                    }
                }

                // Footer
                Text("© 2025 Rasheuristics. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showDoneButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [URL(string: "https://rasheuristics.com/calai/privacy")!])
        }
    }
}

// MARK: - Supporting Views

struct PrivacySection<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            content
                .padding(.leading, 52)
        }
    }
}

struct PrivacyPoint: View {
    let icon: String
    let text: String
    let positive: Bool

    init(icon: String, text: String, positive: Bool = true) {
        self.icon = icon
        self.text = text
        self.positive = positive
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(positive ? .green : .red)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(positive ? .primary : .secondary)
        }
    }
}

struct ThirdPartyService: View {
    let name: String
    let purpose: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(purpose)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}
