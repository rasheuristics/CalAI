import SwiftUI

struct AboutAppView: View {
    @ObservedObject var fontManager: FontManager

    var body: some View {
        Form {
            Section(header: Text("App Information")) {
                VStack(alignment: .center, spacing: 16) {
                    // App Icon
                    Image(systemName: "calendar.badge.gearshape")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                        )

                    VStack(spacing: 6) {
                        Text("CalAI")
                            .dynamicFont(size: 24, weight: .bold, fontManager: fontManager)
                            .foregroundColor(.primary)

                        Text("Intelligent Calendar Assistant")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section(header: Text("Version & Build")) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Version")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "hammer")
                        .foregroundColor(.blue)
                    Text("Build")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("2024.11.001")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    Text("Platform")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("iOS \(UIDevice.current.systemVersion)+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Release Date")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("November 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Development Team")) {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                    Text("Developer")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("CalAI Team")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI Integration")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("Anthropic Claude & OpenAI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "swift")
                        .foregroundColor(.orange)
                    Text("Technology")
                        .dynamicFont(size: 16, fontManager: fontManager)
                    Spacer()
                    Text("SwiftUI & Swift")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Features")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Key Features")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "calendar.badge.gearshape",
                                 title: "Multi-Calendar Integration",
                                 description: "iOS, Google, Outlook support")

                        FeatureRow(icon: "brain.head.profile",
                                 title: "AI-Powered Assistance",
                                 description: "Natural language processing")

                        FeatureRow(icon: "mic.circle",
                                 title: "Voice Interaction",
                                 description: "Hands-free calendar management")

                        FeatureRow(icon: "bell.badge",
                                 title: "Smart Notifications",
                                 description: "Context-aware reminders")

                        FeatureRow(icon: "sun.horizon",
                                 title: "Daily Briefings",
                                 description: "Morning insights & planning")

                        FeatureRow(icon: "arrow.triangle.branch",
                                 title: "Auto-Routing",
                                 description: "Intelligent event categorization")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }

            Section(header: Text("Legal & Privacy")) {
                Button(action: {
                    // Open privacy policy
                    if let url = URL(string: "https://example.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.blue)
                        Text("Privacy Policy")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button(action: {
                    // Open terms of service
                    if let url = URL(string: "https://example.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("Terms of Service")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button(action: {
                    // Open licenses
                }) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .foregroundColor(.blue)
                        Text("Open Source Licenses")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                    }
                }
            }

            Section(header: Text("Support & Feedback")) {
                Button(action: {
                    // Open support email
                    if let url = URL(string: "mailto:support@calai.app?subject=CalAI Support Request") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("Contact Support")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("support@calai.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    // Open GitHub issues
                    if let url = URL(string: "https://github.com/calai/feedback/issues") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundColor(.blue)
                        Text("Report a Bug")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Button(action: {
                    // Open app store review
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/idXXXXXXXXX?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "star")
                            .foregroundColor(.blue)
                        Text("Rate CalAI")
                            .foregroundColor(.blue)
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("App Store")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Copyright")) {
                VStack(alignment: .center, spacing: 8) {
                    Text("© 2024 CalAI Team")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Made with ❤️ for better calendar management")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("About CalAI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AboutAppView(fontManager: FontManager())
    }
}