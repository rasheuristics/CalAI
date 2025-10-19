import SwiftUI
import EventKit
import CoreLocation
import AVFoundation

/// Onboarding flow for new users
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    @State private var calendarManager: CalendarManager?
    @State private var locationManager = CLLocationManager()

    @State private var calendarAccessGranted = false
    @State private var microphoneAccessGranted = false
    @State private var locationAccessGranted = false

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
                                microphoneAccessGranted: $microphoneAccessGranted,
                                locationAccessGranted: $locationAccessGranted,
                                onRequestCalendar: requestCalendarAccess,
                                onRequestMicrophone: requestMicrophoneAccess,
                                onRequestLocation: requestLocationAccess
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
        dismiss()
    }

    // MARK: - Permission Requests

    private func requestCalendarAccess() {
        print("📅 Requesting calendar access from onboarding...")
        if calendarManager == nil {
            calendarManager = CalendarManager()
        }
        calendarManager?.requestCalendarAccess()

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
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneAccessGranted = granted
                print("🎤 Microphone access: \(granted)")
            }
        }
    }

    private func requestLocationAccess() {
        print("📍 Requesting location access from onboarding...")
        locationManager.requestWhenInUseAuthorization()

        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let status = self.locationManager.authorizationStatus
            self.locationAccessGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
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
    @Binding var microphoneAccessGranted: Bool
    @Binding var locationAccessGranted: Bool

    let onRequestCalendar: () -> Void
    let onRequestMicrophone: () -> Void
    let onRequestLocation: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 10)

            Text("Grant Permissions")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("CalAI needs these permissions to provide the best experience")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            VStack(spacing: DesignSystem.Spacing.md) {
                // Calendar Permission
                PermissionButton(
                    icon: "calendar",
                    title: "Calendar Access",
                    description: "View and manage your events",
                    isGranted: calendarAccessGranted,
                    action: onRequestCalendar
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
                    description: "Travel time and location-based features",
                    isGranted: locationAccessGranted,
                    action: onRequestLocation
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding()
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

#Preview {
    OnboardingView()
}
