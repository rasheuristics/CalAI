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
                            .background(Color.clear)
                    } else if selectedTab == "calendar" {
                        CalendarTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                            .background(Color.clear)
                    } else if selectedTab == "events" {
                        EventsTabView(calendarManager: calendarManager, fontManager: fontManager, appearanceManager: appearanceManager)
                            .background(Color.clear)
                    } else if selectedTab == "tasks" {
                        TasksTabView(fontManager: fontManager, calendarManager: calendarManager)
                            .background(Color.clear)
                    } else if selectedTab == "settings" {
                        SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager, googleCalendarManager: googleCalendarManager, outlookCalendarManager: outlookCalendarManager, appearanceManager: appearanceManager)
                            .background(Color.clear)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // iOS 26 style floating bubble tab bar with drag-and-drop
                iOS26FloatingTabBar(
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

// MARK: - iOS 26 Floating Bubble Tab Bar

struct iOS26FloatingTabBar: View {
    @ObservedObject var tabBarManager: TabBarManager
    @Binding var selectedTab: String
    let activeTaskCount: Int

    @State private var draggedTab: TabItem?
    @State private var draggedOffset: CGSize = .zero
    @State private var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabBarManager.tabs.enumerated()), id: \.element.id) { index, tab in
                iOS26TabBubble(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    badge: tab.id == "tasks" ? activeTaskCount : nil,
                    isDragging: draggedTab?.id == tab.id,
                    isEditing: isEditing,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab.id
                        }
                    },
                    onLongPress: {
                        if !tab.isFixed {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditing = true
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                )
                .offset(draggedTab?.id == tab.id ? draggedOffset : .zero)
                .zIndex(draggedTab?.id == tab.id ? 1 : 0)
                .scaleEffect(draggedTab?.id == tab.id ? 1.1 : 1.0)
                .gesture(
                    tab.isFixed || !isEditing ? nil :
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if draggedTab == nil {
                                draggedTab = tab
                            }
                            draggedOffset = value.translation

                            // Calculate which position we're over
                            let itemWidth = (UIScreen.main.bounds.width - 32) / CGFloat(tabBarManager.tabs.count)
                            let currentX = CGFloat(index) * itemWidth + value.translation.width
                            let newIndex = Int(round(currentX / itemWidth))

                            // Check if we've moved to a new position
                            if newIndex != index && newIndex >= 0 && newIndex < tabBarManager.tabs.count - 1 {
                                tabBarManager.moveTab(from: index, to: newIndex)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                draggedOffset = .zero
                                draggedTab = nil
                                isEditing = false
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            // iOS 26 floating bubble background with glassmorphism
            ZStack {
                // Blur effect
                VisualEffectBlur(blurStyle: .systemUltraThinMaterial)

                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - iOS 26 Tab Bubble Item

struct iOS26TabBubble: View {
    let tab: TabItem
    let isSelected: Bool
    let badge: Int?
    let isDragging: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ?
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                colors: [Color.primary.opacity(0.6), Color.primary.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .symbolEffect(.bounce, value: isSelected)

                    // Badge
                    if let count = badge, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                                    .shadow(color: Color.red.opacity(0.3), radius: 3, x: 0, y: 2)
                            )
                            .offset(x: 12, y: -8)
                    }

                    // Editing indicator
                    if isEditing && !tab.isFixed {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: -12, y: -8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .blue : .primary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

#Preview {
    ContentView()
}