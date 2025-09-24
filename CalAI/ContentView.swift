import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var googleCalendarManager = GoogleCalendarManager()
    @StateObject private var outlookCalendarManager = OutlookCalendarManager()
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

            SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager, googleCalendarManager: googleCalendarManager, outlookCalendarManager: outlookCalendarManager)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .preferredColorScheme(.light)
        .onAppear {
            // Inject external calendar managers into the main calendar manager
            calendarManager.googleCalendarManager = googleCalendarManager
            calendarManager.outlookCalendarManager = outlookCalendarManager

            calendarManager.requestCalendarAccess()
            setupiOS18TabBar()
        }
    }

    private func setupiOS18TabBar() {
        // iOS 18 Tab Bar Design - More prominent, floating appearance
        let appearance = UITabBarAppearance()

        // Use prominent background instead of transparent
        appearance.configureWithOpaqueBackground()

        // iOS 18 style materials and effects
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

        // Prominent background color with better contrast
        appearance.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.95)

        // Enhanced shadow for floating effect
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.2)

        // Tab item styling - normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Tab item styling - selected state (more prominent)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Apply the appearance globally
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Force tab bar to be opaque and prominent
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = UIColor.systemGray6

        // Additional iOS 18 styling
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        // Force immediate update - iOS 18 compatible
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.rootViewController?.view.setNeedsDisplay()
                }
            }
        }
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