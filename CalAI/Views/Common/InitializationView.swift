import SwiftUI

/// Loading screen shown after onboarding while calendars initialize
struct InitializationView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var googleCalendarManager: GoogleCalendarManager
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager

    @Binding var isInitialized: Bool

    @State private var iOSCalendarLoaded = false
    @State private var googleCalendarLoaded = false
    @State private var outlookCalendarLoaded = false
    @State private var insightsLoaded = false

    @State private var iOSCalendarSkipped = false
    @State private var googleCalendarSkipped = false
    @State private var outlookCalendarSkipped = false
    @State private var insightsSkipped = false

    @State private var showingSkipAlert = false

    // Computed property to check if all steps are complete
    private var allStepsComplete: Bool {
        let iOSCompleteOrSkipped = iOSCalendarLoaded || iOSCalendarSkipped
        let googleCompleteOrSkipped = !googleCalendarManager.isSignedIn || googleCalendarLoaded || googleCalendarSkipped
        let outlookCompleteOrSkipped = !outlookCalendarManager.isSignedIn || outlookCalendarLoaded || outlookCalendarSkipped
        let insightsCompleteOrSkipped = insightsLoaded || insightsSkipped

        return iOSCompleteOrSkipped && googleCompleteOrSkipped && outlookCompleteOrSkipped && insightsCompleteOrSkipped
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation with skip button
                HStack {
                    Spacer()
                    Button("Skip Setup") {
                        showingSkipAlert = true
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                }
                .padding()

                Spacer()

                VStack(spacing: DesignSystem.Spacing.xl) {
                    Image(systemName: "calendar.badge.gearshape")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10)

                    Text("Setting Up CalAI")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    VStack(spacing: DesignSystem.Spacing.md) {
                        // iOS Calendar
                        InitializationRow(
                            icon: "calendar",
                            title: "iOS Calendar",
                            isComplete: iOSCalendarLoaded,
                            isSkipped: iOSCalendarSkipped,
                            onSkip: {
                                withAnimation {
                                    iOSCalendarSkipped = true
                                }
                            }
                        )

                        // Google Calendar
                        if googleCalendarManager.isSignedIn {
                            InitializationRow(
                                icon: "g.circle.fill",
                                title: "Google Calendar",
                                isComplete: googleCalendarLoaded,
                                isSkipped: googleCalendarSkipped,
                                onSkip: {
                                    withAnimation {
                                        googleCalendarSkipped = true
                                    }
                                }
                            )
                        }

                        // Outlook Calendar
                        if outlookCalendarManager.isSignedIn {
                            InitializationRow(
                                icon: "envelope.circle.fill",
                                title: "Outlook Calendar",
                                isComplete: outlookCalendarLoaded,
                                isSkipped: outlookCalendarSkipped,
                                onSkip: {
                                    withAnimation {
                                        outlookCalendarSkipped = true
                                    }
                                }
                            )
                        }

                        // Insights Analysis
                        InitializationRow(
                            icon: "sparkles",
                            title: "Analyzing Insights",
                            isComplete: insightsLoaded,
                            isSkipped: insightsSkipped,
                            onSkip: {
                                withAnimation {
                                    insightsSkipped = true
                                }
                            }
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)

                    // Continue button - appears when all steps are complete
                    if allStepsComplete {
                        Button(action: {
                            withAnimation {
                                isInitialized = true
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.2), radius: 10)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.lg)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()
            }
        }
        .alert("Skip Setup", isPresented: $showingSkipAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Skip", role: .destructive) {
                skipEntireSetup()
            }
        } message: {
            Text("Are you sure you want to skip the setup? You can always configure these settings later in the app.")
        }
        .onAppear {
            initializeCalendars()
        }
    }

    private func skipEntireSetup() {
        withAnimation {
            iOSCalendarSkipped = true
            googleCalendarSkipped = true
            outlookCalendarSkipped = true
            insightsSkipped = true

            // Mark as initialized to proceed to main app
            isInitialized = true
            print("⏭️ Setup skipped by user")
        }
    }

    private func initializeCalendars() {
        print("🔄 Starting calendar initialization...")

        // Start monitoring for completion
        startCompletionMonitoring()

        // iOS Calendar - Request access and load
        Task {
            await MainActor.run {
                if iOSCalendarSkipped {
                    print("⏭️ iOS Calendar skipped")
                    return
                }
            }

            print("📅 Loading iOS Calendar...")
            calendarManager.requestCalendarAccess()
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    iOSCalendarLoaded = true
                    print("✅ iOS Calendar loaded")
                }
            }
        }

        // Google Calendar - Fetch events
        if googleCalendarManager.isSignedIn {
            Task {
                await MainActor.run {
                    if googleCalendarSkipped {
                        print("⏭️ Google Calendar skipped")
                        return
                    }
                }

                print("📗 Loading Google Calendar...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s initial delay
                // Explicitly fetch Google events
                await MainActor.run {
                    googleCalendarManager.fetchEvents()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s for fetch to complete
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        googleCalendarLoaded = true
                        print("✅ Google Calendar loaded")
                    }
                }
            }
        }

        // Outlook Calendar - Fetch events
        if outlookCalendarManager.isSignedIn {
            Task {
                await MainActor.run {
                    if outlookCalendarSkipped {
                        print("⏭️ Outlook Calendar skipped")
                        return
                    }
                }

                print("📘 Loading Outlook Calendar...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s initial delay
                // Explicitly fetch Outlook events
                await MainActor.run {
                    outlookCalendarManager.fetchEvents()
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s for fetch to complete
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        outlookCalendarLoaded = true
                        print("✅ Outlook Calendar loaded")
                    }
                }
            }
        }

        // Insights - Analyze all events
        Task {
            let delay: UInt64 = (googleCalendarManager.isSignedIn || outlookCalendarManager.isSignedIn) ? 2_500_000_000 : 1_000_000_000

            await MainActor.run {
                if insightsSkipped {
                    print("⏭️ Insights analysis skipped")
                    return
                }
            }

            print("✨ Analyzing insights...")
            try? await Task.sleep(nanoseconds: delay)

            // Load all unified events after all calendar sources have been fetched
            await MainActor.run {
                print("🔄 Loading all unified events from all sources...")
                calendarManager.loadAllUnifiedEvents()
            }

            // Wait for unification to complete
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    insightsLoaded = true
                    print("✅ Insights analyzed - \(calendarManager.unifiedEvents.count) total events")
                }
            }
        }
    }

    private func startCompletionMonitoring() {
        Task {
            while !isInitialized {
                try? await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1s

                await MainActor.run {
                    let iOSCompleteOrSkipped = iOSCalendarLoaded || iOSCalendarSkipped
                    let googleCompleteOrSkipped = !googleCalendarManager.isSignedIn || googleCalendarLoaded || googleCalendarSkipped
                    let outlookCompleteOrSkipped = !outlookCalendarManager.isSignedIn || outlookCalendarLoaded || outlookCalendarSkipped
                    let insightsCompleteOrSkipped = insightsLoaded || insightsSkipped

                    if iOSCompleteOrSkipped && googleCompleteOrSkipped && outlookCompleteOrSkipped && insightsCompleteOrSkipped {
                        withAnimation {
                            print("✅ Initialization complete!")
                            isInitialized = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Initialization Row

struct InitializationRow: View {
    let icon: String
    let title: String
    let isComplete: Bool
    let isSkipped: Bool
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            if isSkipped {
                Text("Skipped")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            } else if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                    .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Button("Skip") {
                        onSkip()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Preview

#Preview {
    InitializationView(
        calendarManager: CalendarManager(),
        googleCalendarManager: GoogleCalendarManager(),
        outlookCalendarManager: OutlookCalendarManager(),
        isInitialized: .constant(false)
    )
}
