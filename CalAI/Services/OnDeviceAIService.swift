import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// On-device AI service using Apple's Foundation Models (iOS 26+)
/// Provides private, fast, and free AI processing without requiring API keys or internet connection
@available(iOS 26.0, *)
class OnDeviceAIService {

    // MARK: - Singleton
    static let shared = OnDeviceAIService()

    // Language model session for on-device AI
    private let session: LanguageModelSession

    private init() {
        // Initialize session with calendar assistant instructions
        self.session = LanguageModelSession(
            instructions: """
            You are an intelligent calendar assistant with context-aware conversation abilities.
            Respond with JSON in the exact format specified in the user's prompts.
            Always be helpful, natural, and conversational while maintaining the required JSON structure.
            """
        )
    }

    // MARK: - Types

    // Use @Generable for structured output with Foundation Models
    @Generable
    struct AIAction {
        @Guide(description: "The user's intent: query, create, modify, delete, search, availability, or conversation")
        let intent: String

        @Guide(description: "Start date/time for the event in ISO8601 format, if applicable")
        let startDate: String?

        @Guide(description: "End date/time for the event in ISO8601 format, if applicable")
        let endDate: String?

        @Guide(description: "Event title or description, if applicable")
        let title: String?

        @Guide(description: "Event location, if applicable")
        let location: String?

        @Guide(description: "Natural language response to the user")
        let message: String

        @Guide(description: "Whether the request needs clarification")
        let needsClarification: Bool

        @Guide(description: "Question to ask if clarification is needed")
        let clarificationQuestion: String?

        @Guide(description: "Whether to continue listening for follow-up")
        let shouldContinueListening: Bool

        @Guide(description: "IDs of events referenced in the conversation")
        let referencedEventIds: [String]?
    }

    // Helper for type-erased codable values (same as ConversationalAIService)
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

    // MARK: - Main Processing

    /// Process a conversational command using on-device AI
    /// - Parameters:
    ///   - transcript: The user's spoken/typed command
    ///   - calendarEvents: The user's calendar events for context
    /// - Returns: An AIAction with intent, parameters, and response message
    func processCommand(
        _ transcript: String,
        calendarEvents: [UnifiedEvent]
    ) async throws -> AIAction {

        print("🤖 OnDeviceAI: Processing '\(transcript)'")
        print("✅ FoundationModels framework is available")

        // Use Foundation Models API (iOS 26+)
        let prompt = buildPrompt(transcript: transcript, events: calendarEvents)
        print("📝 Prompt length: \(prompt.count) characters")

        do {
            print("🔄 Calling session.respond()...")
            // Use structured output with @Generable for guaranteed valid AIAction
            let response = try await session.respond(
                to: prompt,
                generating: AIAction.self
            )

            let action = response.content
            print("✅ OnDeviceAI: Intent=\(action.intent), Message=\(action.message), Clarification=\(action.needsClarification)")

            // Convert to the expected return type
            return convertToReturnType(action)

        } catch {
            print("❌ OnDeviceAI error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            // Check for specific FoundationModels errors
            let nsError = error as NSError
            print("❌ Error domain: \(nsError.domain)")
            print("❌ Error code: \(nsError.code)")

            // Provide more specific error messages
            var errorMessage = "On-device AI error: \(error.localizedDescription)"

            if nsError.domain == "FoundationModels" || nsError.domain.contains("Language") {
                errorMessage += "\n\n💡 This usually means:\n"
                errorMessage += "• Apple Intelligence is not enabled\n"
                errorMessage += "• Device doesn't support Apple Intelligence\n"
                errorMessage += "• Running on iOS Simulator (not supported)\n\n"
                errorMessage += "Go to Settings > Apple Intelligence & Siri to enable."
            }

            throw NSError(
                domain: "OnDeviceAI",
                code: 503,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage
                ]
            )
        }
    }

    // Convert @Generable AIAction to the expected return type with parameters dictionary
    private func convertToReturnType(_ action: AIAction) -> AIAction {
        // The @Generable version uses individual fields, but we need to return
        // the version with a parameters dictionary for compatibility
        // For now, since both are named AIAction, just return the action as-is
        // The calling code will handle the field differences
        return action
    }

    // MARK: - Prompt Building

    /// Build the complete prompt with calendar context for Foundation Models
    private func buildPrompt(transcript: String, events: [UnifiedEvent]) -> String {
        let now = Date()
        let calendar = Calendar.current

        // Get today's events
        let todayEvents = events.filter { calendar.isDateInToday($0.startDate) }
        let upcomingEvents = events.filter { $0.startDate > now }.sorted { $0.startDate < $1.startDate }.prefix(5)

        return """
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
        - weather: Get current weather information
        - create_task: Create a new task
        - list_tasks: List tasks
        - update_task: Update task properties
        - complete_task: Mark task as complete
        - conversation: General chat

        INTENT TYPES:
        Choose one: query, create, modify, delete, search, availability, weather, create_task, list_tasks, update_task, complete_task, conversation

        IMPORTANT GUIDELINES:
        - Provide a natural, friendly message in your response
        - Set shouldContinueListening to true if you ask a question
        - Include referencedEventIds when discussing specific events
        - Use ISO8601 format for date/time parameters
        - Set needsClarification to true for ambiguous requests
        - For weather queries with dates like "tomorrow", "Saturday", "next Tuesday", extract the date and include it in parameters

        USER REQUEST: \(transcript)

        Analyze the request and respond with the appropriate intent and parameters.
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

}

#endif // canImport(FoundationModels)
