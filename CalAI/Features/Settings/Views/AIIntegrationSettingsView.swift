import SwiftUI

struct AIIntegrationSettingsView: View {
    @ObservedObject var fontManager: FontManager
    @Binding var selectedAIProvider: AIProvider
    @Binding var selectedProcessingMode: AIProcessingMode
    @Binding var anthropicAPIKey: String
    @Binding var openaiAPIKey: String
    @Binding var isAnthropicKeyVisible: Bool
    @Binding var isOpenAIKeyVisible: Bool
    @Binding var showingAPIKeyAlert: Bool

    /// Check if FoundationModels framework is available for Apple Intelligence
    private func checkFoundationModels() -> Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        Form {
            Section(header: Text("AI Provider"),
                   footer: Text("Choose which AI service to use for calendar intelligence and natural language processing.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI Provider")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                    }

                    Picker("AI Provider", selection: $selectedAIProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedAIProvider) { newValue in
                        Config.aiProvider = newValue
                    }
                }
            }

            Section(header: Text("Device Compatibility"),
                   footer: Text("Information about AI features available on your device based on iOS version and hardware capabilities.")) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.gray)
                        Text("Device Compatibility")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    let iOSMajorVersion = Int(UIDevice.current.systemVersion.components(separatedBy: ".").first ?? "0") ?? 0
                    let hasFoundationModels = checkFoundationModels()
                    let supportsOnDeviceAI = iOSMajorVersion >= 26 && hasFoundationModels

                    VStack(alignment: .leading, spacing: 8) {
                        // Compatibility status
                        if supportsOnDeviceAI {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("✅ Apple Intelligence + Cloud AI")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        } else if iOSMajorVersion >= 17 {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                Text("🌐 Cloud AI Only (iOS \(iOSMajorVersion))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("📱 Basic Support (iOS \(iOSMajorVersion))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }

                        // Device information
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("iOS Version:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(UIDevice.current.systemVersion)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }

                            HStack {
                                Text("Device Model:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(UIDevice.current.model)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }

                            HStack {
                                Text("Foundation Models:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(hasFoundationModels ? "Available" : "Not Available")
                                    .font(.caption)
                                    .foregroundColor(hasFoundationModels ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(6)
                    }

                    // Show warning if on-device AI selected but not supported
                    if selectedAIProvider == .onDevice && !supportsOnDeviceAI {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Apple Intelligence Not Available")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }

                            if iOSMajorVersion < 26 {
                                Text("Your device (iOS \(iOSMajorVersion)) doesn't support Apple Intelligence. Requires iOS 26+ with A17 Pro/M-series chip or newer. Using cloud AI instead.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Your device doesn't support Apple Intelligence. Requires A17 Pro/M-series chip or newer. Using cloud AI instead.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Show performance tips for older devices
                    if iOSMajorVersion < 17 || !supportsOnDeviceAI {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.blue)
                                Text("Performance Tips")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                if !supportsOnDeviceAI {
                                    Text("• Use cloud AI (Anthropic/OpenAI) for best results")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if iOSMajorVersion < 17 {
                                    Text("• Update to iOS 17+ for better performance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("• Ensure stable internet connection for cloud AI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Section(header: Text("Processing Mode"),
                   footer: Text(selectedProcessingMode.description)) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        Text("Processing Mode")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Spacer()
                    }

                    Picker("Processing Mode", selection: $selectedProcessingMode) {
                        ForEach(AIProcessingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedProcessingMode) { newValue in
                        Config.aiProcessingMode = newValue
                    }
                }
            }

            // Anthropic API Key Section
            if selectedAIProvider == .anthropic {
                Section(header: Text("Anthropic Configuration"),
                       footer: Text("Enter your Anthropic API key to enable Claude AI features. Your key is stored securely on your device.")) {

                    VStack(alignment: .leading, spacing: 12) {
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
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text("Invalid API key format. Should start with 'sk-ant-'")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            // OpenAI API Key Section
            if selectedAIProvider == .openai {
                Section(header: Text("OpenAI Configuration"),
                       footer: Text("Enter your OpenAI API key to enable GPT features. Your key is stored securely on your device.")) {

                    VStack(alignment: .leading, spacing: 12) {
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
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text("Invalid API key format. Should start with 'sk-'")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            Section(header: Text("Status & Help")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Status
                    if Config.hasValidAPIKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("✓ API key configured - AI features enabled")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Add your \(selectedAIProvider.displayName) API key to enable AI-powered calendar features")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Help button
                    Button(action: {
                        showingAPIKeyAlert = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("How to get \(selectedAIProvider.displayName) API key")
                                .foregroundColor(.blue)
                                .dynamicFont(size: 14, fontManager: fontManager)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(header: Text("AI Features")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Powered by AI")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "calendar.badge.gearshape",
                                 title: "Smart Event Creation",
                                 description: "Natural language event parsing")

                        FeatureRow(icon: "brain.head.profile",
                                 title: "Intelligent Scheduling",
                                 description: "AI-powered conflict resolution")

                        FeatureRow(icon: "mic.circle",
                                 title: "Voice Processing",
                                 description: "Advanced speech recognition")

                        FeatureRow(icon: "waveform.circle",
                                 title: "Natural Responses",
                                 description: "Conversational AI assistance")

                        FeatureRow(icon: "chart.line.uptrend.xyaxis.circle",
                                 title: "Calendar Analytics",
                                 description: "Insights and optimization")

                        FeatureRow(icon: "bell.circle",
                                 title: "Smart Notifications",
                                 description: "Context-aware reminders")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .navigationTitle("AI Integration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feature Row Component (using existing FeatureRow from AdvancedSettingsView)

#Preview {
    NavigationView {
        AIIntegrationSettingsView(
            fontManager: FontManager(),
            selectedAIProvider: .constant(.anthropic),
            selectedProcessingMode: .constant(.hybrid),
            anthropicAPIKey: .constant(""),
            openaiAPIKey: .constant(""),
            isAnthropicKeyVisible: .constant(false),
            isOpenAIKeyVisible: .constant(false),
            showingAPIKeyAlert: .constant(false)
        )
    }
}