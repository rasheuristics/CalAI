import SwiftUI

/// Interactive tooltip component for guiding users through features
struct TooltipView: View {
    let tooltip: Tooltip
    let onDismiss: () -> Void
    let onNext: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Icon and title
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: tooltip.icon)
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.Primary.blue)

                Text(tooltip.title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.Text.primary)

                Spacer()

                Button(action: {
                    dismissTooltip()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.Text.tertiary)
                }
            }

            // Description
            Text(tooltip.message)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                if let onNext = onNext {
                    Button("Next") {
                        HapticManager.shared.light()
                        onNext()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.Primary.blue)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                Button(onNext != nil ? "Skip" : "Got it") {
                    dismissTooltip()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.Primary.blue)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.Primary.blue.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.Background.primary)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private func dismissTooltip() {
        HapticManager.shared.light()
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Tooltip Pointer

/// Arrow pointer that points to UI elements
struct TooltipPointer: View {
    let direction: PointerDirection
    let color: Color

    var body: some View {
        Triangle(direction: direction)
            .fill(color)
            .frame(width: 20, height: 12)
    }
}

enum PointerDirection {
    case up, down, left, right
}

struct Triangle: Shape {
    let direction: PointerDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Tooltip Overlay Container

struct TooltipOverlay: View {
    let tooltip: Tooltip
    let targetFrame: CGRect
    let onDismiss: () -> Void
    let onNext: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background with spotlight cutout
                SpotlightOverlay(targetFrame: targetFrame)
                    .ignoresSafeArea()

                // Tooltip positioned near target
                VStack(spacing: 0) {
                    if shouldShowAbove(targetFrame: targetFrame, in: geometry) {
                        TooltipView(tooltip: tooltip, onDismiss: onDismiss, onNext: onNext)

                        TooltipPointer(
                            direction: .down,
                            color: DesignSystem.Colors.Background.primary
                        )
                        .offset(x: calculatePointerOffset(targetFrame: targetFrame, in: geometry))

                        Spacer()
                    } else {
                        Spacer()

                        TooltipPointer(
                            direction: .up,
                            color: DesignSystem.Colors.Background.primary
                        )
                        .offset(x: calculatePointerOffset(targetFrame: targetFrame, in: geometry))

                        TooltipView(tooltip: tooltip, onDismiss: onDismiss, onNext: onNext)
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
    }

    private func shouldShowAbove(targetFrame: CGRect, in geometry: GeometryProxy) -> Bool {
        return targetFrame.midY > geometry.size.height / 2
    }

    private func calculatePointerOffset(targetFrame: CGRect, in geometry: GeometryProxy) -> CGFloat {
        let screenCenter = geometry.size.width / 2
        let targetCenter = targetFrame.midX
        return targetCenter - screenCenter
    }
}

// MARK: - Spotlight Overlay

struct SpotlightOverlay: View {
    let targetFrame: CGRect

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.7))
            .mask(
                Rectangle()
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .frame(width: targetFrame.width + 16, height: targetFrame.height + 16)
                            .position(x: targetFrame.midX, y: targetFrame.midY)
                            .blendMode(.destinationOut)
                    )
            )
    }
}

// MARK: - View Modifier

struct TooltipModifier: ViewModifier {
    let tooltip: Tooltip?
    let isActive: Bool
    let onDismiss: () -> Void
    let onNext: (() -> Void)?

    @State private var targetFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        targetFrame = geometry.frame(in: .global)
                    }
                }
            )
            .overlay(
                Group {
                    if isActive, let tooltip = tooltip, targetFrame != .zero {
                        TooltipOverlay(
                            tooltip: tooltip,
                            targetFrame: targetFrame,
                            onDismiss: onDismiss,
                            onNext: onNext
                        )
                    }
                }
            )
    }
}

extension View {
    /// Show tooltip for this view
    func tooltip(
        _ tooltip: Tooltip?,
        isActive: Bool,
        onDismiss: @escaping () -> Void,
        onNext: (() -> Void)? = nil
    ) -> some View {
        self.modifier(TooltipModifier(
            tooltip: tooltip,
            isActive: isActive,
            onDismiss: onDismiss,
            onNext: onNext
        ))
    }
}

// MARK: - Supporting Types

struct Tooltip: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let message: String
    let targetViewId: String

    init(id: String, icon: String, title: String, message: String, targetViewId: String = "") {
        self.id = id
        self.icon = icon
        self.title = title
        self.message = message
        self.targetViewId = targetViewId
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Button("Feature Button") {}
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
                .tooltip(
                    Tooltip(
                        id: "sample",
                        icon: "star.fill",
                        title: "New Feature",
                        message: "This is a new feature that helps you manage your calendar more efficiently. Try it out!"
                    ),
                    isActive: true,
                    onDismiss: {},
                    onNext: {}
                )
        }
    }
}
