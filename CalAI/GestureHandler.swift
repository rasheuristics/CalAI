import SwiftUI

/// Reusable gesture handler for swipe navigation with velocity-based thresholds
struct SwipeGestureHandler {

    // MARK: - Configuration
    struct Configuration {
        var minimumDistance: CGFloat = 20
        var velocityThreshold: CGFloat = 100
        var hapticFeedback: Bool = true
        var rubberBandEnabled: Bool = true
        var rubberBandDamping: CGFloat = 0.3
    }

    // MARK: - State
    enum Direction {
        case none
        case horizontal
        case vertical
    }

    // MARK: - Callbacks
    typealias ProgressCallback = (CGFloat, CGFloat) -> Void  // (offset, progress)
    typealias CompletionCallback = (SwipeResult) -> Void

    struct SwipeResult {
        let direction: HorizontalDirection
        let velocity: CGFloat
        let distance: CGFloat

        enum HorizontalDirection {
            case left
            case right
        }
    }

    // MARK: - Properties
    let config: Configuration
    let onProgress: ProgressCallback?
    let onComplete: CompletionCallback?

    init(
        config: Configuration = Configuration(),
        onProgress: ProgressCallback? = nil,
        onComplete: CompletionCallback? = nil
    ) {
        self.config = config
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    // MARK: - Gesture Processing

    /// Calculate swipe offset with optional rubber-band effect
    func calculateOffset(
        translation: CGFloat,
        screenWidth: CGFloat
    ) -> CGFloat {
        guard config.rubberBandEnabled else { return translation }

        let rawOffset = translation

        if abs(rawOffset) > screenWidth {
            // Apply damping for over-scroll
            let excess = abs(rawOffset) - screenWidth
            let dampedExcess = excess * config.rubberBandDamping
            return rawOffset > 0 ? screenWidth + dampedExcess : -(screenWidth + dampedExcess)
        }

        return rawOffset
    }

    /// Calculate swipe progress (0 to 1)
    func calculateProgress(
        translation: CGFloat,
        threshold: CGFloat
    ) -> CGFloat {
        return min(abs(translation) / threshold, 1.0)
    }

    /// Determine if gesture should trigger action based on distance and velocity
    func shouldTrigger(
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        screenWidth: CGFloat
    ) -> Bool {
        let distanceThreshold = screenWidth / 2
        let velocity = abs(predictedEndTranslation - translation)
        let isQuickSwipe = velocity > config.velocityThreshold
        let effectiveThreshold = isQuickSwipe ? screenWidth / 3 : distanceThreshold

        return abs(translation) > effectiveThreshold
    }

    /// Determine gesture direction based on translation amounts
    static func determineDirection(
        horizontal: CGFloat,
        vertical: CGFloat,
        threshold: CGFloat = 10
    ) -> Direction {
        if horizontal < threshold && vertical < threshold {
            return .none
        }
        return horizontal > vertical ? .horizontal : .vertical
    }
}

/// View modifier for swipe gestures
struct SwipeGestureModifier: ViewModifier {
    let handler: SwipeGestureHandler

    @Binding var offset: CGFloat
    @Binding var progress: CGFloat
    @Binding var isTransitioning: Bool

    @State private var gestureDirection: SwipeGestureHandler.Direction = .none

    let onSwipe: (SwipeGestureHandler.SwipeResult) -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: handler.config.minimumDistance)
                    .onChanged { value in
                        guard !isTransitioning else { return }

                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)

                        // Determine gesture direction on first movement
                        if gestureDirection == .none {
                            gestureDirection = SwipeGestureHandler.determineDirection(
                                horizontal: horizontalAmount,
                                vertical: verticalAmount
                            )
                        }

                        // Only process horizontal swipes
                        if gestureDirection == .horizontal && horizontalAmount > handler.config.minimumDistance {
                            let screenWidth = UIScreen.main.bounds.width
                            offset = handler.calculateOffset(
                                translation: value.translation.width,
                                screenWidth: screenWidth
                            )

                            progress = handler.calculateProgress(
                                translation: value.translation.width,
                                threshold: screenWidth / 2
                            )

                            handler.onProgress?(offset, progress)
                        }
                    }
                    .onEnded { value in
                        guard !isTransitioning else { return }

                        if gestureDirection == .horizontal {
                            let screenWidth = UIScreen.main.bounds.width

                            if handler.shouldTrigger(
                                translation: value.translation.width,
                                predictedEndTranslation: value.predictedEndTranslation.width,
                                screenWidth: screenWidth
                            ) {
                                // Trigger swipe action
                                let result = SwipeGestureHandler.SwipeResult(
                                    direction: value.translation.width > 0 ? .right : .left,
                                    velocity: abs(value.predictedEndTranslation.width - value.translation.width),
                                    distance: abs(value.translation.width)
                                )

                                if handler.config.hapticFeedback {
                                    HapticManager.shared.light()
                                }

                                onSwipe(result)
                            } else {
                                // Snap back
                                if handler.config.hapticFeedback {
                                    HapticManager.shared.light()
                                }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    offset = 0
                                }
                            }
                        }

                        // Reset gesture state
                        offset = 0
                        progress = 0
                        gestureDirection = .none
                    }
            )
    }
}

extension View {
    func swipeGesture(
        handler: SwipeGestureHandler,
        offset: Binding<CGFloat>,
        progress: Binding<CGFloat>,
        isTransitioning: Binding<Bool>,
        onSwipe: @escaping (SwipeGestureHandler.SwipeResult) -> Void
    ) -> some View {
        self.modifier(SwipeGestureModifier(
            handler: handler,
            offset: offset,
            progress: progress,
            isTransitioning: isTransitioning,
            onSwipe: onSwipe
        ))
    }
}
