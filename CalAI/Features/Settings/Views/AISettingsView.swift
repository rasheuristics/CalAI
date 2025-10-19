import SwiftUI
import AVFoundation

struct AISettingsView: View {
    @AppStorage(UserDefaults.Keys.aiProvider) private var aiProvider: AIProvider = .anthropic
    @AppStorage(UserDefaults.Keys.aiOutputMode) private var aiOutputMode: AIOutputMode = .voiceAndText
    @AppStorage(UserDefaults.Keys.queryDisplayMode) private var queryDisplayMode: QueryDisplayMode = .both
    @AppStorage(UserDefaults.Keys.speechRate) private var speechRate: Double = 0.5
    @AppStorage(UserDefaults.Keys.speechPitch) private var speechPitch: Double = 1.0
    @AppStorage(UserDefaults.Keys.speechVoiceIdentifier) private var voiceIdentifier: String = ""
    @AppStorage(UserDefaults.Keys.speechSentencePause) private var sentencePause: Double = 0.0
    @AppStorage(UserDefaults.Keys.audioEffectsEnabled) private var audioEffectsEnabled: Bool = false
    @AppStorage(UserDefaults.Keys.audioEQBass) private var eqBass: Double = 0.0
    @AppStorage(UserDefaults.Keys.audioEQMid) private var eqMid: Double = 0.0
    @AppStorage(UserDefaults.Keys.audioEQTreble) private var eqTreble: Double = 0.0

    @State private var testSpeechText = "Hello, this is a test. The voice settings sound great!"

    var body: some View {
        Form {
            Section(header: Text("AI Provider"), footer: Text("Choose which AI model powers your assistant. You must provide your own API key for the selected provider.")) {
                Picker("Provider", selection: $aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("AI Output Mode"), footer: Text("Choose how the AI assistant responds. Voice always speaks a short summary.")) {
                Picker("Output Mode", selection: $aiOutputMode) {
                    ForEach(AIOutputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Query Display Mode"), footer: Text("Choose what to show when asking about your schedule. Voice will always speak a short summary only.")) {
                Picker("Display", selection: $queryDisplayMode) {
                    ForEach(QueryDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Voice Settings"), footer: Text("Customize how the AI assistant sounds. Changes take effect immediately.")) {
                NavigationLink(destination: VoiceSelectionView(selectedVoiceIdentifier: $voiceIdentifier)) {
                    HStack {
                        Text("Voice")
                        Spacer()
                        Text(selectedVoiceName)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speed (Rate)")
                        Spacer()
                        Text("\(String(format: "%.2f", speechRate))x")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    Slider(value: $speechRate, in: 0.3...0.7, step: 0.01)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pitch (Timber)")
                        Spacer()
                        Text("\(String(format: "%.1f", speechPitch))x")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sentence Pause")
                        Spacer()
                        Text("\(String(format: "%.1f", sentencePause))s")
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    Slider(value: $sentencePause, in: 0.0...2.0, step: 0.1)
                }

                Button(action: testVoice) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Test Voice")
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Section(header: Text("Audio Effects (Equalizer)"), footer: Text("Adjust audio frequencies. Enable to apply equalizer settings.")) {
                Toggle("Enable Audio Effects", isOn: $audioEffectsEnabled)
                    .onChange(of: audioEffectsEnabled) { enabled in
                        if enabled {
                            SpeechManager.shared.updateEQSettings()
                        }
                    }

                if audioEffectsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bass (60 Hz)")
                            Spacer()
                            Text("\(String(format: "%.0f", eqBass)) dB")
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                        }
                        Slider(value: $eqBass, in: -12.0...12.0, step: 1.0)
                        .onChange(of: eqBass) { _ in
                            SpeechManager.shared.updateEQSettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Mid (1000 Hz)")
                            Spacer()
                            Text("\(String(format: "%.0f", eqMid)) dB")
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                        }
                        Slider(value: $eqMid, in: -12.0...12.0, step: 1.0)
                        .onChange(of: eqMid) { _ in
                            SpeechManager.shared.updateEQSettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Treble (10000 Hz)")
                            Spacer()
                            Text("\(String(format: "%.0f", eqTreble)) dB")
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                        }
                        Slider(value: $eqTreble, in: -12.0...12.0, step: 1.0)
                        .onChange(of: eqTreble) { _ in
                            SpeechManager.shared.updateEQSettings()
                        }
                    }

                    Button("Reset EQ to Flat") {
                        eqBass = 0.0
                        eqMid = 0.0
                        eqTreble = 0.0
                        SpeechManager.shared.updateEQSettings()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("AI Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedVoiceName: String {
        if voiceIdentifier.isEmpty {
            return "System Default"
        }
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return voice.name
        }
        return "Unknown"
    }

    private func testVoice() {
        SpeechManager.shared.speak(text: testSpeechText)
    }
}

// Voice selection view
struct VoiceSelectionView: View {
    @Binding var selectedVoiceIdentifier: String
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var groupedVoices: [String: [AVSpeechSynthesisVoice]] = [:]

    var body: some View {
        List {
            Section {
                Button(action: {
                    selectedVoiceIdentifier = ""
                }) {
                    HStack {
                        Text("System Default")
                        Spacer()
                        if selectedVoiceIdentifier.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            ForEach(Array(groupedVoices.keys.sorted()), id: \.self) { language in
                Section(header: Text(language)) {
                    ForEach(groupedVoices[language] ?? [], id: \.identifier) { voice in
                        Button(action: {
                            selectedVoiceIdentifier = voice.identifier
                            testVoice(voice)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                    Text(qualityText(for: voice))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedVoiceIdentifier == voice.identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadVoices)
    }

    private func loadVoices() {
        // Get ALL available voices (includes Siri, Personal Voice, etc.)
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Filter to BOTH Enhanced (Quality 2) AND Premium (Quality 3) voices
        voices = allVoices.filter { $0.quality == .enhanced || $0.quality == .premium }

        print("📢 Total voices found: \(allVoices.count)")
        print("📢 Enhanced (Level 2) & Premium (Level 3) voices: \(voices.count)")

        // Debug: Print all voice details
        for voice in voices {
            print("  - \(voice.name) (\(voice.language)) - Quality: \(voice.quality.rawValue) - ID: \(voice.identifier)")
        }

        if voices.isEmpty {
            print("⚠️ No enhanced or premium voices found on this device")
            print("💡 To download voices: Settings → Accessibility → Spoken Content → Voices → Select a language → Download voices")
        }

        // Group voices by language
        var grouped: [String: [AVSpeechSynthesisVoice]] = [:]

        for voice in voices {
            let languageName = Locale.current.localizedString(forLanguageCode: voice.language) ?? voice.language
            if grouped[languageName] == nil {
                grouped[languageName] = []
            }
            grouped[languageName]?.append(voice)
        }

        // Sort voices within each language: Premium first, then by name
        for (key, voiceList) in grouped {
            grouped[key] = voiceList.sorted { (voice1, voice2) in
                if voice1.quality != voice2.quality {
                    // Premium (3) before Enhanced (2)
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
        }

        groupedVoices = grouped

        print("📢 Grouped voices into \(grouped.keys.count) categories")
    }

    private func qualityText(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium:
            return "Premium (Level 3)"
        case .enhanced:
            return "Enhanced (Level 2)"
        default:
            return "Standard"
        }
    }

    private func testVoice(_ voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "Hello, this is \(voice.name).")
        utterance.voice = voice
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
