import SwiftUI
import EventKit
import AVFoundation

// MARK: - Animated Components

/// Animated waveform icon that shows audio activity
struct AnimatedWaveformIcon: View {
    let isAnimating: Bool
    let color: Color
    let size: CGFloat

    @State private var waveOffsets: [CGFloat] = [0.3, 0.3, 0.3, 0.3, 0.3]

    var body: some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(color)
                    .frame(width: size * 0.12, height: barHeight(for: index))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if isAnimating {
                startAnimating()
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight = size * 0.3
        let maxHeight = size * 0.9
        return baseHeight + (maxHeight - baseHeight) * waveOffsets[index]
    }

    private func startAnimating() {
        for i in 0..<5 {
            animateBar(index: i)
        }
    }

    private func stopAnimating() {
        waveOffsets = [0.3, 0.3, 0.3, 0.3, 0.3]
    }

    private func animateBar(index: Int) {
        let durations: [Double] = [0.4, 0.5, 0.35, 0.45, 0.4]
        let delays: [Double] = [0, 0.1, 0.05, 0.15, 0.08]

        withAnimation(
            Animation.easeInOut(duration: durations[index])
                .repeatForever(autoreverses: true)
                .delay(delays[index])
        ) {
            waveOffsets[index] = CGFloat.random(in: 0.6...1.0)
        }
    }
}

/// Processing indicator - rotating circle spinner
struct ProcessingIndicator: View {
    let color: Color
    let size: CGFloat

    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
    }
}

// MARK: - Supporting Definitions

// MARK: - Query Display Mode
enum QueryDisplayMode: String, Codable, CaseIterable {
    case summaryOnly = "Summary Only"
    case eventsOnly = "Events Only"
    case both = "Summary & Events"
}

// This extension is placed here to be in scope for both SpeechManager and any potential settings views.
extension UserDefaults {
    struct Keys {
        static let aiProvider = "AIProvider"
        static let aiOutputMode = "AIOutputMode"
        static let queryDisplayMode = "QueryDisplayMode"
        static let speechVoiceIdentifier = "speechVoiceIdentifier"
        static let speechRate = "speechRate"
        static let speechPitch = "speechPitch"
        static let speechSentencePause = "speechSentencePause"
        static let audioEffectsEnabled = "audioEffectsEnabled"
        static let audioEQBass = "audioEQBass"
        static let audioEQMid = "audioEQMid"
        static let audioEQTreble = "audioEQTreble"
    }
}

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    private var completionHandler: (() -> Void)?

    // Audio effects
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var eqNode: AVAudioUnitEQ?

    // Speaking state
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false

    // Sentence queue for multi-sentence speaking
    private var sentenceQueue: [String] = []
    private var currentSentenceIndex: Int = 0

    @AppStorage(UserDefaults.Keys.speechVoiceIdentifier) private var voiceIdentifier: String = ""
    @AppStorage(UserDefaults.Keys.speechRate) private var speechRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage(UserDefaults.Keys.speechPitch) private var speechPitch: Double = 1.0
    @AppStorage(UserDefaults.Keys.speechSentencePause) private var sentencePause: Double = 0.0 // Additional pause between sentences in seconds
    @AppStorage(UserDefaults.Keys.audioEffectsEnabled) private var audioEffectsEnabled: Bool = false
    @AppStorage(UserDefaults.Keys.audioEQBass) private var eqBass: Double = 0.0
    @AppStorage(UserDefaults.Keys.audioEQMid) private var eqMid: Double = 0.0
    @AppStorage(UserDefaults.Keys.audioEQTreble) private var eqTreble: Double = 0.0

    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        eqNode = AVAudioUnitEQ(numberOfBands: 3)

        guard let engine = audioEngine, let player = playerNode, let eq = eqNode else { return }

        // Configure EQ bands
        let bands = eq.bands
        if bands.count >= 3 {
            // Bass (60 Hz)
            bands[0].frequency = 60
            bands[0].bandwidth = 1.0
            bands[0].bypass = false
            bands[0].filterType = .parametric

            // Mid (1000 Hz)
            bands[1].frequency = 1000
            bands[1].bandwidth = 1.0
            bands[1].bypass = false
            bands[1].filterType = .parametric

            // Treble (10000 Hz)
            bands[2].frequency = 10000
            bands[2].bandwidth = 1.0
            bands[2].bypass = false
            bands[2].filterType = .parametric
        }

        engine.attach(player)
        engine.attach(eq)
    }

    func speak(text: String, completion: (() -> Void)? = nil) {
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("🔊 Audio session activated for speech")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        self.completionHandler = completion

        // Split text into sentences if sentence pause is enabled
        if sentencePause > 0 {
            speakWithSentencePauses(text: text)
        } else {
            speakSingleUtterance(text: text)
        }
    }

    private func speakSingleUtterance(text: String) {
        let utterance = createUtterance(from: text)
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPaused = false
        }
        synthesizer.speak(utterance)
    }

    private func speakWithSentencePauses(text: String) {
        // Split into sentences (basic splitting on . ! ?)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        print("📝 Split text into \(sentences.count) sentences")

        // Track the sentences and current index
        self.sentenceQueue = sentences
        self.currentSentenceIndex = 0

        // Store the original completion handler
        let originalCompletion = completionHandler

        // Set a new completion handler that continues through sentences
        completionHandler = { [weak self] in
            guard let self = self else { return }

            self.currentSentenceIndex += 1

            if self.currentSentenceIndex < self.sentenceQueue.count {
                // More sentences to speak
                print("📢 Speaking sentence \(self.currentSentenceIndex + 1)/\(self.sentenceQueue.count)")
                let sentence = self.sentenceQueue[self.currentSentenceIndex]
                let utterance = self.createUtterance(from: sentence)

                // Add pause after utterance if not the last sentence
                if self.currentSentenceIndex < self.sentenceQueue.count - 1 {
                    utterance.postUtteranceDelay = self.sentencePause
                }

                self.synthesizer.speak(utterance)
            } else {
                // All sentences spoken, call original completion
                print("✅ All \(self.sentenceQueue.count) sentences completed")
                self.sentenceQueue = []
                self.currentSentenceIndex = 0
                originalCompletion?()
            }
        }

        // Speak the first sentence
        if !sentences.isEmpty {
            print("📢 Speaking sentence 1/\(sentences.count)")
            let utterance = createUtterance(from: sentences[0])
            if sentences.count > 1 {
                utterance.postUtteranceDelay = sentencePause
            }

            DispatchQueue.main.async {
                self.isSpeaking = true
                self.isPaused = false
            }

            synthesizer.speak(utterance)
        }
    }

    private func createUtterance(from text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        // Use selected voice or system default
        if !voiceIdentifier.isEmpty, let selectedVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = selectedVoice
            print("🎤 Using voice: \(selectedVoice.name)")
        } else {
            print("🎤 Using system default voice")
        }

        utterance.rate = Float(speechRate)
        utterance.pitchMultiplier = Float(speechPitch)

        print("🎤 SpeechManager: Speaking '\(text)' at rate \(speechRate)x, pitch \(speechPitch)x, sentence pause: \(sentencePause)s")

        return utterance
    }

    func updateEQSettings() {
        guard let eq = eqNode else { return }
        let bands = eq.bands

        if bands.count >= 3 {
            bands[0].gain = Float(eqBass)
            bands[1].gain = Float(eqMid)
            bands[2].gain = Float(eqTreble)
        }

        print("🎛️ EQ Settings: Bass \(eqBass)dB, Mid \(eqMid)dB, Treble \(eqTreble)dB")
    }

    func pauseSpeaking() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .word)
            DispatchQueue.main.async {
                self.isPaused = true
            }
            print("⏸️ Speech paused")
        }
    }

    func resumeSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            DispatchQueue.main.async {
                self.isPaused = false
            }
            print("▶️ Speech resumed")
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
        }
        completionHandler = nil
        sentenceQueue = []
        currentSentenceIndex = 0
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎤 Speech started")
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("⏸️ Speech paused by system")
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("▶️ Speech resumed by system")
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ Speech finished.")

        // Check if we're in multi-sentence mode
        let isLastSentence = currentSentenceIndex >= sentenceQueue.count - 1 || sentenceQueue.isEmpty

        // Only deactivate audio session after the last sentence
        if isLastSentence {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                print("🔇 Audio session deactivated")
            } catch {
                print("⚠️ Failed to deactivate audio session: \(error)")
            }

            DispatchQueue.main.async {
                self.isSpeaking = false
                self.isPaused = false
            }
        } else {
            print("⏭️ More sentences to speak, keeping audio session active")
        }

        // Call completion handler (which will trigger next sentence if needed)
        DispatchQueue.main.async {
            self.completionHandler?()
            // Only clear completion handler if this was the last sentence
            if isLastSentence {
                self.completionHandler = nil
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("⏹️ Speech cancelled.")

        // Deactivate audio session on cancel too
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }

        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}

// MARK: - Main AI Tab View

struct AITabView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @ObservedObject var speechManager = SpeechManager.shared

    @State private var conversationHistory: [ConversationItem] = []
    @State private var showConversationWindow = false
    @State private var inputText: String = ""
    @State private var selectedActionCategory: CommandCategory?
    @State private var textEditorHeight: CGFloat = 40
    @State private var isTextInputActive: Bool = false

    // AI Pattern Insights
    @State private var aiPatterns: SmartSchedulingService.CalendarPatterns?
    @State private var showPatternInsights = false

    // Auto-loop conversation mode
    @State private var isInAutoLoopMode: Bool = false
    @State private var inactivityTimer: Timer?
    @State private var pulseAnimation: Bool = false

    // Computed property to show either user input or live dictation
    private var displayText: Binding<String> {
        Binding(
            get: {
                if voiceManager.isListening {
                    return voiceManager.currentTranscript
                }
                return inputText
            },
            set: { newValue in
                if !voiceManager.isListening {
                    inputText = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("AI Assistant")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // Conversation Area
            if showConversationWindow {
                ConversationScrollView(conversationHistory: $conversationHistory, onRefresh: clearConversation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        dismissKeyboard()
                    }
            } else {
                // Large empty space for conversation
                VStack {
                    Spacer()
                    Text("Start a conversation")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .onTapGesture {
                    dismissKeyboard()
                }
            }

            // Processing Indicator
            if aiManager.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // AI Pattern Insights Card (only shown when AI Insight button is tapped)
            if selectedActionCategory == .aiInsight, let patterns = aiPatterns {
                PatternConfidenceView(patterns: patterns)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Four Action Buttons (scrollable) - Ordered by most common use
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 🔵 QUERIES - Most common action (time-aware)
                    ActionButton(
                        category: .eventQueries,
                        isSelected: selectedActionCategory == .eventQueries,
                        onTap: { handleActionButtonTap(.eventQueries) }
                    )

                    // 🟢 SCHEDULE - Quick voice scheduling
                    ActionButton(
                        category: .scheduleManagement,
                        isSelected: selectedActionCategory == .scheduleManagement,
                        onTap: { handleActionButtonTap(.scheduleManagement) }
                    )

                    // 🟠 MANAGE - Attention dashboard
                    ActionButton(
                        category: .eventManagement,
                        isSelected: selectedActionCategory == .eventManagement,
                        onTap: { handleActionButtonTap(.eventManagement) }
                    )

                    // 🟣 AI INSIGHT - Show pattern insights
                    ActionButton(
                        category: .aiInsight,
                        isSelected: selectedActionCategory == .aiInsight,
                        onTap: { handleActionButtonTap(.aiInsight) }
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16) // Gap between action buttons and text box

            // Input Area - Unified Pill Shape
            ZStack {
                // Pill-shaped background
                Capsule()
                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground))
                    )
                    .frame(height: max(44, min(textEditorHeight + 8, 120)))

                HStack(spacing: 8) {
                    // Paperclip button (left side)
                    Button(action: {
                        print("📎 Attachment tapped")
                    }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 16)

                    // Auto-expanding text editor
                    ZStack(alignment: .leading) {
                        // Placeholder text
                        if inputText.isEmpty && !voiceManager.isListening {
                            Text("Ask Anything")
                                .font(.system(size: 17))
                                .foregroundColor(Color(.placeholderText))
                        }

                        TextEditor(text: displayText)
                            .font(.system(size: 17))
                            .frame(height: max(36, min(textEditorHeight, 112)))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .onTapGesture {
                                isTextInputActive = true
                            }
                            .onChange(of: displayText.wrappedValue) { newValue in
                                // Calculate text height dynamically
                                let width = UIScreen.main.bounds.width - 160 // Account for icons and padding
                                let font = UIFont.systemFont(ofSize: 17)
                                let attributes = [NSAttributedString.Key.font: font]
                                let size = (newValue as NSString).boundingRect(
                                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                    options: .usesLineFragmentOrigin,
                                    attributes: attributes,
                                    context: nil
                                ).size
                                textEditorHeight = size.height + 8

                                // Set text input active if user is typing
                                if !newValue.isEmpty {
                                    isTextInputActive = true
                                }
                            }
                    }

                    // Speak/Send button (right side)
                    Button(action: handleSpeakButtonTap) {
                        if isTextInputActive && !inputText.isEmpty {
                            // Show arrow icon in circle when typing
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                )
                        } else {
                            // Show speak button with animated states
                            HStack(spacing: 6) {
                                // Icon changes based on state
                                if aiManager.isProcessing {
                                    // Show processing spinner
                                    ProcessingIndicator(color: .white, size: 14)
                                } else if voiceManager.isListening && !isInAutoLoopMode {
                                    // Show send icon when actively listening (not in auto-loop)
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14))
                                } else if speechManager.isSpeaking {
                                    // Show pause/play for speech playback
                                    Image(systemName: speechManager.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 14))
                                } else {
                                    // Show animated waveform when listening, static when idle
                                    AnimatedWaveformIcon(
                                        isAnimating: voiceManager.isListening || isInAutoLoopMode,
                                        color: .white,
                                        size: 14
                                    )
                                }

                                Text(buttonText)
                                    .font(.system(size: 13))
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(buttonColor)
                            )
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20) // Gap from tab bar
        }
        .background(Color(.systemBackground))
        .onAppear {
            print("👂 AI Tab appeared")
            // Don't start always-on listening immediately on first load
            // User will tap Speak button to initiate first interaction

            // Load AI pattern insights
            loadPatternInsights()
        }
        .onDisappear {
            print("👋 AI Tab disappeared - stopping always-on listening")
            stopAlwaysOnListening()
        }
    }

    // MARK: - Button State

    private var buttonText: String {
        if speechManager.isSpeaking {
            return speechManager.isPaused ? "Play" : "Pause"
        }
        if aiManager.conversationState == .awaitingConfirmation {
            return "Answer"
        }
        // In auto-loop mode, always show "Speak" even when listening
        if isInAutoLoopMode {
            return "Speak"
        }
        return voiceManager.isListening ? "Send" : "Speak"
    }

    // Note: Icon logic is now handled inline in the button view with AnimatedWaveformIcon and ProcessingIndicator

    private var buttonColor: Color {
        // Processing state - show blue
        if aiManager.isProcessing {
            return Color.blue
        }
        // In auto-loop mode, keep black color
        if isInAutoLoopMode {
            return Color.black
        }
        // Listening and receiving speech - show red
        if voiceManager.isListening {
            return Color.red
        }
        // Default idle state - black
        return Color.black
    }

    // MARK: - Actions

    private func handleActionButtonTap(_ category: CommandCategory) {
        // Deselect if tapping the same button again - cancel action
        if selectedActionCategory == category {
            withAnimation {
                selectedActionCategory = nil
            }
            return
        }

        withAnimation {
            selectedActionCategory = category
            // Only show conversation window for non-AI Insight actions
            if category != .aiInsight {
                showConversationWindow = true
            }
        }

        switch category {
        case .eventQueries:
            // Automatically send time-aware query
            handleTranscript(category.autoQuery)

        case .scheduleManagement:
            // Speak the prompt and activate voice input in continuous mode
            SpeechManager.shared.speak(text: category.autoQuery) {
                // After speaking prompt, start listening in continuous mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isInAutoLoopMode = true
                    self.startListeningWithAutoLoop()
                }
            }

        case .eventManagement:
            // Send attention query with analysis
            handleTranscript(category.autoQuery)

        case .aiInsight:
            // Just show the AI insights card - no query or conversation needed
            // The card will appear because selectedActionCategory == .aiInsight
            // Don't clear selection automatically - let user dismiss by tapping again
            return
        }

        // Clear selection after a delay (except for AI Insight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                self.selectedActionCategory = nil
            }
        }
    }

    private func handleTextInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        withAnimation {
            showConversationWindow = true
        }
        handleTranscript(text)
    }

    private func handleSpeakButtonTap() {
        // Handle text input send
        if isTextInputActive && !inputText.isEmpty {
            handleTextInput()
            isTextInputActive = false
            return
        }

        // Handle speech control (pause/play)
        if speechManager.isSpeaking {
            if speechManager.isPaused {
                speechManager.resumeSpeaking()
            } else {
                // Pause button exits auto-loop mode
                speechManager.pauseSpeaking()
                exitAutoLoopMode()
            }
            return
        }

        // Handle voice input (speak/send)
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            // Enter auto-loop mode when speak button is pressed
            isInAutoLoopMode = true
            withAnimation {
                showConversationWindow = true
            }
            startListeningWithAutoLoop()
        }
    }

    private func handleTranscript(_ transcript: String) {
        // Check if this is a new topic when user restarts conversation after inactivity
        if !isInAutoLoopMode && conversationHistory.count > 0 {
            // User manually pressed speak button after auto-loop ended
            // AI will determine if this is a continuation or new topic
            checkAndClearHistoryIfNeeded(transcript: transcript) { shouldClearHistory in
                if shouldClearHistory {
                    print("🆕 New topic detected - clearing conversation history")
                    self.conversationHistory.removeAll()
                }
                self.processTranscript(transcript)
            }
        } else {
            // During auto-loop or first message, just process normally
            processTranscript(transcript)
        }
    }

    private func processTranscript(_ transcript: String) {
        if aiManager.conversationState != .awaitingConfirmation {
            let userMessage = ConversationItem(message: transcript, isUser: true)
            conversationHistory.append(userMessage)
        }

        // Use enhanced conversational AI with memory (OpenAI backend)
        aiManager.processConversationalCommand(transcript, calendarEvents: calendarManager.unifiedEvents) { response in
            self.handleAIResponse(response)
        }
    }

    private func checkAndClearHistoryIfNeeded(transcript: String, completion: @escaping (Bool) -> Void) {
        // Use AI to determine if this is a new topic or continuation
        guard let lastMessage = conversationHistory.last?.message else {
            completion(false)
            return
        }

        // Simple heuristic for now: check if the new query is completely different
        let continuationKeywords = ["also", "and", "additionally", "what about", "how about", "more", "another", "continue", "tell me more", "what else"]
        let lowerTranscript = transcript.lowercased()

        // If user uses continuation keywords, keep history
        if continuationKeywords.contains(where: { lowerTranscript.contains($0) }) {
            completion(false)
            return
        }

        // If the topics are completely different (no shared keywords), clear history
        let previousWords = Set(lastMessage.lowercased().components(separatedBy: .whitespaces))
        let currentWords = Set(lowerTranscript.components(separatedBy: .whitespaces))
        let commonWords = previousWords.intersection(currentWords).filter { $0.count > 3 } // Ignore short words

        // If less than 2 common words, likely a new topic
        completion(commonWords.count < 2)
    }

    private func handleAIResponse(_ response: AICalendarResponse) {
        if Config.aiOutputMode != .voiceOnly {
            let aiMessage = ConversationItem(message: response.message, isUser: false, eventResults: response.eventResults)
            conversationHistory.append(aiMessage)
        }
        if Config.aiOutputMode != .textOnly {
            // Only speak if user is not currently speaking (in continuous mode)
            // The continuous mode will automatically interrupt if user starts speaking mid-response
            SpeechManager.shared.speak(text: response.message) {
                // After AI finishes speaking, restart listening if in auto-loop mode
                if self.isInAutoLoopMode {
                    print("🔄 Auto-loop: AI finished speaking, restarting listening")
                    // Small delay to ensure speech has fully completed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.isInAutoLoopMode && !self.voiceManager.isListening {
                            self.startListeningWithAutoLoop()
                        }
                    }
                }
            }
        } else {
            // If voice output is disabled, restart listening immediately
            if self.isInAutoLoopMode && !self.voiceManager.isListening {
                print("🔄 Auto-loop: No voice output, restarting listening immediately")
                self.startListeningWithAutoLoop()
            }
        }
        if let command = response.command {
            calendarManager.handleAICalendarResponse(AICalendarResponse(message: "", command: command))
        }
    }

    private func dismissConversation() {
        withAnimation { showConversationWindow = false }
        aiManager.resetConversationState()
    }

    private func clearConversation() {
        withAnimation {
            conversationHistory.removeAll()
            showConversationWindow = false
        }

        // Stop any ongoing speech
        SpeechManager.shared.stopSpeaking()

        // Exit auto-loop mode if active
        if isInAutoLoopMode {
            exitAutoLoopMode()
            voiceManager.stopListening()
        }

        // Reset AI state
        aiManager.resetConversationState()

        print("🗑️ Conversation cleared")
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isTextInputActive = false
    }

    // MARK: - Auto-Loop Mode Functions

    private func startListeningWithAutoLoop() {
        // Cancel any existing inactivity timer
        inactivityTimer?.invalidate()
        inactivityTimer = nil

        // Start pulse animation
        withAnimation {
            pulseAnimation = true
        }

        // Start listening in CONTINUOUS mode with speech detection
        voiceManager.startListening(
            continuous: true,
            onPartialTranscript: { partialTranscript in
                // User is speaking - reset the inactivity timer
                self.resetInactivityTimer()
            },
            onSpeechDetected: {
                // User started speaking - interrupt AI if it's speaking
                print("🛑 User started speaking - interrupting AI output")
                SpeechManager.shared.stopSpeaking()
                // Reset timer when user starts speaking
                self.resetInactivityTimer()
            },
            completion: { finalTranscript in
                if !finalTranscript.isEmpty {
                    // Cancel inactivity timer when transcript is final
                    self.inactivityTimer?.invalidate()
                    self.handleTranscript(finalTranscript)
                }
            }
        )

        // Start initial inactivity timer
        resetInactivityTimer()
    }

    private func resetInactivityTimer() {
        // Cancel existing timer
        inactivityTimer?.invalidate()

        // Start new 8-second timer
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            if self.voiceManager.isListening {
                print("⏱️ 8-second inactivity timeout - ending auto-loop (keeping history)")
                self.voiceManager.stopListening()
                self.exitAutoLoopMode()
            }
        }
    }

    private func exitAutoLoopMode() {
        print("🚪 Exiting auto-loop mode")
        isInAutoLoopMode = false
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        withAnimation {
            pulseAnimation = false
        }
        // Note: We keep conversation history as per requirements
    }

    // MARK: - Always-On Listening

    private func startAlwaysOnListening() {
        // Don't start if already listening or in auto-loop mode
        if voiceManager.isListening || isInAutoLoopMode {
            return
        }

        print("🎤 Starting always-on listening mode")

        // Start continuous listening with speech detection
        voiceManager.startListening(
            continuous: true,
            onSpeechDetected: {
                // User started speaking - show conversation window and interrupt AI if needed
                print("👂 Speech detected in always-on mode")
                DispatchQueue.main.async {
                    withAnimation {
                        self.showConversationWindow = true
                    }
                }
                if SpeechManager.shared.isSpeaking {
                    SpeechManager.shared.stopSpeaking()
                }
            },
            completion: { finalTranscript in
                if !finalTranscript.isEmpty {
                    print("📝 Always-on mode captured: \(finalTranscript)")
                    self.handleTranscript(finalTranscript)

                    // Restart always-on listening after processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !self.isInAutoLoopMode {
                            self.startAlwaysOnListening()
                        }
                    }
                } else {
                    // No speech detected, restart listening
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !self.isInAutoLoopMode {
                            self.startAlwaysOnListening()
                        }
                    }
                }
            }
        )
    }

    private func stopAlwaysOnListening() {
        print("🔇 Stopping always-on listening mode")
        if voiceManager.isListening && !isInAutoLoopMode {
            voiceManager.stopListening()
        }
    }

    // MARK: - Pattern Insights

    private func loadPatternInsights() {
        // Get all calendar events
        let allEvents = calendarManager.unifiedEvents
        print("📊 Loading AI patterns from \(allEvents.count) calendar events")

        // Analyze patterns using SmartSchedulingService
        let schedulingService = SmartSchedulingService()
        let patterns = schedulingService.analyzeCalendarPatterns(events: allEvents)

        // Always set patterns and show - even with no confidence, it will show helpful message
        aiPatterns = patterns
        showPatternInsights = true

        print("🧠 Loaded AI pattern insights: \(patterns.confidence) confidence with \(patterns.eventCount) events")
    }
}



// MARK: - UI Components

private struct ActionButton: View {
    let category: CommandCategory
    let isSelected: Bool
    let onTap: () -> Void

    // Color coding for buttons
    private var buttonColor: Color {
        switch category {
        case .eventQueries: return .blue
        case .scheduleManagement: return .green
        case .eventManagement: return .orange
        case .aiInsight: return .purple
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : buttonColor)

                Text(category.displayText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? buttonColor : Color(.systemGray6))
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ConversationScrollView: View {
    @Binding var conversationHistory: [ConversationItem]
    var onRefresh: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversationHistory) { item in
                        ConversationBubble(item: item)
                    }
                }
                .padding()
                .onChange(of: conversationHistory.count) { _ in
                    if let lastItem = conversationHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastItem.id, anchor: .bottom)
                        }
                    }
                }
            }
            .refreshable {
                onRefresh()
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct CommandCardListView: View {
    var onCommandSelected: (String) -> Void
    var body: some View {
        ScrollView {
            VStack {
                Text("AI Assistant").font(.largeTitle).bold().padding(.top)
                Text("Try an example:").font(.headline).padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(CommandCategory.allCases, id: \.self) { category in
                        CommandCategoryCard(category: category, onCommandSelected: onCommandSelected)
                    }
                }.padding()
            }
        }
    }
}

private enum CommandCategory: String, CaseIterable {
    case eventQueries = "Queries"
    case scheduleManagement = "Schedule"
    case eventManagement = "Manage"
    case aiInsight = "AI Insight"

    var icon: String {
        switch self {
        case .eventManagement: return "exclamationmark.triangle.fill"
        case .eventQueries: return "calendar.badge.clock"
        case .scheduleManagement: return "calendar.badge.plus"
        case .aiInsight: return "brain.head.profile"
        }
    }

    var displayText: String {
        switch self {
        case .eventQueries:
            // Time-aware query text
            let hour = Calendar.current.component(.hour, from: Date())
            if hour < 10 {
                return "Today"
            } else if hour < 18 {
                return "What's Next"
            } else {
                return "Tomorrow"
            }
        case .scheduleManagement:
            return "Schedule"
        case .eventManagement:
            return "Manage"
        case .aiInsight:
            return "AI Insight"
        }
    }

    var autoQuery: String {
        switch self {
        case .eventQueries:
            let hour = Calendar.current.component(.hour, from: Date())
            if hour < 10 {
                return "What's my schedule today?"
            } else if hour < 18 {
                return "What's next?"
            } else {
                return "What's tomorrow?"
            }
        case .scheduleManagement:
            return "What would you like to schedule?"
        case .eventManagement:
            return "What needs my attention?"
        case .aiInsight:
            return "" // No query - just shows UI
        }
    }

    var commands: [String] {
        switch self {
        case .eventManagement: return ["Schedule lunch with John tomorrow at 1pm", "Delete my 3pm meeting"]
        case .eventQueries: return ["What does my afternoon look like?", "Am I free at 4pm?"]
        case .scheduleManagement: return ["Find a time for a 30 minute meeting next week", "Clear my schedule on Friday afternoon"]
        case .aiInsight: return [] // No commands - shows insights card
        }
    }
}

private struct CommandCategoryCard: View {
    let category: CommandCategory
    let onCommandSelected: (String) -> Void
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: category.icon).foregroundColor(.blue).font(.headline)
                Text(category.rawValue).font(.headline)
                Spacer()
                Image(systemName: "chevron.down").font(.caption).rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .onTapGesture { withAnimation { isExpanded.toggle() } }
            
            if isExpanded {
                ForEach(category.commands, id: \.self) { command in
                    CommandItem(text: command, onSelect: onCommandSelected)
                }
            }
        }.padding(.bottom, 10)
    }
}

private struct CommandItem: View {
    let text: String
    let onSelect: (String) -> Void
    var body: some View {
        Button(action: { onSelect(text) }) {
            HStack {
                Text(text).font(.subheadline).foregroundColor(.primary).lineLimit(1)
                Spacer()
                Image(systemName: "play.circle").foregroundColor(.blue).opacity(0.7)
            }.padding()
        }.background(Color(.systemGray6).opacity(0.5)).cornerRadius(8)
    }
}

private struct ConversationWindow: View {
    @Binding var conversationHistory: [ConversationItem]
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    // Cancel any ongoing speech
                    SpeechManager.shared.stopSpeaking()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .padding(8)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }.padding()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversationHistory) { item in ConversationBubble(item: item) }
                    }.padding()
                    .onChange(of: conversationHistory.count) { value in // Compatible with older iOS
                        if let lastItem = conversationHistory.last {
                            withAnimation { proxy.scrollTo(lastItem.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(.thickMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

private struct ConversationBubble: View {
    let item: ConversationItem
    @AppStorage(UserDefaults.Keys.queryDisplayMode) private var queryDisplayMode: QueryDisplayMode = .both

    var body: some View {
        VStack(alignment: item.isUser ? .trailing : .leading, spacing: 8) {
            // Show message based on display mode
            if item.isUser || queryDisplayMode == .summaryOnly || queryDisplayMode == .both {
                HStack {
                    if item.isUser { Spacer() }
                    Text(item.message)
                        .padding(12)
                        .foregroundColor(item.isUser ? .white : .primary)
                        .background(item.isUser ? .blue : Color(.systemGray5))
                        .cornerRadius(16)
                    if !item.isUser { Spacer() }
                }
            }

            // Show event cards if we have events and mode allows it
            if !item.isUser,
               let eventResults = item.eventResults,
               !eventResults.isEmpty,
               (queryDisplayMode == .eventsOnly || queryDisplayMode == .both) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(eventResults) { event in
                        EventResultCard(event: event)
                    }
                }
                .padding(.horizontal, item.isUser ? 0 : 12)
            }
        }
    }
}

private struct EventResultCard: View {
    let event: EventResult

    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(from: event.startDate))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                if let duration = durationString(from: event.startDate, to: event.endDate) {
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, alignment: .leading)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Source indicator
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon(for: event.source))
                        .font(.caption2)
                    Text(event.source)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func durationString(from start: Date, to end: Date) -> String? {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return nil
    }

    private func sourceIcon(for source: String) -> String {
        switch source.lowercased() {
        case "ios": return "calendar"
        case "google": return "g.circle.fill"
        case "outlook": return "envelope.circle.fill"
        default: return "calendar"
        }
    }
}

private struct PersistentVoiceFooter: View {
    @ObservedObject var aiManager: AIManager
    @StateObject private var voiceManager = VoiceManager()
    @ObservedObject var speechManager = SpeechManager.shared
    var onTranscript: (String) -> Void
    var onStartListening: () -> Void

    private var buttonText: String {
        // Priority order: Speaking states > Listening states > Default
        if speechManager.isSpeaking {
            return speechManager.isPaused ? "Play" : "Pause"
        }
        if aiManager.conversationState == .awaitingConfirmation {
            return "Tap to Answer"
        }
        return voiceManager.isListening ? "Send" : "Speak"
    }

    private var buttonIcon: String? {
        // Show icon only when not listening and not speaking
        if speechManager.isSpeaking {
            return speechManager.isPaused ? "play.fill" : "pause.fill"
        }
        if voiceManager.isListening {
            return nil // No icon when showing "Send"
        }
        return "waveform" // Icon for "Speak"
    }

    private var buttonColor: Color {
        // Red only when listening (Send button), black for all other states
        if voiceManager.isListening {
            return Color.red
        }
        return Color.black
    }

    var body: some View {
        VStack {
            if voiceManager.isListening {
                HStack {
                    Spacer()
                    Text(voiceManager.currentTranscript)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.trailing, 20)
                }
            }

            HStack {
                Spacer()
                Button(action: handleButtonTap) {
                    HStack(spacing: 6) {
                        if let icon = buttonIcon {
                            Image(systemName: icon)
                                .font(.caption2)
                        }

                        Text(buttonText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(buttonColor)
                    )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func handleButtonTap() {
        // Handle speech control (pause/play)
        if speechManager.isSpeaking {
            if speechManager.isPaused {
                speechManager.resumeSpeaking()
            } else {
                speechManager.pauseSpeaking()
            }
            return
        }

        // Handle voice input (speak/send)
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            onStartListening()
            voiceManager.startListening { finalTranscript in
                if !finalTranscript.isEmpty { onTranscript(finalTranscript) }
            }
        }
    }
}
