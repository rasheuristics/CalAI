import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var fontManager = FontManager()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarTabView(calendarManager: calendarManager, fontManager: fontManager)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(0)

            EventsTabView(calendarManager: calendarManager, fontManager: fontManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Events")
                }
                .tag(1)

            AITabView(voiceManager: voiceManager, aiManager: aiManager, calendarManager: calendarManager, fontManager: fontManager)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI")
                }
                .tag(2)

            SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .onAppear {
            calendarManager.requestCalendarAccess()
            setupGlassmorphismTabBar()
        }
    }

    private func setupGlassmorphismTabBar() {
        // Configure modern iOS glassmorphism tab bar (dock-style)
        let appearance = UITabBarAppearance()

        // Start with transparent base
        appearance.configureWithTransparentBackground()

        // Advanced glassmorphism effect matching iOS dock
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.1)

        // Multi-layered blur system like iOS dock
        let primaryBlur = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundEffect = primaryBlur

        // Enhanced shadow system for modern depth
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.12)

        // Modern icon styling with refined colors
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Vibrant selected state matching iOS system colors
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.label
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Apply sophisticated appearance settings
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Modern translucency settings
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().backgroundColor = UIColor.clear

        // Advanced visual effects for iOS dock-like behavior
        if #available(iOS 15.0, *) {
            // Ensure consistent appearance across scroll states
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        // Additional refinements for glassmorphism
        UITabBar.appearance().barTintColor = UIColor.clear
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }


}

struct VoiceInputButton: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    var onTranscript: ((String) -> Void)? = nil
    var onResponse: ((AIResponse) -> Void)? = nil

    var body: some View {
        VStack {
            Button(action: {
                if voiceManager.isListening {
                    print("🔴 Voice button pressed - stopping listening")
                    voiceManager.stopListening()
                } else {
                    print("🟢 Voice button pressed - starting listening")
                    voiceManager.startListening { transcript in
                        print("📝 Transcript received in VoiceInputButton: \(transcript)")
                        onTranscript?(transcript)
                        aiManager.processVoiceCommand(transcript) { result in
                            print("🎯 AI processing completed with result: \(result.message)")
                            calendarManager.handleAIResponse(result)
                            onResponse?(result)
                        }
                    }
                }
            }) {
                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 30))
                    .foregroundColor(voiceManager.isListening ? .red : .blue)
                    .padding()
                    .background(Circle().fill(Color.gray.opacity(0.2)))
            }

            Text(voiceManager.isListening ? "Listening..." : "Tap to speak")
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .padding(.bottom)
    }
}

#Preview {
    ContentView()
}