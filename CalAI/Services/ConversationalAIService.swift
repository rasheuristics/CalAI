import Foundation

/// Service for conversational AI processing with context awareness
class ConversationalAIService {

    // MARK: - Types

    struct AIAction: Codable {
        let intent: String  // "query", "create", "modify", "delete", "search", "availability", etc.
        let parameters: [String: AnyCodableValue]
        let message: String
        let needsClarification: Bool
        let clarificationQuestion: String?
        let shouldContinueListening: Bool
        let referencedEventIds: [String]?

        init(
            intent: String,
            parameters: [String: AnyCodableValue] = [:],
            message: String,
            needsClarification: Bool = false,
            clarificationQuestion: String? = nil,
            shouldContinueListening: Bool = false,
            referencedEventIds: [String]? = nil
        ) {
            self.intent = intent
            self.parameters = parameters
            self.message = message
            self.needsClarification = needsClarification
            self.clarificationQuestion = clarificationQuestion
            self.shouldContinueListening = shouldContinueListening
            self.referencedEventIds = referencedEventIds
        }
    }

    // Helper for type-erased codable values
    enum AnyCodableValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case date(Date)
        case array([AnyCodableValue])
        case dictionary([String: AnyCodableValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Int.self) {
                self = .int(value)
            } else if let value = try? container.decode(Double.self) {
                self = .double(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([AnyCodableValue].self) {
                self = .array(value)
            } else if let value = try? container.decode([String: AnyCodableValue].self) {
                self = .dictionary(value)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .null:
                try container.encodeNil()
            case .bool(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .string(let value):
                try container.encode(value)
            case .date(let value):
                try container.encode(value)
            case .array(let value):
                try container.encode(value)
            case .dictionary(let value):
                try container.encode(value)
            }
        }

        var stringValue: String? {
            if case .string(let value) = self { return value }
            return nil
        }

        var intValue: Int? {
            if case .int(let value) = self { return value }
            return nil
        }

        var boolValue: Bool? {
            if case .bool(let value) = self { return value }
            return nil
        }
    }

    // MARK: - Properties

    private let contextManager: ConversationContextManager
    private let session: URLSession

    // MARK: - Initialization

    init(contextManager: ConversationContextManager = ConversationContextManager()) {
        self.contextManager = contextManager
        self.session = URLSession.shared
    }

    // MARK: - Main Processing

    func processCommand(
        _ transcript: String,
        calendarEvents: [UnifiedEvent]
    ) async throws -> AIAction {

        print("🤖 ConversationalAI: Processing '\(transcript)'")
        print("📊 Context: \(contextManager.getSummary())")

        // Cleanup expired entities
        contextManager.cleanupExpiredEntities()

        // Add user message to context
        contextManager.addUserMessage(transcript)

        // Build system prompt with calendar context
        let systemPrompt = buildSystemPrompt(events: calendarEvents)

        // Build user message with conversation context
        let conversationContext = contextManager.buildContextPrompt()
        let userPrompt = buildUserPrompt(transcript: transcript, context: conversationContext)

        // Call OpenAI
        let response = try await callOpenAI(system: systemPrompt, user: userPrompt)

        // Parse action from response
        let action = try parseAction(from: response, events: calendarEvents)

        // Track assistant response in context
        contextManager.addAssistantMessage(action.message)

        // Track referenced events
        if let eventIds = action.referencedEventIds {
            let referencedEvents = calendarEvents.filter { eventIds.contains($0.id) }
            if !referencedEvents.isEmpty {
                contextManager.trackEvents(referencedEvents)
            }
        }

        print("✅ ConversationalAI: Intent=\(action.intent), Clarification=\(action.needsClarification)")

        return action
    }

    // MARK: - System Prompt Building

    private func buildSystemPrompt(events: [UnifiedEvent]) -> String {
        let now = Date()
        let calendar = Calendar.current

        // Get today's events
        let todayEvents = events.filter { calendar.isDateInToday($0.startDate) }
        let upcomingEvents = events.filter { $0.startDate > now }.sorted { $0.startDate < $1.startDate }.prefix(5)

        return """
        You are an intelligent calendar assistant with context-aware conversation abilities.

        Today's date: \(now.formatted(.dateTime.year().month().day()))
        Current time: \(now.formatted(.dateTime.hour().minute()))

        User's upcoming events today (\(todayEvents.count)):
        \(formatEventsForPrompt(Array(todayEvents)))

        Next upcoming events (\(upcomingEvents.count)):
        \(formatEventsForPrompt(Array(upcomingEvents)))

        CAPABILITIES:
        - query: Get events for a time range
        - create: Create new events
        - modify: Change existing events
        - delete: Remove events
        - search: Find specific events
        - availability: Check free time
        - conversation: General chat

        CONTEXT AWARENESS RULES:
        1. Use conversation history to resolve pronouns ("it", "that", "this", "the meeting")
        2. Track ordinal references ("the first one", "second one", "last one")
        3. Remember the last discussed event or list of events
        4. If user says "move it to 3pm", "it" refers to the last mentioned event
        5. For "cancel the second one", refer to the second event in the last list
        6. Always confirm destructive actions (delete, modify)
        7. Ask clarifying questions when ambiguous

        RESPONSE FORMAT:
        Respond with JSON in this exact format:
        {
          "intent": "query|create|modify|delete|search|availability|conversation",
          "parameters": {
            // Intent-specific parameters
            // For query: {"start_date": "ISO8601", "end_date": "ISO8601"}
            // For create: {"title": "string", "start_time": "ISO8601", "duration_minutes": number}
            // For modify: {"event_id": "string", "new_start_time": "ISO8601"}
            // For delete: {"event_id": "string"}
          },
          "message": "Natural language response to user",
          "needsClarification": true/false,
          "clarificationQuestion": "Question to ask if ambiguous (or null)",
          "shouldContinueListening": true/false,
          "referencedEventIds": ["event-id-1", "event-id-2"] // Events mentioned in response (or null)
        }

        IMPORTANT:
        - Always include a natural, friendly "message" field
        - Set "shouldContinueListening" to true if you ask a question
        - Include "referencedEventIds" when discussing specific events
        - Use ISO8601 format for all dates/times
        - For ambiguous requests, set "needsClarification" to true
        """
    }

    private func formatEventsForPrompt(_ events: [UnifiedEvent]) -> String {
        guard !events.isEmpty else { return "  (none)" }

        return events.prefix(10).map { event in
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "  - '\(event.title)' (ID: \(event.id)) at \(formatter.string(from: event.startDate))"
        }.joined(separator: "\n")
    }

    // MARK: - User Prompt Building

    private func buildUserPrompt(transcript: String, context: String) -> String {
        var parts: [String] = []

        if !context.isEmpty {
            parts.append(context)
            parts.append("") // blank line
        }

        parts.append("User's current request: \(transcript)")

        return parts.joined(separator: "\n")
    }

    // MARK: - OpenAI Integration

    private func callOpenAI(system: String, user: String) async throws -> String {
        guard !Config.openaiAPIKey.isEmpty else {
            throw NSError(domain: "ConversationalAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages = [
            ["role": "system", "content": system],
            ["role": "user", "content": user]
        ]

        let body: [String: Any] = [
            "model": Config.openAIModel,
            "messages": messages,
            "temperature": 0.3,  // Lower = more deterministic
            "max_tokens": 500
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ConversationalAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ConversationalAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error: \(errorData)"])
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
            throw NSError(domain: "ConversationalAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty response from OpenAI"])
        }

        return content
    }

    // MARK: - Action Parsing

    private func parseAction(from response: String, events: [UnifiedEvent]) throws -> AIAction {
        print("🔍 Parsing OpenAI response: \(response.prefix(200))...")

        // Extract JSON from response (in case it's wrapped in markdown)
        guard let jsonString = extractJSON(from: response) else {
            print("⚠️ No JSON found, treating as conversation")
            // Fallback: treat as conversational response
            return AIAction(
                intent: "conversation",
                message: response,
                needsClarification: false
            )
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ConversationalAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON encoding"])
        }

        do {
            let action = try JSONDecoder().decode(AIAction.self, from: jsonData)
            return action
        } catch {
            print("❌ JSON parsing error: \(error)")
            // Fallback
            return AIAction(
                intent: "conversation",
                message: response,
                needsClarification: false
            )
        }
    }

    private func extractJSON(from text: String) -> String? {
        // Try to find JSON between ```json and ``` markers
        if let jsonMatch = text.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
            let jsonText = String(text[jsonMatch])
            let cleaned = jsonText
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned
        }

        // Try to find JSON between { and }
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }

        return nil
    }

    // MARK: - Context Management

    func clearContext() {
        contextManager.clearHistory()
    }

    func getContextManager() -> ConversationContextManager {
        return contextManager
    }
}
