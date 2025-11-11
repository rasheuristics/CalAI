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
    @StateObject private var morningBriefingService = MorningBriefingService.shared
    @StateObject private var taskManager = EventTaskManager.shared
    @StateObject private var insightsViewModel = InsightsViewModel()
    @StateObject private var postMeetingService = PostMeetingService.shared
    @State private var selectedTab: Int = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedInitialization") private var hasCompletedInitialization = false
    @State private var showOnboarding = false
    @State private var showInitialization = false
    @State private var showMorningBriefing = false

    // Computed property for active task count
    private var activeTaskCount: Int {
        var count = 0
        for eventTasks in taskManager.eventTasks.values {
            count += eventTasks.tasks.filter { !$0.isCompleted }.count
        }
        return count
    }

    // Computed property for insights issue count (conflicts + duplicates)
    private var insightsIssueCount: Int {
        return insightsViewModel.conflicts.count + insightsViewModel.duplicates.count
    }

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

                InsightsView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Insights")
                    }
                    .tag(1)
                    .badge(insightsIssueCount)

                AITabView(voiceManager: voiceManager, aiManager: aiManager, calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image("AITabIcon")
                            .renderingMode(.template)
                    }
                    .tag(2)

                InboxView(fontManager: fontManager, appearanceManager: appearanceManager, calendarManager: calendarManager)
                    .tabItem {
                        Image(systemName: "tray.fill")
                        Text("Tasks")
                    }
                    .tag(3)
                    .badge(activeTaskCount)

                ActionItemsView(postMeetingService: postMeetingService, fontManager: fontManager, calendarManager: calendarManager)
                    .tabItem {
                        Image(systemName: "checkmark.circle")
                        Text("Actions")
                    }
                    .tag(4)
                    .badge(postMeetingService.pendingActionItems.filter { !$0.isCompleted }.count)

                SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager, googleCalendarManager: googleCalendarManager, outlookCalendarManager: outlookCalendarManager, appearanceManager: appearanceManager)
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(5)
            }
            .background(Color.clear)
            .onChange(of: selectedTab) { newTab in
                let tabName = ["Calendar", "Insights", "AI", "Tasks", "Actions", "Settings"][newTab]
                PerformanceMonitor.shared.measure("Tab Switch to \(tabName)") {
                    MemoryMonitor.logMemoryUsage(context: "Tab: \(tabName)")
                }
            }

            // Performance overlay - shows FPS in debug builds
            #if DEBUG
            PerformanceOverlay()
            #endif
        }
        .preferredColorScheme(appearanceManager.currentMode.colorScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                calendarManager: calendarManager,
                googleCalendarManager: googleCalendarManager,
                outlookCalendarManager: outlookCalendarManager,
                voiceManager: voiceManager
            )
        }
        .fullScreenCover(isPresented: $showInitialization) {
            InitializationView(
                calendarManager: calendarManager,
                googleCalendarManager: googleCalendarManager,
                outlookCalendarManager: outlookCalendarManager,
                isInitialized: $hasCompletedInitialization
            )
        }
        .onChange(of: hasCompletedInitialization) { completed in
            if completed {
                // Dismiss initialization view when completed
                showInitialization = false
            }
        }
        .sheet(isPresented: $showMorningBriefing) {
            NavigationView {
                MorningBriefingScreen()
                    .environmentObject(calendarManager)
                    .environmentObject(taskManager)
                    .environmentObject(fontManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showMorningBriefing = false
                            }
                        }
                    }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            print("========================================")
            print("🔴🔴🔴 CALAI APP LAUNCHED - CONSOLE IS WORKING! 🔴🔴🔴")
            print("========================================")

            // Check if onboarding needs to be shown
            if !hasCompletedOnboarding {
                print("📋 First launch detected - showing onboarding")
                showOnboarding = true
            } else if !hasCompletedInitialization {
                print("⏳ Onboarding completed but initialization needed")
                showInitialization = true
            }

            // Perform secure storage migration if needed
            if !SecureStorage.isMigrationCompleted() {
                SecureStorage.performAppMigration()
            }

            // Inject external calendar managers into the main calendar manager
            calendarManager.googleCalendarManager = googleCalendarManager
            calendarManager.outlookCalendarManager = outlookCalendarManager

            // Setup UI immediately for fast launch
            setupiOS26TabBar()

            // Defer non-UI initialization to avoid blocking launch
            DispatchQueue.main.async {
                // Configure Morning Briefing Service
                print("🔴 About to configure MorningBriefingService...")
                morningBriefingService.configure(calendarManager: calendarManager)
                print("🔴 MorningBriefingService configuration completed")

                // Configure PostMeetingService
                postMeetingService.configure(calendarManager: calendarManager)

                // Only request calendar access if onboarding is completed
                if hasCompletedOnboarding {
                    calendarManager.requestCalendarAccess()
                }
            }
        }
        .sheet(isPresented: $postMeetingService.showPostMeetingSummary) {
            if let summary = postMeetingService.currentMeetingSummary {
                PostMeetingSummaryView(
                    followUp: summary,
                    postMeetingService: postMeetingService,
                    fontManager: fontManager,
                    calendarManager: calendarManager
                )
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")

        guard url.scheme == "calai" else {
            print("⚠️ Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }

        switch url.host {
        case "morning-briefing":
            print("📅 Opening Morning Briefing")
            showMorningBriefing = true
        default:
            print("⚠️ Unknown deep link host: \(url.host ?? "nil")")
        }
    }

    private func setupiOS26TabBar() {
        // iOS 26 enhanced dock with advanced glassmorphism
        let appearance = UITabBarAppearance()

        // Ultra-modern transparent configuration with enhanced blur
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

        // iOS 26 dock styling with refined glass background
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.02)

        // Enhanced shadow for floating dock appearance
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.15)

        // iOS 26 tab item styling - inactive state with refined opacity
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.label.withAlphaComponent(0.55)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.label.withAlphaComponent(0.55),
            .font: UIFont.systemFont(ofSize: 9.5, weight: .medium)
        ]
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.systemRed

        // iOS 26 tab item styling - active state with enhanced accent
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold)
        ]

        // iOS 26 compact layout for smaller devices
        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.label.withAlphaComponent(0.55)
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.label.withAlphaComponent(0.55),
            .font: UIFont.systemFont(ofSize: 9, weight: .medium)
        ]
        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold)
        ]

        // Apply iOS 26 dock appearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Note: Compact appearance is available in newer iOS versions
        // if #available(iOS 15.0, *) {
        //     UITabBar.appearance().compactAppearance = appearance
        //     UITabBar.appearance().compactScrollEdgeAppearance = appearance
        // }

        // iOS 26 enhanced translucency and visual effects
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().barTintColor = UIColor.clear
        UITabBar.appearance().tintColor = UIColor.systemBlue
        UITabBar.appearance().unselectedItemTintColor = UIColor.label.withAlphaComponent(0.55)

        // Force immediate visual update for iOS 26 styling
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    if let tabBarController = window.rootViewController as? UITabBarController {
                        tabBarController.tabBar.setNeedsLayout()
                        tabBarController.tabBar.layoutIfNeeded()
                    }
                    window.rootViewController?.view.setNeedsDisplay()
                    window.rootViewController?.view.setNeedsLayout()
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
                .font(.system(size: 24))
                .foregroundColor(voiceManager.isListening ? .red : .blue)
        }
    }
}

#Preview {
    ContentView()
}