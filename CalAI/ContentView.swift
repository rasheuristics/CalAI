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
    @StateObject private var tabBarManager = TabBarManager()
    // PHASE 12 DISABLED
    // @StateObject private var postMeetingService = PostMeetingService.shared
    @State private var selectedTab: String = "ai" // Changed from Int to String
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    // Computed property for active task count
    private var activeTaskCount: Int {
        var count = 0
        for eventTasks in taskManager.eventTasks.values {
            count += eventTasks.tasks.filter { !$0.isCompleted }.count
        }
        return count
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

            VStack(spacing: 0) {
                // Content area - show the appropriate view based on selected tab
                ZStack {
                    if selectedTab == "ai" {
                        AITabView(voiceManager: voiceManager, aiManager: aiManager, calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    } else if selectedTab == "calendar" {
                        CalendarTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    } else if selectedTab == "events" {
                        EventsTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                    } else if selectedTab == "tasks" {
                        TasksTabView(fontManager: fontManager, calendarManager: calendarManager)
                    } else if selectedTab == "settings" {
                        SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager, googleCalendarManager: googleCalendarManager, outlookCalendarManager: outlookCalendarManager, appearanceManager: appearanceManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom draggable tab bar
                CustomTabBar(
                    tabBarManager: tabBarManager,
                    selectedTab: $selectedTab,
                    activeTaskCount: activeTaskCount
                )
            }
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
        .onAppear {
            print("========================================")
            print("🔴🔴🔴 CALAI APP LAUNCHED - CONSOLE IS WORKING! 🔴🔴🔴")
            print("========================================")

            // Check if onboarding needs to be shown
            if !hasCompletedOnboarding {
                print("📋 First launch detected - showing onboarding")
                showOnboarding = true
            }

            // Perform secure storage migration if needed
            if !SecureStorage.isMigrationCompleted() {
                SecureStorage.performAppMigration()
            }

            // Inject external calendar managers into the main calendar manager
            calendarManager.googleCalendarManager = googleCalendarManager
            calendarManager.outlookCalendarManager = outlookCalendarManager

            // Configure Morning Briefing Service
            print("🔴 About to configure MorningBriefingService...")
            morningBriefingService.configure(calendarManager: calendarManager)
            print("🔴 MorningBriefingService configuration completed")

            // PHASE 12 DISABLED - PostMeetingService Configuration
            // postMeetingService.configure(calendarManager: calendarManager, aiManager: aiManager)

            // Only request calendar access if onboarding is completed
            if hasCompletedOnboarding {
                calendarManager.requestCalendarAccess()
            }
            setupiOS26TabBar()
        }
        // PHASE 12 DISABLED - Post-Meeting Summary Sheet
        // .sheet(isPresented: $postMeetingService.showPostMeetingSummary) {
        //     if let summary = postMeetingService.currentMeetingSummary {
        //         PostMeetingSummaryView(
        //             followUp: summary,
        //             postMeetingService: postMeetingService,
        //             fontManager: fontManager,
        //             calendarManager: calendarManager
        //         )
        //     }
        // }
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

// MARK: - Tab Item Model

struct TabItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let icon: String
    var order: Int
    let isFixed: Bool // Settings tab will be fixed

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tab Bar Manager

class TabBarManager: ObservableObject {
    @Published var tabs: [TabItem] = []
    @AppStorage("customTabOrder") private var tabOrderData: Data = Data()

    init() {
        loadTabs()
    }

    private func loadTabs() {
        // Try to load saved order
        if let decoded = try? JSONDecoder().decode([TabItem].self, from: tabOrderData) {
            tabs = decoded
            print("📊 Loaded saved tab order: \(tabs.map { $0.title })")
        } else {
            // Default order
            tabs = [
                TabItem(id: "ai", title: "AI", icon: "brain.head.profile", order: 0, isFixed: false),
                TabItem(id: "calendar", title: "Calendar", icon: "calendar", order: 1, isFixed: false),
                TabItem(id: "events", title: "Events", icon: "list.bullet", order: 2, isFixed: false),
                TabItem(id: "tasks", title: "Tasks", icon: "tray.fill", order: 3, isFixed: false),
                TabItem(id: "settings", title: "Settings", icon: "gearshape", order: 4, isFixed: true)
            ]
            saveTabs()
        }
    }

    func saveTabs() {
        // Update order values
        for (index, _) in tabs.enumerated() {
            tabs[index].order = index
        }

        if let encoded = try? JSONEncoder().encode(tabs) {
            tabOrderData = encoded
            print("💾 Saved tab order: \(tabs.map { $0.title })")
        }
    }

    func moveTab(from source: Int, to destination: Int) {
        // Don't allow moving if either position is the settings tab
        if tabs[source].isFixed || tabs[destination].isFixed {
            print("⚠️ Cannot move fixed tab (Settings)")
            return
        }

        // Don't allow moving past settings
        if destination >= tabs.count - 1 {
            print("⚠️ Cannot move past Settings tab")
            return
        }

        withAnimation {
            let movedTab = tabs.remove(at: source)
            tabs.insert(movedTab, at: destination)
            saveTabs()
        }
    }
}

// MARK: - Custom Tab Bar View

struct CustomTabBar: View {
    @ObservedObject var tabBarManager: TabBarManager
    @Binding var selectedTab: String
    let activeTaskCount: Int

    @State private var draggedTab: TabItem?
    @State private var draggedOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabBarManager.tabs.enumerated()), id: \.element.id) { index, tab in
                CustomTabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    badge: tab.id == "tasks" ? activeTaskCount : nil,
                    isDragging: draggedTab?.id == tab.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab.id
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .offset(draggedTab?.id == tab.id ? draggedOffset : .zero)
                .zIndex(draggedTab?.id == tab.id ? 1 : 0)
                .opacity(draggedTab?.id == tab.id ? 0.8 : 1.0)
                .gesture(
                    tab.isFixed ? nil : // Settings tab cannot be dragged
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if draggedTab == nil {
                                draggedTab = tab
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            draggedOffset = value.translation

                            // Calculate which position we're over
                            let itemWidth = UIScreen.main.bounds.width / CGFloat(tabBarManager.tabs.count)
                            let currentX = CGFloat(index) * itemWidth + value.translation.width
                            let newIndex = Int(round(currentX / itemWidth))

                            // Check if we've moved to a new position
                            if newIndex != index && newIndex >= 0 && newIndex < tabBarManager.tabs.count - 1 {
                                // Don't allow moving past settings (last position)
                                tabBarManager.moveTab(from: index, to: newIndex)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                draggedOffset = .zero
                                draggedTab = nil
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
        }
        .frame(height: 49) // Standard tab bar height
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        )
    }
}

// MARK: - Custom Tab Bar Item

struct CustomTabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let badge: Int?
    let isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .blue : .gray)
                        .scaleEffect(isDragging ? 1.1 : 1.0)

                    // Badge
                    if let count = badge, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}