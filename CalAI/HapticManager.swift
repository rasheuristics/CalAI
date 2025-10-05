import UIKit
import CoreHaptics

class HapticManager {
    static let shared = HapticManager()

    // UIKit Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // Core Haptics Engine for advanced patterns
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    private init() {
        // Prepare UIKit generators for lower latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        impactSoft.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()

        // Initialize Core Haptics
        setupCoreHaptics()
    }

    // MARK: - Core Haptics Setup

    private func setupCoreHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            supportsHaptics = true

            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("❌ Failed to restart haptic engine: \(error)")
                }
            }

            print("✅ Core Haptics initialized")
        } catch {
            print("❌ Core Haptics initialization failed: \(error)")
            supportsHaptics = false
        }
    }

    // MARK: - Basic Haptics

    // Light impact - for subtle interactions
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    // Medium impact - for standard interactions
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    // Heavy impact - for significant interactions
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    // Rigid impact - for precise interactions
    func rigid() {
        impactRigid.impactOccurred()
        impactRigid.prepare()
    }

    // Soft impact - for gentle interactions
    func soft() {
        impactSoft.impactOccurred()
        impactSoft.prepare()
    }

    // Selection feedback - for picker/segmented controls
    func selection() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    // Success notification
    func success() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    // Warning notification
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }

    // Error notification
    func error() {
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }

    // MARK: - Advanced Haptic Patterns

    /// Event created - celebratory double tap
    func eventCreated() {
        guard supportsHaptics else {
            success()
            return
        }

        playPattern([
            (intensity: 0.7, sharpness: 0.5, delay: 0.0),
            (intensity: 1.0, sharpness: 0.7, delay: 0.1)
        ])
    }

    /// Event deleted - warning thud
    func eventDeleted() {
        guard supportsHaptics else {
            warning()
            return
        }

        playPattern([
            (intensity: 0.8, sharpness: 0.3, delay: 0.0),
            (intensity: 0.4, sharpness: 0.2, delay: 0.05)
        ])
    }

    /// Swipe gesture - sliding feedback
    func swipeGesture(progress: CGFloat) {
        let clampedProgress = max(0, min(1, progress))
        impactLight.impactOccurred(intensity: clampedProgress)
        impactLight.prepare()
    }

    /// Pull to refresh - elastic stretch
    func pullToRefresh(progress: CGFloat) {
        let clampedProgress = max(0, min(1, progress))
        if clampedProgress > 0.5 {
            impactLight.impactOccurred(intensity: (clampedProgress - 0.5) * 2)
            impactLight.prepare()
        }
    }

    /// Refresh started - quick burst
    func refreshStarted() {
        guard supportsHaptics else {
            medium()
            return
        }

        playPattern([
            (intensity: 0.5, sharpness: 0.8, delay: 0.0),
            (intensity: 0.7, sharpness: 0.9, delay: 0.05),
            (intensity: 0.9, sharpness: 1.0, delay: 0.1)
        ])
    }

    /// Conflict detected - warning pulse
    func conflictDetected() {
        guard supportsHaptics else {
            warning()
            return
        }

        playPattern([
            (intensity: 0.6, sharpness: 0.4, delay: 0.0),
            (intensity: 0.8, sharpness: 0.5, delay: 0.15),
            (intensity: 0.6, sharpness: 0.4, delay: 0.3)
        ])
    }

    /// Time suggestion - subtle notification
    func timeSuggestion() {
        guard supportsHaptics else {
            light()
            return
        }

        playPattern([
            (intensity: 0.4, sharpness: 0.7, delay: 0.0),
            (intensity: 0.3, sharpness: 0.6, delay: 0.08)
        ])
    }

    /// Calendar sync completed - success wave
    func syncCompleted() {
        guard supportsHaptics else {
            success()
            return
        }

        playPattern([
            (intensity: 0.5, sharpness: 0.5, delay: 0.0),
            (intensity: 0.7, sharpness: 0.6, delay: 0.1),
            (intensity: 0.9, sharpness: 0.7, delay: 0.2),
            (intensity: 0.6, sharpness: 0.5, delay: 0.3)
        ])
    }

    /// Loading started - subtle tick
    func loadingStarted() {
        guard supportsHaptics else {
            soft()
            return
        }

        playPattern([
            (intensity: 0.3, sharpness: 0.8, delay: 0.0)
        ])
    }

    /// Drag and drop - pick up/put down
    func dragStarted() {
        rigid()
    }

    func dragEnded() {
        soft()
    }

    /// Toggle switch - crisp click
    func toggleSwitch() {
        rigid()
    }

    /// Button press - satisfying tap
    func buttonPress() {
        impactMedium.impactOccurred(intensity: 0.7)
        impactMedium.prepare()
    }

    /// Long press detected - confirmation
    func longPressDetected() {
        guard supportsHaptics else {
            medium()
            return
        }

        playPattern([
            (intensity: 0.6, sharpness: 0.5, delay: 0.0),
            (intensity: 0.8, sharpness: 0.6, delay: 0.05)
        ])
    }

    /// Navigation - page transition
    func pageTransition() {
        light()
    }

    /// Modal presentation
    func modalPresented() {
        impactMedium.impactOccurred(intensity: 0.5)
        impactMedium.prepare()
    }

    func modalDismissed() {
        impactLight.impactOccurred(intensity: 0.4)
        impactLight.prepare()
    }

    // MARK: - Core Haptics Pattern Player

    private func playPattern(_ events: [(intensity: Float, sharpness: Float, delay: TimeInterval)]) {
        guard supportsHaptics, let engine = hapticEngine else { return }

        var hapticEvents: [CHHapticEvent] = []

        for event in events {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)

            let hapticEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: event.delay
            )

            hapticEvents.append(hapticEvent)
        }

        do {
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play haptic pattern: \(error)")
        }
    }

    // MARK: - Continuous Haptics

    /// Play continuous haptic for duration (e.g., for long operations)
    func playContinuous(duration: TimeInterval, intensity: Float = 0.5, sharpness: Float = 0.5) {
        guard supportsHaptics, let engine = hapticEngine else { return }

        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("❌ Failed to play continuous haptic: \(error)")
        }
    }

    // MARK: - Accessibility

    /// Check if haptics are enabled in system settings
    var isEnabled: Bool {
        return supportsHaptics
    }

    /// Disable all haptics (for user preference)
    private var hapticsDisabled = false

    func setEnabled(_ enabled: Bool) {
        hapticsDisabled = !enabled
    }

    private func shouldPlayHaptic() -> Bool {
        return !hapticsDisabled && supportsHaptics
    }
}

// MARK: - Haptic Context

enum HapticContext {
    case eventCreation
    case eventDeletion
    case eventUpdate
    case swipeGesture
    case pullRefresh
    case conflictDetection
    case timeSuggestion
    case syncComplete
    case navigation
    case modalPresentation
    case toggleSwitch
    case buttonPress
    case error
    case success
    case warning
}

extension HapticManager {
    /// Play context-appropriate haptic
    func play(context: HapticContext) {
        guard shouldPlayHaptic() else { return }

        switch context {
        case .eventCreation:
            eventCreated()
        case .eventDeletion:
            eventDeleted()
        case .eventUpdate:
            medium()
        case .swipeGesture:
            light()
        case .pullRefresh:
            refreshStarted()
        case .conflictDetection:
            conflictDetected()
        case .timeSuggestion:
            timeSuggestion()
        case .syncComplete:
            syncCompleted()
        case .navigation:
            pageTransition()
        case .modalPresentation:
            modalPresented()
        case .toggleSwitch:
            toggleSwitch()
        case .buttonPress:
            buttonPress()
        case .error:
            error()
        case .success:
            success()
        case .warning:
            warning()
        }
    }
}
