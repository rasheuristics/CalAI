import Foundation

/// Manages multi-turn conversation sessions for natural AI interactions
class ConversationSessionManager: ObservableObject {
    static let shared = ConversationSessionManager()

    // MARK: - Session State

    /// Current active conversation session
    @Published var currentSession: ConversationSession?

    /// Maximum number of turns to keep in context
    private let maxContextTurns = 5

    /// Session timeout duration (15 minutes of inactivity)
    private let sessionTimeout: TimeInterval = 15 * 60

    private init() {}

    // MARK: - Session Management

    /// Start a new conversation session
    func startNewSession() {
        currentSession = ConversationSession()
        print("🆕 Started new conversation session: \(currentSession?.id.uuidString.prefix(8) ?? "")")
    }

    /// Add a turn to the current session
    func addTurn(userMessage: String, assistantMessage: String, context: TurnContext? = nil) {
        guard let session = currentSession else {
            startNewSession()
            addTurn(userMessage: userMessage, assistantMessage: assistantMessage, context: context)
            return
        }

        // Check if session has timed out
        if shouldResetSession() {
            print("⏰ Session timed out, starting new session")
            startNewSession()
            addTurn(userMessage: userMessage, assistantMessage: assistantMessage, context: context)
            return
        }

        let turn = ConversationTurn(
            userMessage: userMessage,
            assistantMessage: assistantMessage,
            timestamp: Date(),
            context: context
        )

        currentSession?.turns.append(turn)
        currentSession?.lastActivity = Date()

        // Trim old turns if exceeded max
        if let session = currentSession, session.turns.count > maxContextTurns {
            currentSession?.turns = Array(session.turns.suffix(maxContextTurns))
        }

        print("💬 Added turn to session. Total turns: \(currentSession?.turns.count ?? 0)")
    }

    /// Get conversation history for context
    func getConversationHistory() -> [ConversationTurn] {
        guard let session = currentSession, !shouldResetSession() else {
            return []
        }
        return session.turns
    }

    /// Get the last mentioned event/context from conversation
    func getLastContext() -> TurnContext? {
        return currentSession?.turns.last?.context
    }

    /// Clear the current session
    func clearSession() {
        print("🗑️ Clearing conversation session")
        currentSession = nil
    }

    /// Check if session should be reset due to inactivity
    private func shouldResetSession() -> Bool {
        guard let session = currentSession else { return true }
        let timeSinceLastActivity = Date().timeIntervalSince(session.lastActivity)
        return timeSinceLastActivity > sessionTimeout
    }

    /// Update context for the current turn
    func updateCurrentContext(_ context: TurnContext) {
        guard currentSession != nil else { return }
        if var lastTurn = currentSession?.turns.last {
            lastTurn.context = context
            currentSession?.turns[currentSession!.turns.count - 1] = lastTurn
        }
    }
}

// MARK: - Data Models

/// Represents a single conversation session
struct ConversationSession {
    let id: UUID
    var turns: [ConversationTurn]
    var startTime: Date
    var lastActivity: Date

    init() {
        self.id = UUID()
        self.turns = []
        self.startTime = Date()
        self.lastActivity = Date()
    }
}

/// Represents a single turn in a conversation
struct ConversationTurn: Codable {
    let userMessage: String
    let assistantMessage: String
    let timestamp: Date
    var context: TurnContext?

    /// Format for prompt context
    var formattedForPrompt: String {
        return """
        User: \(userMessage)
        Assistant: \(assistantMessage)
        """
    }
}

/// Context information for a conversation turn
struct TurnContext: Codable {
    var lastMentionedEventId: String?
    var lastMentionedEventTitle: String?
    var lastMentionedDate: String?
    var lastMentionedTime: String?
    var lastMentionedPerson: String?
    var lastMentionedLocation: String?
    var lastIntent: String?
    var pendingAction: String?

    /// Check if context has meaningful information
    var hasContent: Bool {
        return lastMentionedEventId != nil ||
               lastMentionedEventTitle != nil ||
               lastMentionedDate != nil ||
               lastMentionedTime != nil ||
               lastMentionedPerson != nil ||
               lastMentionedLocation != nil
    }

    /// Format context for prompt
    var formattedForPrompt: String {
        var lines: [String] = []

        if let eventId = lastMentionedEventId, let eventTitle = lastMentionedEventTitle {
            lines.append("Last mentioned event: '\(eventTitle)' (ID: \(eventId))")
        }
        if let date = lastMentionedDate {
            lines.append("Last mentioned date: \(date)")
        }
        if let time = lastMentionedTime {
            lines.append("Last mentioned time: \(time)")
        }
        if let person = lastMentionedPerson {
            lines.append("Last mentioned person: \(person)")
        }
        if let location = lastMentionedLocation {
            lines.append("Last mentioned location: \(location)")
        }
        if let action = pendingAction {
            lines.append("Pending action: \(action)")
        }

        return lines.isEmpty ? "No previous context" : lines.joined(separator: "\n")
    }
}
