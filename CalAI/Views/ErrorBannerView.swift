import SwiftUI

struct ErrorBannerView: View {
    let error: AppError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.title3)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(error.message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: {
                    HapticManager.shared.light()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .accessibilityLabel("Dismiss error")
                .accessibilityHint("Double tap to dismiss this error message")
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Settings button for access denied errors
                if case .calendarAccessDenied = error {
                    Button(action: {
                        HapticManager.shared.medium()
                        openSettings()
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Open Settings")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                    .accessibilityLabel("Open Settings")
                    .accessibilityHint("Double tap to open app settings")
                }

                // Retry button for retryable errors
                if error.isRetryable {
                    Button(action: {
                        HapticManager.shared.medium()
                        onRetry()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                    .accessibilityLabel("Retry")
                    .accessibilityHint("Double tap to retry the failed operation")
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .designSystemShadow(DesignSystem.Shadow.error)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(error.title)")
        .accessibilityValue(error.message)
    }
}

#Preview {
    VStack {
        ErrorBannerView(
            error: .calendarAccessDenied,
            onRetry: { },
            onDismiss: { }
        )

        ErrorBannerView(
            error: .failedToLoadEvents(NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])),
            onRetry: { },
            onDismiss: { }
        )
    }
}
