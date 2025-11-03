import Foundation
import Speech
import AVFoundation

class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var hasRecordingPermission = false
    @Published var currentTranscript = "" // Real-time transcript updates
    @Published var isSpeechDetected = false // True when user is actively speaking

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var completionHandler: ((String) -> Void)?
    private var partialTranscriptHandler: ((String) -> Void)?
    private var speechDetectedHandler: (() -> Void)? // Called immediately when speech starts
    private var latestTranscript = ""
    private var hasProcessedResult = false // Prevents duplicate processing

    // Silence detection
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 5.0 // 5 seconds of silence (allows 3+ second pause between tasks)
    private var autoStopEnabled = true // Can be toggled

    // Continuous listening mode
    @Published var isContinuousMode = false
    private var continuousModeEnabled = false
    private var lastTranscriptLength = 0

    override init() {
        super.init()
        // Don't request permissions automatically - will be requested from onboarding
        checkExistingPermissions()
    }

    private func checkExistingPermissions() {
        // Check if permissions were already granted without requesting
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission

        DispatchQueue.main.async {
            self.hasRecordingPermission = (speechStatus == .authorized && micStatus == .granted)
        }
    }

    func requestPermissions() {
        print("🎤 Requesting speech recognition permissions...")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ Speech recognition authorized")
                    self?.requestRecordingPermission()
                case .denied:
                    print("❌ Speech recognition denied")
                    self?.hasRecordingPermission = false
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self?.hasRecordingPermission = false
                case .notDetermined:
                    print("❌ Speech recognition not determined")
                    self?.hasRecordingPermission = false
                @unknown default:
                    print("❌ Speech recognition unknown status")
                    self?.hasRecordingPermission = false
                }
            }
        }
    }

    private func requestRecordingPermission() {
        print("🎤 Requesting microphone permissions...")
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted")
                    self?.hasRecordingPermission = true
                } else {
                    print("❌ Microphone permission denied")
                    self?.hasRecordingPermission = false
                }
            }
        }
    }

    func startListening(continuous: Bool = false, onPartialTranscript: ((String) -> Void)? = nil, onSpeechDetected: (() -> Void)? = nil, completion: @escaping (String) -> Void) {
        print("🎙️ Starting listening process... (continuous: \(continuous))")
        print("📋 Checking permissions - hasRecordingPermission: \(hasRecordingPermission)")

        // Prevent starting if already listening
        guard !isListening else {
            print("⚠️ Already listening, stopping existing session first...")
            stopListening()
            // Schedule restart after a brief delay to allow cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.startListening(continuous: continuous, onPartialTranscript: onPartialTranscript, onSpeechDetected: onSpeechDetected, completion: completion)
            }
            return
        }

        guard hasRecordingPermission else {
            print("❌ Recording permission not granted")
            return
        }

        guard let speechRecognizer = speechRecognizer else {
            print("❌ Speech recognizer is nil")
            return
        }

        guard speechRecognizer.isAvailable else {
            print("❌ Speech recognizer is not available")
            return
        }

        print("✅ All permissions and requirements met")
        continuousModeEnabled = continuous
        isContinuousMode = continuous
        completionHandler = completion
        partialTranscriptHandler = onPartialTranscript
        speechDetectedHandler = onSpeechDetected
        hasProcessedResult = false // Reset for new session
        lastTranscriptLength = 0

        // Clear previous transcript
        DispatchQueue.main.async {
            self.currentTranscript = ""
            self.isSpeechDetected = false
        }

        // Cancel previous task
        print("🔄 Canceling previous recognition task...")
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        print("🔧 Configuring audio session...")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Audio session setup failed: \(error)")
            return
        }

        // Create recognition request
        print("📝 Creating recognition request...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        // Configure for longer listening sessions
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false // Allow server-based for longer sessions
        }

        // Set task hint for dictation (more forgiving with pauses)
        if #available(iOS 13, *) {
            recognitionRequest.taskHint = .dictation // More patient with pauses than .search or .confirmation
        }

        print("✅ Recognition request created with extended listening settings")

        // Configure audio engine
        print("🎛️ Configuring audio engine...")
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("📊 Recording format: \(recordingFormat)")

        // Remove any existing tap before installing new one
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
            print("🧹 Removed existing tap before installing new one")
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        print("🎛️ Audio engine prepared")

        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
            DispatchQueue.main.async {
                self.isListening = true
            }
        } catch {
            print("❌ Audio engine failed to start: \(error)")
            return
        }

        // Start recognition
        print("🎯 Starting speech recognition task...")
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in

            if let result = result {
                let newTranscript = result.bestTranscription.formattedString
                print("🎤 Transcript received: \(newTranscript)")

                // Detect speech start (any new words)
                let currentLength = newTranscript.count
                if currentLength > (self?.lastTranscriptLength ?? 0) {
                    // New speech detected!
                    DispatchQueue.main.async {
                        if !(self?.isSpeechDetected ?? false) {
                            print("🗣️ SPEECH DETECTED - User started speaking!")
                            self?.isSpeechDetected = true
                            self?.speechDetectedHandler?()
                        }
                    }
                    self?.lastTranscriptLength = currentLength
                }

                // Only update if we have a non-empty transcript or no previous transcript
                if !newTranscript.isEmpty || (self?.latestTranscript.isEmpty ?? true) {
                    self?.latestTranscript = newTranscript

                    // Update published property for real-time display
                    DispatchQueue.main.async {
                        self?.currentTranscript = newTranscript
                        self?.partialTranscriptHandler?(newTranscript)
                    }

                    // Reset silence timer on new transcript
                    self?.resetSilenceTimer()
                }

                if result.isFinal {
                    print("✅ Final transcript: \(self?.latestTranscript ?? "")")
                    self?.invalidateSilenceTimer()
                    DispatchQueue.main.async {
                        guard let self = self, !self.hasProcessedResult else { return }
                        let transcript = self.latestTranscript
                        if !transcript.isEmpty {
                            self.hasProcessedResult = true

                            // Save continuous mode state before stopping
                            let wasContinuous = self.continuousModeEnabled

                            self.completionHandler?(transcript)

                            // In continuous mode, stop audio engine but preserve continuous flag
                            // Let the caller (AITabView) decide when to restart after AI response
                            if wasContinuous {
                                print("🔄 Continuous mode: Stopping audio engine but preserving continuous flag")
                                self.audioEngine.stop()
                                self.audioEngine.inputNode.removeTap(onBus: 0)
                                self.recognitionRequest?.endAudio()
                                self.recognitionTask?.cancel()
                                self.isListening = false
                                // Don't clear continuousModeEnabled - keep it for restart
                            } else {
                                self.stopListening()
                            }
                        }
                    }
                    return
                }
            }

            if let error = error {
                print("❌ Recognition error: \(error)")
                print("📝 Current stored transcript: '\(self?.latestTranscript ?? "")'")

                self?.invalidateSilenceTimer()

                // Don't process on cancellation errors - these happen during normal stop
                let nsError = error as NSError
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    print("🔄 Recognition canceled - using stored transcript if available")
                    DispatchQueue.main.async {
                        guard let self = self, !self.hasProcessedResult else {
                            self?.stopListening()
                            return
                        }
                        let transcript = self.latestTranscript
                        if !transcript.isEmpty {
                            print("✅ Processing stored transcript: \(transcript)")
                            self.hasProcessedResult = true
                            self.completionHandler?(transcript)
                        }
                        self.stopListening()
                    }
                } else {
                    // Other errors - use delayed processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard let self = self, !self.hasProcessedResult else {
                            self?.stopListening()
                            return
                        }
                        let transcript = self.latestTranscript
                        if !transcript.isEmpty {
                            print("🔄 Using stored transcript after delay: \(transcript)")
                            self.hasProcessedResult = true
                            self.completionHandler?(transcript)
                        }
                        self.stopListening()
                    }
                }
            }
        }
        print("🚀 Speech recognition task started")
    }

    private func resetSilenceTimer() {
        guard autoStopEnabled else { return }

        DispatchQueue.main.async { [weak self] in
            self?.silenceTimer?.invalidate()
            self?.silenceTimer = Timer.scheduledTimer(withTimeInterval: self?.silenceThreshold ?? 5.0, repeats: false) { [weak self] _ in
                print("⏱️ Silence detected - auto-stopping")
                self?.handleSilenceDetected()
            }
        }
    }

    private func invalidateSilenceTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.silenceTimer?.invalidate()
            self?.silenceTimer = nil
        }
    }

    private func handleSilenceDetected() {
        guard autoStopEnabled, isListening else { return }

        print("🔇 Silence threshold reached - finalizing transcript")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.hasProcessedResult else {
                self?.stopListening()
                return
            }
            let transcript = self.latestTranscript
            if !transcript.isEmpty {
                print("✅ Auto-stop with transcript: \(transcript)")
                self.hasProcessedResult = true

                // Save continuous mode state before stopping
                let wasContinuous = self.continuousModeEnabled

                self.completionHandler?(transcript)

                // In continuous mode, stop audio engine but preserve continuous flag
                // Let the caller (AITabView) decide when to restart after AI response
                if wasContinuous {
                    print("🔄 Continuous mode: Stopping audio engine but preserving continuous flag")
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.recognitionRequest?.endAudio()
                    self.recognitionTask?.cancel()
                    self.isListening = false
                    // Don't clear continuousModeEnabled - keep it for restart
                } else {
                    self.stopListening()
                }
                return
            }
            if !self.continuousModeEnabled {
                self.stopListening()
            }
        }
    }

    private func restartListeningForContinuousMode() {
        // Briefly stop and restart to process the current transcript
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.continuousModeEnabled else { return }

            print("🔄 Restarting listening in continuous mode...")

            // Stop current session
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.recognitionRequest?.endAudio()
            self.recognitionTask?.cancel()

            // Reset state for new session
            self.latestTranscript = ""
            self.hasProcessedResult = false
            self.lastTranscriptLength = 0

            DispatchQueue.main.async {
                self.currentTranscript = ""
                self.isSpeechDetected = false
            }

            // Restart listening with same handlers
            let savedCompletionHandler = self.completionHandler
            let savedPartialHandler = self.partialTranscriptHandler
            let savedSpeechDetectedHandler = self.speechDetectedHandler

            if let completion = savedCompletionHandler {
                self.startListening(
                    continuous: true,
                    onPartialTranscript: savedPartialHandler,
                    onSpeechDetected: savedSpeechDetectedHandler,
                    completion: completion
                )
            }
        }
    }

    func stopListening() {
        print("🛑 Stopping listening...")

        guard isListening else {
            print("⚠️ Already stopped listening")
            return
        }

        invalidateSilenceTimer()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        continuousModeEnabled = false // Stop continuous mode
        recognitionRequest = nil
        recognitionTask = nil

        // Clear published transcript immediately
        DispatchQueue.main.async {
            self.currentTranscript = ""
            self.isContinuousMode = false
            self.isSpeechDetected = false
        }

        // Don't clear latestTranscript immediately, let delayed processing use it
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.latestTranscript = ""
            self.lastTranscriptLength = 0
        }

        print("✅ Listening stopped successfully")
    }

    // Enable/disable continuous listening mode
    func setContinuousMode(_ enabled: Bool) {
        continuousModeEnabled = enabled
        DispatchQueue.main.async {
            self.isContinuousMode = enabled
        }
        print("🔄 Continuous mode set to: \(enabled)")
    }
}