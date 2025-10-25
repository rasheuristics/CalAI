import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Enhanced conversational AI service with multi-turn conversation memory
/// Uses Apple Intelligence on iOS 26+, falls back to OpenAI on older devices
@available(iOS 16.0, *)
class EnhancedConversationalAI {

    // MARK: - Types

    struct ConversationTurn: Codable {
        let id: UUID
        let timestamp: Date
        let userMessage: String
        let assistantResponse: String
        let intent: String?
        let entities: [Entity]

        init(id: UUID = UUID(), timestamp: Date = Date(), userMessage: String, assistantResponse: String, intent: String? = nil, entities: [Entity] = []) {
            self.id = id
            self.timestamp = timestamp
            self.userMessage = userMessage
            self.assistantResponse = assistantResponse
            self.intent = intent
            self.entities = entities
        }
    }

    struct Entity: Codable {
        enum EntityType: String, Codable {
            case person
            case date
            case time
            case location
            case event
            case task
            case duration
            case priority
        }

        let type: EntityType
        let value: String
        let confidence: Float

        init(type: EntityType, value: String, confidence: Float = 1.0) {
            self.type = type
            self.value = value
            self.confidence = confidence
        }
    }

    // Conditional struct definition based on FoundationModels availability
    #if canImport(FoundationModels)
    @Generable
    #endif
    struct ConversationalResponse: Codable {
        enum Intent: String, Codable {
            case createEvent
            case modifyEvent
            case deleteEvent
            case createTask
            case modifyTask
            case deleteTask
            case completeTask
            case querySchedule
            case requestAdvice
            case smallTalk
            case clarification
            case multiStepPlanning
            case scheduleOptimization
            case unknown
        }

        let message: String
        let intent: String
        let confidence: Float
        let requiresClarification: Bool
        let clarificationQuestions: [String]?
        let actionType: String?
        let actionParameters: [String: String]?
        let contextToRemember: [String: String]?
        let suggestedFollowUps: [String]?

        init(
            message: String,
            intent: String = "unknown",
            confidence: Float = 0.5,
            requiresClarification: Bool = false,
            clarificationQuestions: [String]? = nil,
            actionType: String? = nil,
            actionParameters: [String: String]? = nil,
            contextToRemember: [String: String]? = nil,
            suggestedFollowUps: [String]? = nil
        ) {
            self.message = message
            self.intent = intent
            self.confidence = confidence
            self.requiresClarification = requiresClarification
            self.clarificationQuestions = clarificationQuestions
            self.actionType = actionType
            self.actionParameters = actionParameters
            self.contextToRemember = contextToRemember
            self.suggestedFollowUps = suggestedFollowUps
        }
    }

    // MARK: - Properties

    private var conversationHistory: [ConversationTurn] = []
    #if canImport(FoundationModels)
    private var appleSession: LanguageModelSession?  // For iOS 26+
    #endif
    private let urlSession: URLSession
    private let maxHistoryLength = 10  // Keep last 10 turns
    private var currentContext: [String: String] = [:]
    private var useAppleIntelligence: Bool = false

    // MARK: - Initialization

    init() {
        self.urlSession = URLSession.shared

        // Try to initialize Apple Intelligence session
        if #available(iOS 26.0, *) {
            Task {
                await initializeAppleIntelligence()
            }
        } else {
            print("✅ Enhanced Conversational AI initialized with OpenAI fallback (iOS 26+ required for Apple Intelligence)")
        }
    }

    @available(iOS 26.0, *)
    private func initializeAppleIntelligence() async {
        #if canImport(FoundationModels)
        do {
            let session = try await LanguageModelSession()
            self.appleSession = session
            self.useAppleIntelligence = true
            print("✅ Enhanced Conversational AI initialized with Apple Intelligence")
        } catch {
            print("⚠️ Failed to initialize Apple Intelligence: \(error)")
            print("✅ Falling back to OpenAI backend")
            self.useAppleIntelligence = false
        }
        #else
        print("⚠️ FoundationModels not available - using OpenAI backend")
        self.useAppleIntelligence = false
        #endif
    }

    // MARK: - Main Conversation Interface

    func chat(
        message: String,
        calendarEvents: [UnifiedEvent],
        tasks: [EventTask]
    ) async throws -> ConversationalResponse {

        print("💬 Processing message: \(message)")
        print("📚 Conversation history: \(conversationHistory.count) turns")

        // Build comprehensive context
        let contextPrompt = buildContextPrompt(
            message: message,
            events: calendarEvents,
            tasks: tasks
        )

        print("📝 Context prompt built")

        // Generate response using Apple Intelligence or OpenAI fallback
        let response: ConversationalResponse

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), useAppleIntelligence, let session = appleSession {
            print("🍎 Using Apple Intelligence (on-device)")
            response = try await session.generate(contextPrompt, as: ConversationalResponse.self)
        } else {
            print("☁️ Using OpenAI fallback")
            response = try await callOpenAI(systemPrompt: contextPrompt, userMessage: message)
        }
        #else
        print("☁️ Using OpenAI (FoundationModels not available)")
        response = try await callOpenAI(systemPrompt: contextPrompt, userMessage: message)
        #endif

        print("✅ Response generated: \(response.intent)")

        // Extract entities from the conversation
        let entities = extractEntities(from: message, response: response)

        // Store conversation turn
        let turn = ConversationTurn(
            userMessage: message,
            assistantResponse: response.message,
            intent: response.intent,
            entities: entities
        )
        conversationHistory.append(turn)

        // Update current context if provided
        if let contextToRemember = response.contextToRemember {
            currentContext.merge(contextToRemember) { _, new in new }
        }

        // Trim history if needed
        trimConversationHistory()

        return response
    }

    // MARK: - Context Building

    private func buildContextPrompt(
        message: String,
        events: [UnifiedEvent],
        tasks: [EventTask]
    ) -> String {

        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        // Build conversation history summary
        let historyContext = buildConversationHistoryContext()

        // Build current context summary
        let contextSummary = currentContext.isEmpty ? "No active context" :
            currentContext.map { "\($0.key): \($0.value)" }.joined(separator: ", ")

        // Build calendar context
        let upcomingEvents = events
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(10)

        let eventsContext = upcomingEvents.isEmpty ? "No upcoming events" :
            upcomingEvents.map { event in
                "\(event.title) - \(formatter.string(from: event.startDate))"
            }.joined(separator: "\n")

        // Build task context
        let activeTasks = tasks
            .filter { !$0.isCompleted }
            .prefix(10)

        let tasksContext = activeTasks.isEmpty ? "No active tasks" :
            activeTasks.map { task in
                "\(task.title) - Priority: \(task.priority.rawValue)"
            }.joined(separator: "\n")

        return """
        SYSTEM: You are an intelligent calendar and task assistant with conversational memory. You help users manage their schedule, tasks, and provide insights.

        CURRENT TIME: \(formatter.string(from: now))
        DAY: \(calendar.weekdaySymbols[calendar.component(.weekday, from: now) - 1])

        CONVERSATION MEMORY:
        \(historyContext)

        ACTIVE CONTEXT:
        \(contextSummary)

        UPCOMING EVENTS:
        \(eventsContext)

        ACTIVE TASKS:
        \(tasksContext)

        CAPABILITIES:
        - Create, modify, delete events and tasks
        - Answer questions about schedule and availability
        - Provide scheduling advice and optimization suggestions
        - Handle multi-turn conversations with memory of previous context
        - Ask clarifying questions when needed
        - Suggest follow-up actions

        INSTRUCTIONS:
        1. Consider the entire conversation history when responding
        2. Reference previous messages when relevant (e.g., "As we discussed earlier...")
        3. If the user refers to something from earlier in the conversation, use that context
        4. If you need more information, ask clarifying questions
        5. Be conversational and natural
        6. When executing actions, provide clear confirmation
        7. Suggest follow-up actions when appropriate
        8. Remember important context across turns using contextToRemember field

        RESPONSE FORMAT:
        - message: Natural language response to the user
        - intent: The primary intent (createEvent, modifyEvent, createTask, querySchedule, etc.)
        - confidence: Float 0-1 indicating confidence in understanding
        - requiresClarification: true if you need more information
        - clarificationQuestions: Array of specific questions to ask
        - actionType: Type of action to execute (if any)
        - actionParameters: Parameters needed to execute the action
        - contextToRemember: Key-value pairs of important context for future turns
        - suggestedFollowUps: Array of suggested next actions

        USER MESSAGE: "\(message)"

        Respond with structured data that maintains conversation continuity.
        """
    }

    private func buildConversationHistoryContext() -> String {
        guard !conversationHistory.isEmpty else {
            return "No previous conversation"
        }

        return conversationHistory.suffix(5).enumerated().map { index, turn in
            let turnNumber = conversationHistory.count - 5 + index + 1
            let entities = turn.entities.isEmpty ? "" :
                " [Entities: \(turn.entities.map { "\($0.type.rawValue):\($0.value)" }.joined(separator: ", "))]"
            return """
            Turn \(turnNumber):
            User: \(turn.userMessage)
            Assistant: \(turn.assistantResponse)\(entities)
            """
        }.joined(separator: "\n\n")
    }

    // MARK: - Entity Extraction

    private func extractEntities(from message: String, response: ConversationalResponse) -> [Entity] {
        var entities: [Entity] = []

        // Extract from action parameters if available
        if let params = response.actionParameters {
            for (key, value) in params {
                let entityType: Entity.EntityType
                switch key.lowercased() {
                case "title", "name": entityType = .event
                case "date", "startdate", "enddate": entityType = .date
                case "time", "starttime", "endtime": entityType = .time
                case "location": entityType = .location
                case "priority": entityType = .priority
                case "duration": entityType = .duration
                case "task": entityType = .task
                default: continue
                }

                entities.append(Entity(type: entityType, value: value, confidence: response.confidence))
            }
        }

        // Could add more sophisticated entity extraction here using NLP

        return entities
    }

    // MARK: - History Management

    private func trimConversationHistory() {
        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
            print("📚 Trimmed conversation history to \(maxHistoryLength) turns")
        }
    }

    func clearConversationHistory() {
        conversationHistory.removeAll()
        currentContext.removeAll()
        print("🗑️ Conversation history cleared")
    }

    func getConversationSummary() -> String {
        guard !conversationHistory.isEmpty else {
            return "No conversation history"
        }

        return """
        Conversation with \(conversationHistory.count) turns
        Recent topics: \(getRecentTopics())
        Active context: \(currentContext.keys.joined(separator: ", "))
        """
    }

    private func getRecentTopics() -> String {
        let recentIntents = conversationHistory
            .suffix(5)
            .compactMap { $0.intent }

        return recentIntents.isEmpty ? "None" : recentIntents.joined(separator: ", ")
    }

    // MARK: - OpenAI Integration

    private func callOpenAI(systemPrompt: String, userMessage: String) async throws -> ConversationalResponse {
        guard !Config.openaiAPIKey.isEmpty else {
            throw NSError(domain: "EnhancedConversationalAI", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API key not configured"
            ])
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages array with conversation history
        var messages: [[String: String]] = []

        // Add system prompt
        messages.append(["role": "system", "content": systemPrompt])

        // Add conversation history (last 5 turns for context)
        for turn in conversationHistory.suffix(5) {
            messages.append(["role": "user", "content": turn.userMessage])
            messages.append(["role": "assistant", "content": turn.assistantResponse])
        }

        // Add current user message
        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": Config.openAIModel,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1500,
            "response_format": ["type": "json_object"]  // Force JSON response
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EnhancedConversationalAI", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }

        guard httpResponse.statusCode == 200 else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "EnhancedConversationalAI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "OpenAI API error: \(errorData)"
            ])
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw NSError(domain: "EnhancedConversationalAI", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Empty response from OpenAI"
            ])
        }

        // Parse JSON response into ConversationalResponse
        guard let jsonData = content.data(using: .utf8) else {
            throw NSError(domain: "EnhancedConversationalAI", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Invalid JSON encoding"
            ])
        }

        let conversationalResponse = try JSONDecoder().decode(ConversationalResponse.self, from: jsonData)
        return conversationalResponse
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

// MARK: - UnifiedEvent Extension for Context Building

extension UnifiedEvent {
    var contextDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(title) at \(formatter.string(from: startDate))"
    }
}
