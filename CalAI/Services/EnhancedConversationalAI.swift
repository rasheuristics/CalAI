import Foundation

/// Enhanced conversational AI wrapper that adds multi-turn memory and context tracking
/// Works as a layer on top of any AI provider (on-device, OpenAI, Anthropic)
class EnhancedConversationalAI {

    // MARK: - Types

    struct ConversationTurn: Codable {
        let id: UUID
        let timestamp: Date
        let userMessage: String
        let assistantResponse: String
        let intent: String?
        let entities: [String: String]

        init(id: UUID = UUID(), timestamp: Date = Date(), userMessage: String, assistantResponse: String, intent: String? = nil, entities: [String: String] = [:]) {
            self.id = id
            self.timestamp = timestamp
            self.userMessage = userMessage
            self.assistantResponse = assistantResponse
            self.intent = intent
            self.entities = entities
        }
    }

    struct EnhancedResponse {
        let message: String
        let intent: String
        let confidence: Float
        let requiresClarification: Bool
        let clarificationQuestions: [String]?
        let contextToRemember: [String: String]?
        let suggestedFollowUps: [String]?
    }

    // MARK: - Properties

    private var conversationHistory: [ConversationTurn] = []
    private let maxHistoryLength = 10
    private var currentContext: [String: String] = [:]

    // Reference to the underlying AI service (will be injected)
    private var aiService: ConversationalAIService

    // MARK: - Initialization

    init(aiService: ConversationalAIService) {
        self.aiService = aiService
        print("✅ Enhanced Conversational AI initialized with multi-turn memory")
    }

    // MARK: - Main Interface

    func processWithMemory(
        message: String,
        calendarEvents: [UnifiedEvent]
    ) async throws -> ConversationalAIService.AIAction {

        print("💬 Enhanced AI processing: \(message)")
        print("📚 Conversation history: \(conversationHistory.count) turns")

        // Build enhanced prompt with conversation context
        let enhancedMessage = buildEnhancedPrompt(message: message)

        // Call underlying AI service
        let action = try await aiService.processCommand(enhancedMessage, calendarEvents: calendarEvents)

        // Store conversation turn
        let turn = ConversationTurn(
            userMessage: message,
            assistantResponse: action.message,
            intent: action.intent,
            entities: extractEntities(from: action.parameters)
        )
        conversationHistory.append(turn)

        // Update context if needed
        updateContext(from: action)

        // Trim history if needed
        trimConversationHistory()

        print("✅ Enhanced AI completed: \(action.intent)")

        return action
    }

    // MARK: - Context Building

    private func buildEnhancedPrompt(message: String) -> String {
        guard !conversationHistory.isEmpty else {
            return message
        }

        // Build conversation context from recent history
        let recentTurns = conversationHistory.suffix(3)
        var contextLines: [String] = []

        contextLines.append("CONVERSATION CONTEXT:")
        for (index, turn) in recentTurns.enumerated() {
            contextLines.append("[\(index + 1)] User: \(turn.userMessage)")
            contextLines.append("[\(index + 1)] Assistant: \(turn.assistantResponse)")
        }

        // Add active context
        if !currentContext.isEmpty {
            contextLines.append("\nACTIVE CONTEXT:")
            for (key, value) in currentContext {
                contextLines.append("- \(key): \(value)")
            }
        }

        contextLines.append("\nCURRENT REQUEST:")
        contextLines.append(message)

        return contextLines.joined(separator: "\n")
    }

    private func extractEntities(from parameters: [String: ConversationalAIService.AnyCodableValue]) -> [String: String] {
        var entities: [String: String] = [:]

        for (key, value) in parameters {
            switch value {
            case .string(let str):
                entities[key] = str
            case .int(let int):
                entities[key] = "\(int)"
            case .double(let double):
                entities[key] = "\(double)"
            case .bool(let bool):
                entities[key] = "\(bool)"
            case .date(let date):
                entities[key] = ISO8601DateFormatter().string(from: date)
            default:
                break
            }
        }

        return entities
    }

    private func updateContext(from action: ConversationalAIService.AIAction) {
        // Extract important context from the action
        if let title = action.parameters["title"], case .string(let titleStr) = title {
            currentContext["lastMentionedEvent"] = titleStr
        }

        if let date = action.parameters["startDate"], case .string(let dateStr) = date {
            currentContext["lastMentionedDate"] = dateStr
        }

        // Store intent for context
        currentContext["lastIntent"] = action.intent
    }

    // MARK: - History Management

    private func trimConversationHistory() {
        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
            print("📚 Trimmed conversation history to \(maxHistoryLength) turns")
        }
    }

    func clearHistory() {
        conversationHistory.removeAll()
        currentContext.removeAll()
        print("🗑️ Conversation history cleared")
    }

    func getConversationSummary() -> String {
        guard !conversationHistory.isEmpty else {
            return "No conversation history"
        }

        let recentIntents = conversationHistory
            .suffix(5)
            .compactMap { $0.intent }

        return """
        Conversation with \(conversationHistory.count) turns
        Recent topics: \(recentIntents.joined(separator: ", "))
        Active context: \(currentContext.keys.joined(separator: ", "))
        """
    }

    // MARK: - Context Helpers

    func addContext(key: String, value: String) {
        currentContext[key] = value
    }

    func removeContext(key: String) {
        currentContext.removeValue(forKey: key)
    }

    func getContext(key: String) -> String? {
        return currentContext[key]
    }
}
