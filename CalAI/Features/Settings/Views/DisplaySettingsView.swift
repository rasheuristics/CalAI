import SwiftUI

struct DisplaySettingsView: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @Binding var selectedLanguage: String

    var body: some View {
        Form {
            Section(header: Text("Font & Text"),
                   footer: Text("Adjust text size for better readability. Changes apply app-wide.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.blue)
                        Text("Font Size")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                    }

                    Picker("Font Size", selection: $fontManager.currentFontSize) {
                        Text("Small").tag(FontSize.small)
                        Text("Medium").tag(FontSize.medium)
                        Text("Large").tag(FontSize.large)
                        Text("Extra Large").tag(FontSize.extraLarge)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // Font preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Sample event title with dynamic text")
                            .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
            }

            Section(header: Text("Appearance"),
                   footer: Text("Choose between light mode, dark mode, or let the app follow your device's appearance settings.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: appearanceManager.currentMode.icon)
                            .foregroundColor(.blue)
                        Text("Theme")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                    }

                    Picker("Appearance", selection: $appearanceManager.currentMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // Theme preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: appearanceManager.backgroundGradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(appearanceManager.strokeOpacity), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current theme:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(appearanceManager.currentMode.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appearanceManager.cardGlassColor.opacity(appearanceManager.glassOpacity))
                        )
                    }
                    .padding(.top, 8)
                }
            }

            Section(header: Text("Language & Region"),
                   footer: Text("Select your preferred language for the app interface. This affects date formats, text, and voice responses.")) {

                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text("Language")
                        .dynamicFont(size: 16, fontManager: fontManager)
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
            }

            Section(header: Text("Accessibility"),
                   footer: Text("CalAI supports iOS Dynamic Type and accessibility features. These settings work alongside your device's accessibility preferences.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "accessibility")
                            .foregroundColor(.green)
                        Text("Accessibility Features")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Dynamic Type Support")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("High Contrast Colors")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        HStack {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("VoiceOver Compatible")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Haptic Feedback")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }

            Section(header: Text("Visual Effects")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Glassmorphism Effects")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                        Text("Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Blur and transparency effects")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Dynamic gradient backgrounds")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Adaptive to light/dark mode")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Optimized for performance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }
        }
        .navigationTitle("Display Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DisplaySettingsView(
            fontManager: FontManager(),
            appearanceManager: AppearanceManager(),
            selectedLanguage: .constant("en-US")
        )
    }
}