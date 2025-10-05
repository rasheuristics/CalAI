import UIKit

class HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for lower latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

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
}
