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

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
                        isComplete: iOSCalendarLoaded
                    )

                    // Google Calendar
                    if googleCalendarManager.isSignedIn {
                        InitializationRow(
                            icon: "g.circle.fill",
                            title: "Google Calendar",
                            isComplete: googleCalendarLoaded
                        )
                    }

                    // Outlook Calendar
                    if outlookCalendarManager.isSignedIn {
                        InitializationRow(
                            icon: "envelope.circle.fill",
                            title: "Outlook Calendar",
                            isComplete: outlookCalendarLoaded
                        )
                    }

                    // Insights Analysis
                    InitializationRow(
                        icon: "sparkles",
                        title: "Analyzing Insights",
                        isComplete: insightsLoaded
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .onAppear {
            initializeCalendars()
        }
    }

    private func initializeCalendars() {
        print("🔄 Starting calendar initialization...")

        // iOS Calendar - Request access and load
        Task {
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

            // Wait a moment to show completed state
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                withAnimation {
                    print("✅ Initialization complete!")
                    isInitialized = true
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

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                    .transition(.scale.combined(with: .opacity))
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
