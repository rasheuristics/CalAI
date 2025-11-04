import Foundation
import Combine

/// Handles conversation interruptions and corrections during voice interactions
class ConversationInterruptionHandler: ObservableObject {

    // MARK: - Types

    enum InterruptionType {
        case userSpeaking  // User started speaking while AI is processing
        case correction    // User wants to correct previous statement
        case cancellation  // User wants to cancel current operation
        case clarification // User providing clarification to previous question
    }

    struct InterruptionContext {
        let type: InterruptionType
        let timestamp: Date
        let previousTranscript: String?
        let newTranscript: String
    }

    // MARK: - Properties

    @Published var isInterrupted = false
    @Published var currentInterruption: InterruptionContext?

    private var ongoingOperation: Task<Void, Never>?
    private var interruptionCallback: ((InterruptionContext) -> Void)?

    // Correction detection keywords
    private let correctionKeywords = ["no", "wait", "sorry", "actually", "I meant", "correction", "cancel", "stop", "nevermind"]
    private let clarificationKeywords = ["yes", "no", "sure", "okay", "confirm", "that's right", "correct"]

    // MARK: - Detection

    func detectInterruption(newTranscript: String, previousTranscript: String?, isAIProcessing: Bool) -> InterruptionType? {
        let transcript = newTranscript.lowercased()

        // Check for cancellation
        if transcript.contains("cancel") || transcript.contains("stop") || transcript.contains("nevermind") {
            return .cancellation
        }

        // Check for correction
        for keyword in correctionKeywords {
            if transcript.hasPrefix(keyword) || transcript.contains(" \(keyword) ") {
                return .correction
            }
        }

        // Check for clarification (if AI asked a question)
        if previousTranscript != nil {
            for keyword in clarificationKeywords {
                if transcript.hasPrefix(keyword) || transcript == keyword {
                    return .clarification
                }
            }
        }

        // Check if user is speaking while AI is processing
        if isAIProcessing && !newTranscript.isEmpty {
            return .userSpeaking
        }

        return nil
    }

    // MARK: - Handling

    func handleInterruption(
        type: InterruptionType,
        newTranscript: String,
        previousTranscript: String? = nil,
        onInterruption: @escaping (InterruptionContext) -> Void
    ) {
        let context = InterruptionContext(
            type: type,
            timestamp: Date(),
            previousTranscript: previousTranscript,
            newTranscript: newTranscript
        )

        currentInterruption = context
        isInterrupted = true
        interruptionCallback = onInterruption

        // Cancel ongoing operation
        cancelOngoingOperation()

        // Execute callback
        onInterruption(context)

        print("⚠️ Interruption: \(type) - '\(newTranscript)'")
    }

    func cancelOngoingOperation() {
        ongoingOperation?.cancel()
        ongoingOperation = nil
        print("❌ Canceled ongoing operation due to interruption")
    }

    func registerOngoingOperation(_ task: Task<Void, Never>) {
        ongoingOperation = task
    }

    func clearInterruption() {
        isInterrupted = false
        currentInterruption = nil
        interruptionCallback = nil
        print("✅ Interruption cleared")
    }

    // MARK: - Correction Processing

    func processCorrection(
        originalTranscript: String,
        correctionTranscript: String
    ) -> String {
        // Extract the correction intent
        let correction = correctionTranscript.lowercased()

        // Handle common correction patterns
        if correction.contains("I meant") {
            // "No, I meant 3pm" -> extract "3pm"
            if let range = correction.range(of: "I meant") {
                let afterMeant = String(correction[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return afterMeant
            }
        }

        if correction.hasPrefix("no") || correction.hasPrefix("wait") || correction.hasPrefix("actually") {
            // "No, make it 3pm" -> extract "make it 3pm"
            let keywords = ["no,", "no ", "wait,", "wait ", "actually,", "actually ", "sorry,", "sorry "]
            for keyword in keywords {
                if let range = correction.range(of: keyword) {
                    let afterKeyword = String(correction[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !afterKeyword.isEmpty {
                        return afterKeyword
                    }
                }
            }
        }

        // If no pattern matched, return the whole correction
        return correctionTranscript
    }

    // MARK: - State Management

    func isCurrentlyInterrupted() -> Bool {
        return isInterrupted
    }

    func getLastInterruption() -> InterruptionContext? {
        return currentInterruption
    }

    func shouldProcessAsCorrection(_ transcript: String) -> Bool {
        guard let interruption = currentInterruption else {
            return false
        }

        switch interruption.type {
        case .correction:
            return true
        case .clarification:
            return false // Clarifications are additions, not corrections
        case .cancellation, .userSpeaking:
            return false
        }
    }

    // MARK: - Smart Restart

    func shouldRestartListening(after interruption: InterruptionContext) -> Bool {
        switch interruption.type {
        case .correction:
            return true // Allow user to finish correcting
        case .clarification:
            return false // Clarification is usually final
        case .cancellation:
            return false // User wants to stop
        case .userSpeaking:
            return true // Let user continue speaking
        }
    }

    func getRestartDelay(for interruption: InterruptionContext) -> TimeInterval {
        switch interruption.type {
        case .correction:
            return 0.5 // Quick restart for corrections
        case .userSpeaking:
            return 0.2 // Very quick for active speech
        case .clarification:
            return 1.0 // Longer delay for clarifications
        case .cancellation:
            return 0 // No restart
        }
    }
}
