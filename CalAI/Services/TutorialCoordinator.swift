import Foundation
import SwiftUI
import Combine

/// Manages the interactive tutorial flow
class TutorialCoordinator: ObservableObject {
    static let shared = TutorialCoordinator()

    @Published var currentTutorial: Tutorial?
    @Published var currentStepIndex: Int = 0
    @Published var isActive: Bool = false

    @AppStorage("hasCompletedMainTutorial") private var hasCompletedMainTutorial = false
    @AppStorage("tutorialCompletedSteps") private var completedStepsData: Data = Data()

    private var completedSteps: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCompletedSteps()
    }

    // MARK: - Tutorial Management

    /// Start a tutorial flow
    func startTutorial(_ tutorial: Tutorial) {
        currentTutorial = tutorial
        currentStepIndex = 0
        isActive = true

        print("📚 Starting tutorial: \(tutorial.id)")
        HapticManager.shared.light()
    }

    /// Advance to next step
    func nextStep() {
        guard let tutorial = currentTutorial else { return }

        if currentStepIndex < tutorial.steps.count - 1 {
            currentStepIndex += 1
            HapticManager.shared.light()
        } else {
            completeTutorial()
        }
    }

    /// Go back to previous step
    func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            HapticManager.shared.light()
        }
    }

    /// Skip current tutorial
    func skipTutorial() {
        HapticManager.shared.light()
        dismissTutorial()
    }

    /// Complete current tutorial
    func completeTutorial() {
        guard let tutorial = currentTutorial else { return }

        completedSteps.insert(tutorial.id)
        saveCompletedSteps()

        if tutorial.id == "main" {
            hasCompletedMainTutorial = true
        }

        HapticManager.shared.success()
        print("✅ Tutorial completed: \(tutorial.id)")

        dismissTutorial()
    }

    /// Dismiss current tutorial
    func dismissTutorial() {
        currentTutorial = nil
        currentStepIndex = 0
        isActive = false
    }

    // MARK: - Step Tracking

    /// Mark individual step as completed
    func markStepCompleted(_ stepId: String) {
        completedSteps.insert(stepId)
        saveCompletedSteps()
    }

    /// Check if step has been completed
    func hasCompletedStep(_ stepId: String) -> Bool {
        return completedSteps.contains(stepId)
    }

    /// Check if tutorial should auto-start
    func shouldAutoStartTutorial(_ tutorialId: String) -> Bool {
        return !completedSteps.contains(tutorialId)
    }

    // MARK: - Current Tooltip

    var currentTooltip: Tooltip? {
        guard let tutorial = currentTutorial,
              currentStepIndex < tutorial.steps.count else {
            return nil
        }

        let step = tutorial.steps[currentStepIndex]
        return Tooltip(
            id: step.id,
            icon: step.icon,
            title: step.title,
            message: step.message,
            targetViewId: step.targetViewId
        )
    }

    var hasNextStep: Bool {
        guard let tutorial = currentTutorial else { return false }
        return currentStepIndex < tutorial.steps.count - 1
    }

    // MARK: - Persistence

    private func loadCompletedSteps() {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: completedStepsData) {
            completedSteps = decoded
        }
    }

    private func saveCompletedSteps() {
        if let encoded = try? JSONEncoder().encode(completedSteps) {
            completedStepsData = encoded
        }
    }

    // MARK: - Reset

    /// Reset all tutorial progress (for testing/debugging)
    func resetAllProgress() {
        completedSteps.removeAll()
        saveCompletedSteps()
        hasCompletedMainTutorial = false
        dismissTutorial()
        print("🔄 All tutorial progress reset")
    }
}

// MARK: - Tutorial Model

struct Tutorial: Identifiable {
    let id: String
    let title: String
    let description: String
    let steps: [TutorialStep]
}

struct TutorialStep: Identifiable {
    let id: String
    let icon: String
    let title: String
    let message: String
    let targetViewId: String
}

// MARK: - Predefined Tutorials

extension Tutorial {
    /// Main app tutorial for first-time users
    static let mainTutorial = Tutorial(
        id: "main",
        title: "Getting Started with Heu Calendar AI",
        description: "Learn the basics of using Heu Calendar AI",
        steps: [
            TutorialStep(
                id: "welcome",
                icon: "hand.wave.fill",
                title: "Welcome to Heu Calendar AI",
                message: "Let's take a quick tour of the main features. You can skip this anytime.",
                targetViewId: "mainTabView"
            ),
            TutorialStep(
                id: "calendar-view",
                icon: "calendar",
                title: "Your Calendar",
                message: "This is your main calendar view. Swipe left and right to navigate between days, or tap the date to jump to any day.",
                targetViewId: "calendarView"
            ),
            TutorialStep(
                id: "add-event",
                icon: "plus.circle.fill",
                title: "Add Events",
                message: "Tap the plus button to create new events. You can use natural language like 'Lunch with John tomorrow at noon'.",
                targetViewId: "addEventButton"
            ),
            TutorialStep(
                id: "ai-suggestions",
                icon: "brain.head.profile",
                title: "AI Suggestions",
                message: "CalAI learns from your patterns and suggests optimal times for your events. Look for the sparkle icon.",
                targetViewId: "aiSuggestionsButton"
            ),
            TutorialStep(
                id: "swipe-gestures",
                icon: "hand.draw.fill",
                title: "Quick Actions",
                message: "Swipe right on any event to edit it, or swipe left to delete. It's that simple!",
                targetViewId: "eventsList"
            ),
            TutorialStep(
                id: "settings",
                icon: "gearshape.fill",
                title: "Customize Settings",
                message: "Visit Settings to connect your calendars, customize notifications, and configure AI preferences.",
                targetViewId: "settingsTab"
            )
        ]
    )

    /// AI features tutorial
    static let aiFeaturesTutorial = Tutorial(
        id: "ai-features",
        title: "AI Features",
        description: "Discover how AI makes scheduling smarter",
        steps: [
            TutorialStep(
                id: "natural-language",
                icon: "text.bubble.fill",
                title: "Natural Language",
                message: "Just type naturally: 'Team meeting next Tuesday at 2pm' and CalAI will parse it automatically.",
                targetViewId: "eventInput"
            ),
            TutorialStep(
                id: "smart-suggestions",
                icon: "lightbulb.fill",
                title: "Smart Suggestions",
                message: "CalAI analyzes your schedule and suggests the best times based on your habits and preferences.",
                targetViewId: "suggestions"
            ),
            TutorialStep(
                id: "conflict-detection",
                icon: "exclamationmark.triangle.fill",
                title: "Conflict Detection",
                message: "AI automatically detects scheduling conflicts and suggests alternative times.",
                targetViewId: "conflictDetector"
            ),
            TutorialStep(
                id: "analytics",
                icon: "chart.bar.fill",
                title: "Calendar Analytics",
                message: "Get insights into how you spend your time with AI-powered analytics.",
                targetViewId: "analyticsView"
            )
        ]
    )

    /// Smart notifications tutorial
    static let notificationsTutorial = Tutorial(
        id: "notifications",
        title: "Smart Notifications",
        description: "Context-aware reminders",
        steps: [
            TutorialStep(
                id: "travel-time",
                icon: "car.fill",
                title: "Travel Time Alerts",
                message: "CalAI calculates travel time and notifies you when it's time to leave for physical meetings.",
                targetViewId: "notifications"
            ),
            TutorialStep(
                id: "virtual-meetings",
                icon: "video.fill",
                title: "Virtual Meeting Alerts",
                message: "Get notified 5 minutes before virtual meetings with quick join links.",
                targetViewId: "notifications"
            ),
            TutorialStep(
                id: "customize-notifications",
                icon: "bell.badge.fill",
                title: "Customize Alerts",
                message: "Configure notification preferences in Settings to match your needs.",
                targetViewId: "notificationSettings"
            )
        ]
    )

    /// Quick list of all available tutorials
    static let allTutorials: [Tutorial] = [
        mainTutorial,
        aiFeaturesTutorial,
        notificationsTutorial
    ]
}

// MARK: - Tutorial Progress View

struct TutorialProgressView: View {
    @ObservedObject var coordinator: TutorialCoordinator
    let tutorial: Tutorial

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<tutorial.steps.count, id: \.self) { index in
                Circle()
                    .fill(index == coordinator.currentStepIndex ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Tutorial Launcher View

struct TutorialLauncherView: View {
    @ObservedObject private var coordinator = TutorialCoordinator.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Tutorials")
                .font(.title2.bold())

            ForEach(Tutorial.allTutorials) { tutorial in
                Button(action: {
                    coordinator.startTutorial(tutorial)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tutorial.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(tutorial.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if coordinator.hasCompletedStep(tutorial.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }

            // Reset button (for testing)
            #if DEBUG
            Button("Reset Tutorial Progress") {
                coordinator.resetAllProgress()
            }
            .font(.caption)
            .foregroundColor(.red)
            #endif
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    TutorialLauncherView()
}
