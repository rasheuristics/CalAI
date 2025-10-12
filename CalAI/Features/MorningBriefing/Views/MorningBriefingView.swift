import SwiftUI
import AVFoundation

/// View displaying the daily morning briefing
struct MorningBriefingView: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var briefingService = MorningBriefingService.shared
    @StateObject private var voiceReader = VoiceReader()

    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Generating your briefing...")
                        .padding()
                } else if let briefing = briefingService.todaysBriefing {
                    briefingContent(briefing)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Morning Briefing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Voice toggle button
                        Button(action: {
                            toggleVoiceReadout()
                        }) {
                            Image(systemName: voiceReader.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 20))
                                .foregroundColor(voiceReader.isSpeaking ? .blue : .primary)
                        }

                        // Refresh button
                        Button(action: {
                            refreshBriefing()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                        }
                    }
                }
            }
            .onAppear {
                if briefingService.todaysBriefing == nil {
                    refreshBriefing()
                }

                // Auto-play voice if enabled
                if briefingService.settings.voiceAutoPlay,
                   let briefing = briefingService.todaysBriefing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        playVoiceReadout(for: briefing)
                    }
                }
            }
        }
    }

    // MARK: - Briefing Content

    @ViewBuilder
    private func briefingContent(_ briefing: DailyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Greeting
            Text(briefing.greeting)
                .dynamicFont(size: 32, weight: .bold, fontManager: fontManager)
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.top)

            // Weather Section
            if let weather = briefing.weather {
                weatherSection(weather)
            } else {
                // Debug: Show why weather is missing
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Weather Unavailable")
                            .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                        Spacer()
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weather data could not be loaded.")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text("Check Xcode Console for details. Common issues:")
                            .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Location permission not granted")
                            Text("• No internet connection")
                            Text("• WeatherKit not available (iOS 15)")
                            Text("• Simulator location not set")
                        }
                        .dynamicFont(size: 11, fontManager: fontManager)
                        .foregroundColor(.secondary)

                        Button(action: {
                            print("🧪 Manual weather fetch test started...")
                            WeatherService.shared.fetchCurrentWeather { result in
                                switch result {
                                case .success(let weather):
                                    print("🧪 Manual test SUCCESS: \(weather.temperatureFormatted), \(weather.condition)")
                                case .failure(let error):
                                    print("🧪 Manual test FAILED: \(error.localizedDescription)")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                Text("Test Weather Fetch")
                                    .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            // Events Summary
            eventsSummarySection(briefing)

            // Events List
            if !briefing.events.isEmpty {
                eventsListSection(briefing.events)
            }

            // Suggestions
            if !briefing.suggestions.isEmpty {
                suggestionsSection(briefing.suggestions)
            }
        }
        .padding(.bottom, 24)
    }

    private func weatherSection(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weather")
                    .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // Weather icon
                    Text(weather.weatherEmoji)
                        .font(.system(size: 60))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.temperatureFormatted)
                            .dynamicFont(size: 48, weight: .bold, fontManager: fontManager)

                        Text(weather.conditionDescription)
                            .dynamicFont(size: 18, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text(weather.highLowFormatted)
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if weather.shouldShowPrecipitation {
                    HStack {
                        Image(systemName: "cloud.rain.fill")
                            .foregroundColor(.blue)
                        Text("\(weather.precipitationChance)% chance of precipitation")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func eventsSummarySection(_ briefing: DailyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Schedule")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                .padding(.horizontal)

            Text(briefing.daySummary)
                .dynamicFont(size: 16, fontManager: fontManager)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    private func eventsListSection(_ events: [BriefingEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(events) { event in
                eventCard(event)
            }
        }
        .padding(.horizontal)
    }

    private func eventCard(_ event: BriefingEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time indicator
            VStack(alignment: .center, spacing: 4) {
                Text(timeString(from: event.startTime))
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.blue)

                if !event.isAllDay {
                    Text(event.durationFormatted)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.primary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(location)
                            .dynamicFont(size: 14, fontManager: fontManager)
                    }
                    .foregroundColor(.secondary)
                }

                Text(event.source.rawValue)
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func suggestionsSection(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Text(suggestion)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("No briefing available")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)

            Text("Tap refresh to generate your morning briefing")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                refreshBriefing()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func refreshBriefing() {
        isLoading = true
        briefingService.generateBriefing { briefing in
            isLoading = false
        }
    }

    private func toggleVoiceReadout() {
        if voiceReader.isSpeaking {
            voiceReader.stop()
        } else if let briefing = briefingService.todaysBriefing {
            playVoiceReadout(for: briefing)
        }
    }

    private func playVoiceReadout(for briefing: DailyBriefing) {
        let script = briefingService.generateVoiceScript(for: briefing)
        voiceReader.speak(script)
    }
}

// MARK: - Voice Reader

class VoiceReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = 0.5 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - Preview

#Preview {
    MorningBriefingView(fontManager: FontManager())
}
