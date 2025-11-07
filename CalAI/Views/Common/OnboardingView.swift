import SwiftUI
import EventKit
import CoreLocation
import AVFoundation
import UserNotifications

/// Onboarding flow for new users
struct OnboardingView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var googleCalendarManager: GoogleCalendarManager
    @ObservedObject var outlookCalendarManager: OutlookCalendarManager
    @ObservedObject var voiceManager: VoiceManager

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedInitialization") private var hasCompletedInitialization = false
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    @State private var calendarAccessGranted = false
    @State private var googleCalendarConnected = false
    @State private var outlookCalendarConnected = false
    @State private var microphoneAccessGranted = false
    @State private var locationAccessGranted = false
    @State private var notificationAccessGranted = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar.badge.plus",
            title: "Welcome to CalAI",
            description: "Your intelligent calendar assistant that learns from your habits and helps you schedule smarter.",
            gradient: [Color.blue, Color.purple],
            type: .info
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "AI-Powered Suggestions",
            description: "Get smart event suggestions based on your patterns. Natural language input makes scheduling effortless.",
            gradient: [Color.purple, Color.pink],
            type: .info
        ),
        OnboardingPage(
            icon: "calendar.circle.fill",
            title: "Multi-Calendar Sync",
            description: "Connect iOS Calendar, Google Calendar, and Outlook. All your events in one place.",
            gradient: [Color.pink, Color.orange],
            type: .info
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Smart Notifications",
            description: "Context-aware notifications that adapt to your location, travel time, and meeting type.",
            gradient: [Color.orange, Color.red],
            type: .info
        ),
        OnboardingPage(
            icon: "hand.raised.fill",
            title: "Grant Permissions",
            description: "CalAI needs access to your calendar, microphone, and location to provide the best experience.",
            gradient: [Color.red, Color.purple],
            type: .permissions
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "You're All Set!",
            description: "Let's get started with your intelligent calendar.",
            gradient: [Color.green, Color.blue],
            type: .info
        )
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: pages[currentPage].gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                    }
                }

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if pages[index].type == .permissions {
                            PermissionsPageView(
                                calendarAccessGranted: $calendarAccessGranted,
                                googleCalendarConnected: $googleCalendarConnected,
                                outlookCalendarConnected: $outlookCalendarConnected,
                                microphoneAccessGranted: $microphoneAccessGranted,
                                locationAccessGranted: $locationAccessGranted,
                                notificationAccessGranted: $notificationAccessGranted,
                                onRequestCalendar: requestCalendarAccess,
                                onConnectGoogle: connectGoogleCalendar,
                                onConnectOutlook: connectOutlookCalendar,
                                onRequestMicrophone: requestMicrophoneAccess,
                                onRequestLocation: requestLocationAccess,
                                onRequestNotification: requestNotificationAccess
                            )
                            .tag(index)
                        } else {
                            OnboardingPageView(page: pages[index])
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Action button
                Button(action: handleNextTap) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(pages[currentPage].gradient[0])
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .sheet(isPresented: $outlookCalendarManager.showCalendarSelection) {
            OutlookCalendarSelectionView(outlookCalendarManager: outlookCalendarManager)
        }
        .onChange(of: outlookCalendarManager.selectedCalendar?.id) { _ in
            // Update connection status when calendar is selected
            outlookCalendarConnected = outlookCalendarManager.isSignedIn && outlookCalendarManager.selectedCalendar != nil
        }
    }

    private func handleNextTap() {
        HapticManager.shared.light()

        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        HapticManager.shared.success()
        hasCompletedOnboarding = true
        hasCompletedInitialization = false // Reset to show initialization screen

        // Initialize morning briefing now that onboarding is complete
        MorningBriefingService.shared.initializeAfterOnboarding()

        dismiss()
    }

    // MARK: - Permission Requests

    private func requestCalendarAccess() {
        print("📅 Requesting calendar access from onboarding...")
        calendarManager.requestCalendarAccess()

        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 17.0, *) {
                let status = EKEventStore.authorizationStatus(for: .event)
                self.calendarAccessGranted = (status == .fullAccess || status == .authorized)
            } else {
                let status = EKEventStore.authorizationStatus(for: .event)
                self.calendarAccessGranted = (status == .authorized)
            }
        }
    }

    private func requestMicrophoneAccess() {
        print("🎤 Requesting microphone access from onboarding...")
        voiceManager.requestPermissions()

        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.microphoneAccessGranted = self.voiceManager.hasRecordingPermission
            if self.microphoneAccessGranted {
                print("✅ Microphone access granted")
            }
        }
    }

    private func requestLocationAccess() {
        print("📍 Requesting location access from onboarding...")
        SmartNotificationManager.shared.requestLocationPermission()

        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let locationManager = CLLocationManager()
            let status = locationManager.authorizationStatus
            self.locationAccessGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
        }
    }

    private func requestNotificationAccess() {
        print("🔔 Requesting notification access from onboarding...")
        SmartNotificationManager.shared.requestNotificationPermission { granted in
            DispatchQueue.main.async {
                self.notificationAccessGranted = granted
                if granted {
                    print("✅ Notification access granted")
                    SmartNotificationManager.shared.setupNotificationCategories()
                }
            }
        }
    }

    private func connectGoogleCalendar() {
        print("📅 Connecting Google Calendar from onboarding...")
        googleCalendarManager.signIn()

        // Check connection status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.googleCalendarConnected = self.googleCalendarManager.isSignedIn
            if self.googleCalendarConnected {
                print("✅ Google Calendar connected")
            }
        }
    }

    private func connectOutlookCalendar() {
        print("📅 Connecting Outlook Calendar from onboarding...")
        outlookCalendarManager.signIn()

        // Check connection status after a delay
        // Note: User will need to select a calendar after signing in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Consider connected if signed in and has a selected calendar
            self.outlookCalendarConnected = self.outlookCalendarManager.isSignedIn && self.outlookCalendarManager.selectedCalendar != nil
            if self.outlookCalendarManager.isSignedIn {
                print("✅ Outlook signed in, selected calendar: \(self.outlookCalendarManager.selectedCalendar?.displayName ?? "none")")
            }
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 10)

            VStack(spacing: DesignSystem.Spacing.md) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding()
    }
}

// MARK: - Permissions Page View

struct PermissionsPageView: View {
    @Binding var calendarAccessGranted: Bool
    @Binding var googleCalendarConnected: Bool
    @Binding var outlookCalendarConnected: Bool
    @Binding var microphoneAccessGranted: Bool
    @Binding var locationAccessGranted: Bool
    @Binding var notificationAccessGranted: Bool

    let onRequestCalendar: () -> Void
    let onConnectGoogle: () -> Void
    let onConnectOutlook: () -> Void
    let onRequestMicrophone: () -> Void
    let onRequestLocation: () -> Void
    let onRequestNotification: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 10)

                Text("Connect & Permissions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Connect your calendars and grant permissions")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    // iOS Calendar Permission
                    PermissionButton(
                        icon: "calendar",
                        title: "iOS Calendar",
                        description: "Access your device calendar",
                        isGranted: calendarAccessGranted,
                        action: onRequestCalendar
                    )

                    // Google Calendar Connection
                    PermissionButton(
                        icon: "g.circle.fill",
                        title: "Google Calendar",
                        description: "Connect your Google Calendar",
                        isGranted: googleCalendarConnected,
                        action: onConnectGoogle
                    )

                    // Outlook Calendar Connection
                    PermissionButton(
                        icon: "envelope.circle.fill",
                        title: "Outlook Calendar",
                        description: "Connect your Outlook Calendar",
                        isGranted: outlookCalendarConnected,
                        action: onConnectOutlook
                    )

                    // Microphone Permission
                    PermissionButton(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "Voice commands and AI assistant",
                        isGranted: microphoneAccessGranted,
                        action: onRequestMicrophone
                    )

                    // Location Permission
                    PermissionButton(
                        icon: "location.fill",
                        title: "Location Access",
                        description: "Travel time calculations",
                        isGranted: locationAccessGranted,
                        action: onRequestLocation
                    )

                    // Notification Permission
                    PermissionButton(
                        icon: "bell.fill",
                        title: "Notification Access",
                        description: "Smart event reminders",
                        isGranted: notificationAccessGranted,
                        action: onRequestNotification
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Permission Button

struct PermissionButton: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: isGranted ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundColor(isGranted ? .green : .white.opacity(0.6))
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .disabled(isGranted)
    }
}

// MARK: - Supporting Types

enum OnboardingPageType {
    case info
    case permissions
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
    let type: OnboardingPageType
}

// MARK: - Preview
// Note: OutlookCalendarSelectionView and CalendarRow are defined in SettingsTabView.swift

#Preview {
    OnboardingView(
        calendarManager: CalendarManager(),
        googleCalendarManager: GoogleCalendarManager(),
        outlookCalendarManager: OutlookCalendarManager(),
        voiceManager: VoiceManager()
    )
}
