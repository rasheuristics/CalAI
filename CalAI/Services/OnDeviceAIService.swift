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

    // MARK: - High-Impact Easy Implementations

    // MARK: 1. Morning Briefing Enhancement

    /// Generate a personalized, AI-enhanced morning briefing
    @Generable
    struct MorningBriefingContent {
        @Guide(description: "Warm, friendly greeting appropriate for time of day")
        let greeting: String

        @Guide(description: "2-3 sentence overview of the day ahead")
        let daySummary: String

        @Guide(description: "Highlight of the most important event or task")
        let keyFocus: String

        @Guide(description: "Brief weather comment (1 sentence)")
        let weatherNote: String?

        @Guide(description: "Encouraging closing message")
        let motivation: String

        @Guide(description: "Suggested preparation or reminder")
        let actionableReminder: String?
    }

    func generateMorningBriefing(
        todaysEvents: [UnifiedEvent],
        tasks: [String], // Task titles
        weatherDescription: String?
    ) async throws -> MorningBriefingContent {
        let now = Date()
        let timeOfDay = Calendar.current.component(.hour, from: now) < 12 ? "morning" : "day"

        let prompt = """
        Generate a personalized \(timeOfDay) briefing for the user.

        Today's Schedule (\(todaysEvents.count) events):
        \(formatEventsForBriefing(todaysEvents))

        Tasks Due Today (\(tasks.count)):
        \(tasks.isEmpty ? "  (none)" : tasks.prefix(5).map { "  - \($0)" }.joined(separator: "\n"))

        Weather: \(weatherDescription ?? "Not available")

        Create a warm, motivating briefing that:
        - Greets the user naturally
        - Summarizes the day in 2-3 sentences
        - Highlights the most important item
        - Mentions weather if notable
        - Ends with encouragement
        - Suggests one actionable preparation tip if relevant
        """

        print("🌅 Generating morning briefing...")
        let response = try await session.respond(to: prompt, generating: MorningBriefingContent.self)
        return response.content
    }

    private func formatEventsForBriefing(_ events: [UnifiedEvent]) -> String {
        guard !events.isEmpty else { return "  (No events scheduled)" }

        return events.sorted { $0.startDate < $1.startDate }.prefix(8).map { event in
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let time = formatter.string(from: event.startDate)
            let duration = formatDuration(from: event.startDate, to: event.endDate)
            return "  - \(time): \(event.title) (\(duration))"
        }.joined(separator: "\n")
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
    }

    // MARK: 2. Smart Event Suggestions

    /// AI-generated event suggestions based on user patterns
    @Generable
    struct EventSuggestion {
        @Guide(description: "Suggested event title")
        let title: String

        @Guide(description: "Suggested day (e.g., 'Monday', 'Tomorrow')")
        let suggestedDay: String

        @Guide(description: "Suggested time (e.g., '9:00 AM', '2:00 PM')")
        let suggestedTime: String

        @Guide(description: "Why this event is suggested")
        let reason: String

        @Guide(description: "Confidence level: high, medium, or low")
        let confidence: String

        @Guide(description: "Event type: meeting, break, task, personal, recurring")
        let eventType: String
    }

    func suggestEvents(
        basedOn historicalEvents: [UnifiedEvent],
        currentWeek: Date
    ) async throws -> [EventSuggestion] {
        let patterns = analyzeEventPatterns(historicalEvents)
        let weekday = Calendar.current.component(.weekday, from: currentWeek)
        let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]

        let prompt = """
        Analyze the user's calendar patterns and suggest events for the current week.

        Detected Patterns:
        \(patterns)

        Current Week Starting: \(weekdayName), \(formatDate(currentWeek))

        Recent Events (for context):
        \(formatEventsForBriefing(Array(historicalEvents.suffix(15))))

        Suggest 3-5 events the user might want to schedule this week based on:
        - Recurring patterns (weekly meetings, regular activities)
        - Missing routines (if they usually have gym/lunch/breaks but don't this week)
        - Follow-up meetings (if previous meetings suggest follow-ups)
        - Work-life balance (suggest breaks if overbooked)

        For each suggestion, provide:
        - A clear title
        - Specific day and time
        - Reasoning
        - Confidence level (high if it's a clear pattern, medium/low otherwise)
        - Event type
        """

        print("💡 Generating smart event suggestions...")
        let response = try await session.respond(to: prompt, generating: [EventSuggestion].self)
        return response.content
    }

    private func analyzeEventPatterns(_ events: [UnifiedEvent]) -> String {
        let calendar = Calendar.current
        var patterns: [String] = []

        // Count events by day of week
        var dayFrequency: [Int: Int] = [:]
        for event in events {
            let weekday = calendar.component(.weekday, from: event.startDate)
            dayFrequency[weekday, default: 0] += 1
        }

        // Find busiest days
        if let busiestDay = dayFrequency.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[busiestDay.key - 1]
            patterns.append("- Busiest day: \(dayName) (\(busiestDay.value) events on average)")
        }

        // Count recurring titles
        var titleFrequency: [String: Int] = [:]
        for event in events {
            titleFrequency[event.title, default: 0] += 1
        }

        // Find recurring meetings
        let recurring = titleFrequency.filter { $0.value >= 3 }.sorted { $0.value > $1.value }.prefix(3)
        if !recurring.isEmpty {
            patterns.append("- Recurring meetings: \(recurring.map { "\($0.key) (×\($0.value))" }.joined(separator: ", "))")
        }

        // Average events per week
        let weekSpan = max(1, events.count / 7)
        patterns.append("- Average: ~\(weekSpan) events per week")

        return patterns.isEmpty ? "No clear patterns detected yet." : patterns.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: 3. Task Priority & Scheduling

    /// AI-powered task scheduling recommendations
    @Generable
    struct TaskScheduleRecommendation {
        @Guide(description: "The task title")
        let taskTitle: String

        @Guide(description: "Recommended day (e.g., 'Today', 'Tomorrow', 'Wednesday')")
        let recommendedDay: String

        @Guide(description: "Recommended time slot (e.g., '9:00 AM - 10:00 AM')")
        let recommendedTimeSlot: String

        @Guide(description: "Estimated duration in minutes")
        let estimatedDuration: Int

        @Guide(description: "Priority level: high, medium, or low")
        let priority: String

        @Guide(description: "Reasoning for this scheduling recommendation")
        let reasoning: String

        @Guide(description: "Best type of time for this task: focus, admin, creative, or flexible")
        let taskType: String
    }

    func scheduleTasksIntelligently(
        tasks: [String], // Task titles
        calendar: [UnifiedEvent],
        workingHours: (start: Int, end: Int)
    ) async throws -> [TaskScheduleRecommendation] {
        let availableSlots = findAvailableSlots(in: calendar, workingHours: workingHours)

        let prompt = """
        Schedule these tasks optimally in the user's calendar.

        Tasks to Schedule (\(tasks.count)):
        \(tasks.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Available Time Slots This Week:
        \(availableSlots)

        Current Schedule:
        \(formatEventsForBriefing(Array(calendar.prefix(10))))

        Working Hours: \(workingHours.start):00 - \(workingHours.end):00

        For each task, recommend:
        - Best day and time slot
        - Estimated duration (realistic)
        - Priority level based on urgency/importance signals in task name
        - Reasoning (why this slot is good)
        - Task type (focus work, admin, creative, or flexible)

        Consider:
        - Deep work tasks → morning (9-12) when energy is high
        - Admin tasks → afternoon (2-4)
        - Creative tasks → mid-morning or after lunch
        - Buffer time between meetings
        - Don't overbook - leave breathing room
        - Group similar tasks together
        """

        print("📅 Generating task scheduling recommendations...")
        let response = try await session.respond(to: prompt, generating: [TaskScheduleRecommendation].self)
        return response.content
    }

    private func findAvailableSlots(in events: [UnifiedEvent], workingHours: (start: Int, end: Int)) -> String {
        let calendar = Calendar.current
        let today = Date()
        var slots: [String] = []

        // Check next 5 weekdays
        for dayOffset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dayName = dayOffset == 0 ? "Today" : (dayOffset == 1 ? "Tomorrow" : calendar.weekdaySymbols[calendar.component(.weekday, from: day) - 1])

            // Filter events for this day
            let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                .sorted { $0.startDate < $1.startDate }

            if dayEvents.isEmpty {
                slots.append("\(dayName): Open all day (\(workingHours.start):00 - \(workingHours.end):00)")
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short

                var availableHours = workingHours.end - workingHours.start
                for event in dayEvents {
                    let eventHours = event.endDate.timeIntervalSince(event.startDate) / 3600
                    availableHours -= Int(eventHours)
                }

                slots.append("\(dayName): ~\(max(0, availableHours)) hours available between \(dayEvents.count) events")
            }
        }

        return slots.joined(separator: "\n")
    }

    // MARK: - High-Impact Medium Effort Implementations

    // MARK: 4. Post-Meeting Action Items

    /// Extract insights from meeting notes using on-device AI
    @Generable
    struct MeetingInsights {
        @Guide(description: "Brief 2-3 sentence meeting summary")
        let summary: String

        @Guide(description: "List of action items extracted from the meeting")
        let actionItems: [ActionItem]

        @Guide(description: "Key decisions made during the meeting")
        let decisions: [String]

        @Guide(description: "Whether a follow-up meeting is needed")
        let followUpNeeded: Bool

        @Guide(description: "Suggested date for follow-up (e.g., 'Next week', 'In 2 weeks')")
        let suggestedFollowUpDate: String?

        @Guide(description: "Overall meeting sentiment: positive, neutral, or negative")
        let sentiment: String

        @Guide(description: "Topics discussed in the meeting")
        let topics: [String]
    }

    @Generable
    struct ActionItem {
        @Guide(description: "Clear, actionable description of the task")
        let title: String

        @Guide(description: "Person responsible for this action (if mentioned)")
        let assignee: String?

        @Guide(description: "Suggested due date (e.g., 'End of week', 'Next Monday')")
        let dueDate: String?

        @Guide(description: "Priority level: high, medium, or low")
        let priority: String

        @Guide(description: "Additional context or details")
        let context: String?
    }

    func analyzeMeetingNotes(
        eventTitle: String,
        notes: String,
        attendees: [String]
    ) async throws -> MeetingInsights {
        let prompt = """
        Analyze these meeting notes and extract actionable insights.

        Meeting: \(eventTitle)
        Attendees: \(attendees.joined(separator: ", "))

        Notes:
        \(notes)

        Extract and provide:
        1. Brief summary (2-3 sentences capturing main points)
        2. Action items with:
           - Clear, actionable descriptions
           - Assignee (if mentioned)
           - Due date (if mentioned or reasonable to suggest)
           - Priority (based on urgency indicators)
           - Context (why it matters)
        3. Key decisions made (concrete choices, not discussions)
        4. Whether follow-up meeting is needed and when
        5. Overall sentiment (positive/neutral/negative based on tone)
        6. Main topics discussed

        Be specific and actionable. If something isn't explicitly stated, use "Unknown" for assignee/due date.
        """

        print("📝 Analyzing meeting notes...")
        let response = try await session.respond(to: prompt, generating: MeetingInsights.self)
        return response.content
    }

    // MARK: 5. Natural Language Search

    /// Semantic search for events using natural language understanding
    @Generable
    struct SearchResult {
        @Guide(description: "Event ID that matches the search")
        let eventId: String

        @Guide(description: "Event title")
        let eventTitle: String

        @Guide(description: "Relevance score from 0-100, where 100 is perfect match")
        let relevanceScore: Int

        @Guide(description: "Explanation of why this event matches the query")
        let matchReason: String

        @Guide(description: "Event date in readable format")
        let eventDate: String

        @Guide(description: "Type of match: exact, synonym, semantic, time-based, or person")
        let matchType: String
    }

    func semanticSearch(
        query: String,
        in events: [UnifiedEvent]
    ) async throws -> [SearchResult] {
        // Format events with relevant details
        let eventsContext = formatEventsForSearch(events)

        let prompt = """
        Search for events matching this query: "\(query)"

        Available events:
        \(eventsContext)

        Find relevant events using semantic understanding:
        - Understand synonyms: "meeting" = "call" = "sync" = "chat" = "discussion"
        - Match partial names: "Sarah" matches "Sarah Johnson" or "Sarah Miller"
        - Understand time references: "last week", "recent", "upcoming", "next month"
        - Recognize related concepts: "lunch" matches "meal", "dinner", "restaurant", "cafe"
        - Consider locations: "office" matches events at office addresses
        - Match topics: "project review" matches events discussing projects

        Return top 10 most relevant events, ranked by relevance (100 = perfect, 0 = no match).
        Include events with relevance ≥ 30.

        Explain WHY each event matches (specific words, concepts, or context).
        """

        print("🔍 Performing semantic search for: '\(query)'")
        let response = try await session.respond(to: prompt, generating: [SearchResult].self)
        return response.content.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func formatEventsForSearch(_ events: [UnifiedEvent]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return events.prefix(50).map { event in
            let dateStr = formatter.string(from: event.startDate)
            let location = event.location ?? "No location"
            let notes = event.description ?? "No notes"
            return """
            ID: \(event.id)
            Title: \(event.title)
            Date: \(dateStr)
            Location: \(location)
            Notes: \(notes.prefix(100))...
            """
        }.joined(separator: "\n---\n")
    }

    // MARK: 6. Voice Command Enhancement

    /// Advanced conversational response with context awareness
    @Generable
    struct ConversationalResponse {
        @Guide(description: "Natural language response to the user")
        let message: String

        @Guide(description: "Intent identified: query, create, modify, delete, clarify, acknowledge")
        let intent: String

        @Guide(description: "Entities extracted from the conversation")
        let entities: [ExtractedEntity]

        @Guide(description: "Whether this requires clarification")
        let needsClarification: Bool

        @Guide(description: "Follow-up question if clarification needed")
        let clarificationQuestion: String?

        @Guide(description: "Whether to continue listening for follow-up")
        let shouldContinueListening: Bool

        @Guide(description: "Confidence level: high, medium, or low")
        let confidence: String

        @Guide(description: "Suggested actions for the user")
        let suggestedActions: [String]
    }

    @Generable
    struct ExtractedEntity {
        @Guide(description: "Type of entity: date, time, person, location, event")
        let type: String

        @Guide(description: "The extracted value")
        let value: String
    }

    @Generable
    struct ConversationTurn {
        @Guide(description: "What the user said")
        let userMessage: String

        @Guide(description: "What the assistant responded")
        let assistantMessage: String

        @Guide(description: "When this exchange happened")
        let timestamp: String
    }

    func handleConversationalContext(
        userMessage: String,
        conversationHistory: [ConversationTurn],
        currentContext: ConversationContext,
        recentEvents: [UnifiedEvent]
    ) async throws -> ConversationalResponse {
        let historyContext = formatConversationHistory(conversationHistory)
        let eventsContext = formatEventsForPrompt(recentEvents)

        let prompt = """
        You are a helpful calendar assistant engaged in a natural conversation.

        Conversation History (last 5 turns):
        \(historyContext)

        Current Context:
        - Last mentioned event: \(currentContext.lastEventTitle ?? "none")
        - Last mentioned event ID: \(currentContext.lastEventId ?? "none")
        - Last mentioned date: \(currentContext.lastMentionedDate ?? "none")
        - Pending question: \(currentContext.pendingQuestion ?? "none")
        - User's timezone: \(currentContext.userTimezone ?? "Unknown")

        Recent Events (for reference):
        \(eventsContext)

        User says: "\(userMessage)"

        Respond naturally and conversationally while:
        - Understanding pronouns correctly (it, that, them, those refer to previously mentioned events/dates)
        - Maintaining context from previous messages
        - Being helpful and friendly
        - Asking for clarification when ambiguous
        - Suggesting relevant actions
        - Using natural language, not formal/robotic
        - Handling follow-ups like "move it to tomorrow", "who's attending?", "change the time"

        Identify the intent, extract entities (dates, times, people, locations), and provide a helpful response.
        """

        print("💬 Processing conversational command: '\(userMessage)'")
        let response = try await session.respond(to: prompt, generating: ConversationalResponse.self)
        return response.content
    }

    private func formatConversationHistory(_ history: [ConversationTurn]) -> String {
        if history.isEmpty {
            return "(No previous conversation)"
        }

        return history.suffix(5).map { turn in
            "User: \(turn.userMessage)\nAssistant: \(turn.assistantMessage)"
        }.joined(separator: "\n---\n")
    }

    // Helper struct for conversation context
    struct ConversationContext {
        let lastEventTitle: String?
        let lastEventId: String?
        let lastMentionedDate: String?
        let pendingQuestion: String?
        let userTimezone: String?

        static let empty = ConversationContext(
            lastEventTitle: nil,
            lastEventId: nil,
            lastMentionedDate: nil,
            pendingQuestion: nil,
            userTimezone: nil
        )
    }

}

#endif // canImport(FoundationModels)
