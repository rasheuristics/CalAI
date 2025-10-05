import SwiftUI

/// Onboarding flow for new users
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar.badge.plus",
            title: "Welcome to CalAI",
            description: "Your intelligent calendar assistant that learns from your habits and helps you schedule smarter.",
            gradient: [Color.blue, Color.purple]
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "AI-Powered Suggestions",
            description: "Get smart event suggestions based on your patterns. Natural language input makes scheduling effortless.",
            gradient: [Color.purple, Color.pink]
        ),
        OnboardingPage(
            icon: "calendar.circle.fill",
            title: "Multi-Calendar Sync",
            description: "Connect iOS Calendar, Google Calendar, and Outlook. All your events in one place.",
            gradient: [Color.pink, Color.orange]
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Smart Notifications",
            description: "Context-aware notifications that adapt to your location, travel time, and meeting type.",
            gradient: [Color.orange, Color.red]
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "You're All Set!",
            description: "Let's get started by connecting your first calendar.",
            gradient: [Color.green, Color.blue]
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
                        OnboardingPageView(page: pages[index])
                            .tag(index)
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

// MARK: - Supporting Types

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
