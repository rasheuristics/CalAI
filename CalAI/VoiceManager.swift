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

    override init() {
        super.init()
        requestPermissions()
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.requestRecordingPermission()
                default:
                    self?.hasRecordingPermission = false
                }
            }
        }
    }

    private func requestRecordingPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasRecordingPermission = granted
            }
        }
    }

    func startListening(completion: @escaping (String) -> Void) {
        guard hasRecordingPermission,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }

        completionHandler = completion

        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }

        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    DispatchQueue.main.async {
                        self?.completionHandler?(transcript)
                        self?.stopListening()
                    }
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    self?.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        recognitionRequest = nil
        recognitionTask = nil
    }
}