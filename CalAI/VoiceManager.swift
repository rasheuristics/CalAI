import Foundation
import Speech
import AVFoundation

class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var hasRecordingPermission = false

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var completionHandler: ((String) -> Void)?
    private var latestTranscript = ""

    override init() {
        super.init()
        requestPermissions()
    }

    private func requestPermissions() {
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

    func startListening(completion: @escaping (String) -> Void) {
        print("🎙️ Starting listening process...")
        print("📋 Checking permissions - hasRecordingPermission: \(hasRecordingPermission)")

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
        completionHandler = completion

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
        print("✅ Recognition request created")

        // Configure audio engine
        print("🎛️ Configuring audio engine...")
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("📊 Recording format: \(recordingFormat)")

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
                self?.latestTranscript = result.bestTranscription.formattedString
                print("🎤 Transcript received: \(self?.latestTranscript ?? "")")

                if result.isFinal {
                    print("✅ Final transcript: \(self?.latestTranscript ?? "")")
                    DispatchQueue.main.async {
                        if let transcript = self?.latestTranscript, !transcript.isEmpty {
                            self?.completionHandler?(transcript)
                        }
                        self?.stopListening()
                    }
                    return
                }
            }

            if let error = error {
                print("❌ Recognition error: \(error)")
                print("📝 Current stored transcript: '\(self?.latestTranscript ?? "")'")
                // Use stored transcript after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let transcript = self?.latestTranscript, !transcript.isEmpty {
                        print("🔄 Using stored transcript after delay: \(transcript)")
                        self?.completionHandler?(transcript)
                    }
                    self?.stopListening()
                }
            }
        }
        print("🚀 Speech recognition task started")
    }

    func stopListening() {
        print("🛑 Stopping listening...")

        guard isListening else {
            print("⚠️ Already stopped listening")
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        recognitionRequest = nil
        recognitionTask = nil

        // Don't clear transcript immediately, let delayed processing use it
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.latestTranscript = ""
        }

        print("✅ Listening stopped successfully")
    }
}