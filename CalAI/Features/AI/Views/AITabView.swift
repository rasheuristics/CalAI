import SwiftUI
import EventKit
import AVFoundation

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

        var currentIndex = 0

        func speakNextSentence() {
            guard currentIndex < sentences.count else {
                // All sentences spoken
                DispatchQueue.main.async {
                    self.completionHandler?()
                    self.completionHandler = nil
                }
                return
            }

            let sentence = sentences[currentIndex]
            currentIndex += 1

            let utterance = createUtterance(from: sentence)

            // Add pause after utterance if not the last sentence
            if currentIndex < sentences.count {
                utterance.postUtteranceDelay = sentencePause
            }

            // Update speaking state for first sentence
            if currentIndex == 1 {
                DispatchQueue.main.async {
                    self.isSpeaking = true
                    self.isPaused = false
                }
            }

            synthesizer.speak(utterance)
        }

        // Override completion to speak next sentence
        let originalCompletion = completionHandler
        completionHandler = {
            if currentIndex < sentences.count {
                speakNextSentence()
            } else {
                originalCompletion?()
            }
        }

        speakNextSentence()
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

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Audio session deactivated")
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
                ConversationScrollView(conversationHistory: $conversationHistory)
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

            // Three Action Buttons (scrollable) - Ordered by most common use
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
                            // Show regular speak button
                            HStack(spacing: 4) {
                                if let icon = buttonIcon {
                                    Image(systemName: icon)
                                        .font(.system(size: 14))
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
    }

    // MARK: - Button State

    private var buttonText: String {
        if speechManager.isSpeaking {
            return speechManager.isPaused ? "Play" : "Pause"
        }
        if aiManager.conversationState == .awaitingConfirmation {
            return "Answer"
        }
        return voiceManager.isListening ? "Send" : "Speak"
    }

    private var buttonIcon: String? {
        if speechManager.isSpeaking {
            return speechManager.isPaused ? "play.fill" : "pause.fill"
        }
        if voiceManager.isListening {
            return "paperplane.fill"
        }
        return "waveform"
    }

    private var buttonColor: Color {
        if voiceManager.isListening {
            return Color.red
        }
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
            showConversationWindow = true
        }

        switch category {
        case .eventQueries:
            // Automatically send time-aware query
            handleTranscript(category.autoQuery)

        case .scheduleManagement:
            // Speak the prompt and activate voice input
            SpeechManager.shared.speak(text: category.autoQuery) {
                // After speaking prompt, start listening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.voiceManager.startListening { finalTranscript in
                        if !finalTranscript.isEmpty {
                            self.handleTranscript(finalTranscript)
                        }
                    }
                }
            }

        case .eventManagement:
            // Send attention query with analysis
            handleTranscript(category.autoQuery)
        }

        // Clear selection after a delay
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
                speechManager.pauseSpeaking()
            }
            return
        }

        // Handle voice input (speak/send)
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            withAnimation {
                showConversationWindow = true
            }
            voiceManager.startListening { finalTranscript in
                if !finalTranscript.isEmpty {
                    handleTranscript(finalTranscript)
                }
            }
        }
    }

    private func handleTranscript(_ transcript: String) {
        if aiManager.conversationState != .awaitingConfirmation {
            let userMessage = ConversationItem(message: transcript, isUser: true)
            conversationHistory.append(userMessage)
        }
        aiManager.processVoiceCommand(transcript, conversationHistory: conversationHistory, calendarEvents: calendarManager.unifiedEvents) { response in
            handleAIResponse(response)
        }
    }

    private func handleAIResponse(_ response: AICalendarResponse) {
        if Config.aiOutputMode != .voiceOnly {
            let aiMessage = ConversationItem(message: response.message, isUser: false, eventResults: response.eventResults)
            conversationHistory.append(aiMessage)
        }
        if Config.aiOutputMode != .textOnly {
            let shouldContinue = response.shouldContinueListening

            // Speak with completion handler to auto-restart listening if needed
            SpeechManager.shared.speak(text: response.message) {
                // If response contains a follow-up question, automatically restart listening
                if shouldContinue && !self.voiceManager.isListening {
                    print("🎤 Auto-restarting listening for follow-up question")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.voiceManager.startListening { finalTranscript in
                            if !finalTranscript.isEmpty {
                                self.handleTranscript(finalTranscript)
                            }
                        }
                    }
                }
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

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isTextInputActive = false
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

    var icon: String {
        switch self {
        case .eventManagement: return "exclamationmark.triangle.fill"
        case .eventQueries: return "calendar.badge.clock"
        case .scheduleManagement: return "calendar.badge.plus"
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
        }
    }

    var commands: [String] {
        switch self {
        case .eventManagement: return ["Schedule lunch with John tomorrow at 1pm", "Delete my 3pm meeting"]
        case .eventQueries: return ["What does my afternoon look like?", "Am I free at 4pm?"]
        case .scheduleManagement: return ["Find a time for a 30 minute meeting next week", "Clear my schedule on Friday afternoon"]
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
