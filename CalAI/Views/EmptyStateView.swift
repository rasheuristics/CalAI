import SwiftUI

/// Empty state view for when no events are available
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String = "calendar",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            // Title and message
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            // Optional action button
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticManager.shared.light()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color.blue)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .accessibilityLabel(actionTitle)
                .padding(.top, DesignSystem.Spacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Predefined Empty States
extension EmptyStateView {
    static func noEvents(onAddEvent: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "No Events Today",
            message: "Your calendar is clear. Add an event to get started.",
            actionTitle: "Add Event",
            action: onAddEvent
        )
    }

    static func noCalendarAccess(onOpenSettings: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "calendar.badge.exclamationmark",
            title: "Calendar Access Required",
            message: "Grant calendar access in Settings to view your events.",
            actionTitle: "Open Settings",
            action: onOpenSettings
        )
    }

    static func loadingFailed(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Unable to Load Events",
            message: "Something went wrong. Please try again.",
            actionTitle: "Retry",
            action: onRetry
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyStateView.noEvents(onAddEvent: {})
    }
}
