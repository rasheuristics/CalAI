import SwiftUI

/// Enhanced error recovery UI with actionable options
struct ErrorRecoveryView: View {
    let error: RecoverableError
    let onRecovery: (RecoveryOption) -> Void

    @State private var isExpanded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Error header
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(error.severity.color.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: error.icon)
                        .font(.system(size: 40))
                        .foregroundColor(error.severity.color)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                // Title and message
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(error.title)
                        .font(.title2.bold())
                        .foregroundColor(DesignSystem.Colors.Text.primary)
                        .multilineTextAlignment(.center)

                    Text(error.message)
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            Spacer()
                .frame(height: DesignSystem.Spacing.xxl)

            // Recovery options
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(error.recoveryOptions, id: \.title) { option in
                    RecoveryOptionButton(option: option) {
                        handleRecovery(option)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            // Technical details (expandable)
            if let details = error.technicalDetails {
                DisclosureGroup(
                    isExpanded: $isExpanded,
                    content: {
                        Text(details)
                            .font(.caption.monospaced())
                            .foregroundColor(DesignSystem.Colors.Text.tertiary)
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.Colors.Background.tertiary)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    },
                    label: {
                        Label("Technical Details", systemImage: "chevron.down")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.Text.tertiary)
                    }
                )
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.Background.primary)
    }

    private func handleRecovery(_ option: RecoveryOption) {
        HapticManager.shared.light()

        if option == .dismiss {
            dismiss()
        }

        onRecovery(option)
    }
}

// MARK: - Recovery Option Button

struct RecoveryOptionButton: View {
    let option: RecoveryOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: option.icon)
                    .font(.body.weight(.medium))
                    .frame(width: 24)

                Text(option.title)
                    .font(.body.weight(.medium))

                Spacer()
            }
            .foregroundColor(foregroundColor)
            .padding(DesignSystem.Spacing.md)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var foregroundColor: Color {
        switch option.style {
        case .primary:
            return .white
        case .secondary:
            return DesignSystem.Colors.Primary.blue
        case .destructive:
            return .red
        case .tertiary:
            return DesignSystem.Colors.Text.secondary
        }
    }

    private var backgroundColor: Color {
        switch option.style {
        case .primary:
            return DesignSystem.Colors.Primary.blue
        case .secondary:
            return DesignSystem.Colors.Primary.blue.opacity(0.1)
        case .destructive:
            return Color.red.opacity(0.1)
        case .tertiary:
            return Color.clear
        }
    }

    private var borderColor: Color {
        switch option.style {
        case .primary:
            return .clear
        case .secondary:
            return DesignSystem.Colors.Primary.blue.opacity(0.3)
        case .destructive:
            return Color.red.opacity(0.3)
        case .tertiary:
            return DesignSystem.Colors.Text.tertiary.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        option.style == .tertiary ? 1 : 0
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Error Recovery Sheet Modifier

struct ErrorRecoverySheet: ViewModifier {
    @StateObject private var errorManager = ErrorRecoveryManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $errorManager.isShowingRecovery) {
                if let error = errorManager.currentError {
                    ErrorRecoveryView(error: error) { option in
                        errorManager.attemptRecovery(option: option)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
    }
}

extension View {
    /// Add error recovery sheet to view
    func errorRecoverySheet() -> some View {
        self.modifier(ErrorRecoverySheet())
    }
}

// MARK: - Inline Error View

struct InlineErrorView: View {
    let error: RecoverableError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: error.icon)
                .foregroundColor(error.severity.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.primary)

                Text(error.message)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if error.recoveryOptions.contains(.retry) {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(error.severity.color)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(error.severity.color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Toast

struct ErrorToast: View {
    let error: RecoverableError
    @Binding var isShowing: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: error.icon)
                .foregroundColor(error.severity.color)

            Text(error.title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.Text.primary)

            Spacer()

            Button(action: { isShowing = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.Background.primary)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Full Error Recovery") {
    ErrorRecoveryView(
        error: RecoverableError(
            title: "Sync Failed",
            message: "Unable to sync your calendars. Please check your internet connection and try again.",
            icon: "arrow.triangle.2.circlepath.circle.fill",
            severity: .high,
            context: .calendarSync,
            recoveryOptions: [.retry, .enableOfflineMode, .contactSupport, .dismiss],
            canAutoRecover: false,
            technicalDetails: "NSURLError -1009: The Internet connection appears to be offline."
        )
    ) { option in
        print("Selected recovery option: \(option.title)")
    }
}

#Preview("Inline Error") {
    VStack {
        InlineErrorView(
            error: RecoverableError(
                title: "Network Error",
                message: "Unable to connect to server",
                icon: "wifi.exclamationmark",
                severity: .medium,
                context: .networkRequest,
                recoveryOptions: [.retry, .dismiss],
                canAutoRecover: false
            ),
            onRetry: { print("Retry") },
            onDismiss: { print("Dismiss") }
        )
        .padding()

        Spacer()
    }
}
