import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var googleCalendarManager = GoogleCalendarManager()
    @StateObject private var outlookCalendarManager = OutlookCalendarManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var fontManager = FontManager()
    @StateObject private var appearanceManager = AppearanceManager()
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            // Beautiful gradient background that adapts to appearance mode
            LinearGradient(
                colors: appearanceManager.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                CalendarTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(0)

                EventsTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Events")
                    }
                    .tag(1)

                AITabView(voiceManager: voiceManager, aiManager: aiManager, calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("AI")
                    }
                    .tag(2)

                SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager, googleCalendarManager: googleCalendarManager, outlookCalendarManager: outlookCalendarManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .background(Color.clear)
        }
        .preferredColorScheme(appearanceManager.currentMode.colorScheme)
        .onAppear {
            // Perform secure storage migration if needed
            if !SecureStorage.isMigrationCompleted() {
                SecureStorage.performAppMigration()
            }

            // Inject external calendar managers into the main calendar manager
            calendarManager.googleCalendarManager = googleCalendarManager
            calendarManager.outlookCalendarManager = outlookCalendarManager

            calendarManager.requestCalendarAccess()
            setupiOS18TabBar()
        }
    }

    private func setupiOS18TabBar() {
        // Modern glassmorphism tab bar design
        let appearance = UITabBarAppearance()

        // Configure with glass material
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

        // Subtle glass background
        appearance.backgroundColor = UIColor.clear

        // Enhanced shadow for floating glass effect
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)

        // Tab item styling - normal state with glass aesthetic
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.label.withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.label.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Tab item styling - selected state with accent color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Apply the glassmorphism appearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Enable translucency for glass effect
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().barTintColor = UIColor.clear

        // Force immediate update
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
    @ObservedObject var appearanceManager: AppearanceManager
    var onTranscript: ((String) -> Void)? = nil
    var onResponse: ((AICalendarResponse) -> Void)? = nil

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
                            calendarManager.handleAICalendarResponse(result)
                            onResponse?(result)
                        }
                    }
                }
            }) {
                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 30))
                    .foregroundColor(voiceManager.isListening ? .red : .white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.white.opacity(appearanceManager.glassOpacity))
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: voiceManager.isListening ?
                                                [.red.opacity(0.8), .red.opacity(0.6)] :
                                                [.blue.opacity(0.8), .blue.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: voiceManager.isListening ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 15, x: 0, y: 5)
                    )
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