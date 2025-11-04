import Foundation
import AVFoundation

/// Provides voice feedback during long-running operations
class VoiceFeedbackService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    // MARK: - Types

    enum FeedbackType {
        case processing
        case searching
        case creating
        case updating
        case deleting
        case complete
        case error(String)
        case custom(String)

        var message: String {
            switch self {
            case .processing:
                return "Processing your request..."
            case .searching:
                return "Searching..."
            case .creating:
                return "Creating..."
            case .updating:
                return "Updating..."
            case .deleting:
                return "Deleting..."
            case .complete:
                return "Done"
            case .error(let msg):
                return msg
            case .custom(let msg):
                return msg
            }
        }
    }

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    @Published var isSpeaking = false
    @Published var currentFeedback: String?

    // Settings
    var isEnabled = true
    var rate: Float = 0.5 // Speaking rate (0.0 - 1.0)
    var volume: Float = 1.0 // Volume (0.0 - 1.0)
    var pitch: Float = 1.0 // Pitch (0.5 - 2.0)

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Feedback

    func provideFeedback(_ type: FeedbackType, delay: TimeInterval = 0) {
        guard isEnabled else { return }

        let message = type.message

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.speak(message)
            }
        } else {
            speak(message)
        }
    }

    func provideProgressFeedback(_ message: String) {
        guard isEnabled else { return }
        speak(message)
    }

    private func speak(_ message: String) {
        // Stop current speech if any
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = rate
        utterance.volume = volume
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        currentUtterance = utterance
        currentFeedback = message
        isSpeaking = true

        synthesizer.speak(utterance)

        print("🔊 VoiceFeedback: Speaking '\(message)'")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentFeedback = nil
        currentUtterance = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentFeedback = nil
            self.currentUtterance = nil
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentFeedback = nil
            self.currentUtterance = nil
        }
    }

    // MARK: - Convenience Methods

    func announceProcessing() {
        provideFeedback(.processing)
    }

    func announceSearching() {
        provideFeedback(.searching)
    }

    func announceCreating() {
        provideFeedback(.creating)
    }

    func announceComplete() {
        provideFeedback(.complete)
    }

    func announceError(_ message: String) {
        provideFeedback(.error(message))
    }

    // MARK: - Long Operation Support

    func announceWithProgress<T>(operation: String, task: @escaping () async throws -> T) async throws -> T {
        // Announce start after 1 second delay (only if operation takes longer)
        let delayTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled {
                provideFeedback(.custom(operation))
            }
        }

        do {
            let result = try await task()
            delayTask.cancel() // Cancel announcement if completed quickly
            return result
        } catch {
            delayTask.cancel()
            throw error
        }
    }
}
