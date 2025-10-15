import Foundation
import SwiftAnthropic
import EventKit

// MARK: - Data Structures

struct ConversationItem: Identifiable {
    let id: UUID
    let message: String
    let isUser: Bool
    let timestamp: Date
    let eventResults: [EventResult]?

    init(id: UUID = UUID(), message: String, isUser: Bool, timestamp: Date = Date(), eventResults: [EventResult]? = nil) {
        self.id = id
        self.message = message
        self.isUser = isUser
        self.timestamp = timestamp
        self.eventResults = eventResults
    }
}

enum AIError: Error {
    case invalidResponse
    case apiError(String)
    case networkError
    case authenticationError
    case rateLimitError
    case timeoutError
    case noAPIKeyConfigured

    var userFriendlyMessage: String {
        switch self {
        case .invalidResponse:
            return "I received an unexpected response. Please try again."
        case .apiError(let message):
            return "I encountered an error: \(message)"
        case .networkError:
            return "I'm having trouble connecting. Please check your internet connection."
        case .authenticationError:
            return "There's an issue with the API configuration. Please check your settings."
        case .rateLimitError:
            return "I've received too many requests. Please wait a moment and try again."
        case .timeoutError:
            return "The request took too long. Please try again."
        case .noAPIKeyConfigured:
            return "Please configure your API key in Settings to use AI features."
        }
    }
}

// Represents the state of a multi-turn conversation
enum ConversationState: Equatable, CustomStringConvertible {
    case idle // Waiting for a new command
    case awaitingConfirmation // AI has asked a yes/no question and is waiting for a reply
    case creatingEvent(ExtractedEntities, missingField: String) // In the middle of creating an event, waiting for missing info

    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .awaitingConfirmation:
            return "awaitingConfirmation"
        case .creatingEvent(_, let missingField):
            return "creatingEvent(missingField: \(missingField))"
        }
    }

    static func == (lhs: ConversationState, rhs: ConversationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.awaitingConfirmation, .awaitingConfirmation):
            return true
        case (.creatingEvent(_, let lhsField), .creatingEvent(_, let rhsField)):
            return lhsField == rhsField
        default:
            return false
        }
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false

    // State management for multi-turn conversations
    @Published var conversationState: ConversationState = .idle
    @Published var pendingCommand: CalendarCommand? = nil

    // Conversation context retention
    private var lastQueryTimeRange: (start: Date, end: Date)?
    private var lastQueryEvents: [UnifiedEvent] = []
    private var conversationContext: [String] = [] // Recent user queries
    private let maxContextMessages = 3 // Keep last 3 messages for context

    private let parser: NaturalLanguageParser
    private let smartEventParser: SmartEventParser
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        self.parser = NaturalLanguageParser()
        self.smartEventParser = SmartEventParser()
    }

    // MARK: - Context Management

    private func addToContext(_ message: String) {
        conversationContext.append(message)
        if conversationContext.count > maxContextMessages {
            conversationContext.removeFirst()
        }
        print("💭 Context updated: \(conversationContext)")
    }

    private func buildContextPrompt() -> String {
        guard !conversationContext.isEmpty else {
            return ""
        }
        return "\nRecent conversation context:\n" + conversationContext.enumerated().map { index, msg in
            "[\(index + 1)] \(msg)"
        }.joined(separator: "\n") + "\n"
    }

    // MARK: - Main Command Processing

    func processVoiceCommand(_ transcript: String, conversationHistory: [ConversationItem] = [], calendarEvents: [UnifiedEvent] = [], completion: @escaping (AICalendarResponse) -> Void) {
        print("🧠 AI Manager processing transcript: \"\(transcript)\"")
        print("🔄 Current conversation state: \(conversationState)")
        isProcessing = true

        if conversationState == .awaitingConfirmation {
            print("✋ Handling confirmation response")
            handleConfirmation(transcript: transcript, completion: completion)
            return
        }

        // Check if we're in the middle of creating an event
        if case .creatingEvent(let entities, let missingField) = conversationState {
            print("📝 Continuing event creation - filling in: \(missingField)")
            print("📝 Current entities: title=\(entities.title ?? "nil"), attendees=\(entities.attendeeNames), time=\(entities.time?.description ?? "nil")")
            handleEventClarification(transcript: transcript, entities: entities, missingField: missingField, completion: completion)
            return
        }

        print("🆕 Starting new command processing")

        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            let response = AICalendarResponse(message: "I didn't catch that. Please try again.")
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(response)
            }
            return
        }

        // Add to conversation context
        addToContext(cleanTranscript)

        // Classify intent first (now with context awareness)
        let intent = classifyIntent(from: cleanTranscript)
        print("🎯 Classified intent: \(intent)")

        Task {
            do {
                switch intent {
                case .query:
                    // Handle calendar queries (what's on my schedule, etc.)
                    try await handleQuery(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .create:
                    // Handle event creation using SmartEventParser
                    await handleEventCreation(transcript: cleanTranscript, completion: completion)

                case .conversation:
                    // Handle general conversation
                    try await handleConversation(transcript: cleanTranscript, completion: completion)
                }

            } catch {
                print("❌ Error processing voice command: \(error)")
                let errorMessage = handleError(error)
                let errorResponse = AICalendarResponse(message: errorMessage)
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) -> String {
        // Check if it's our custom AIError
        if let aiError = error as? AIError {
            return aiError.userFriendlyMessage
        }

        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return AIError.networkError.userFriendlyMessage
            case .timedOut:
                return AIError.timeoutError.userFriendlyMessage
            case .userAuthenticationRequired:
                return AIError.authenticationError.userFriendlyMessage
            default:
                return "I encountered a network issue: \(urlError.localizedDescription)"
            }
        }

        // Generic fallback
        return "Sorry, I had trouble understanding that. Please try again."
    }

    private func retryWithBackoff<T>(
        maxRetries: Int = 2,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                lastError = error
                print("⚠️ Attempt \(attempt) failed with network error, retrying in \(delay)s...")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2 // Exponential backoff
            } catch {
                // For non-network errors, don't retry
                throw error
            }
        }

        // If we've exhausted all retries, throw the last error
        throw lastError ?? AIError.invalidResponse
    }

    // MARK: - Intent Classification

    private enum UserIntent {
        case query    // Asking about schedule/events
        case create   // Creating/modifying events
        case conversation // General chat
    }

    private func classifyIntent(from text: String) -> UserIntent {
        let lowercased = text.lowercased()

        // Query patterns - asking about schedule
        let queryPatterns = [
            // Question words
            ("what", 3), ("what's", 3), ("whats", 3), ("when", 2), ("where", 2),
            ("show", 2), ("tell", 2), ("list", 2),
            // Schedule inquiry phrases
            ("do i have", 4), ("am i free", 4), ("am i busy", 4),
            ("any events", 3), ("anything on", 3), ("anything scheduled", 3),
            // Time references with questions
            ("my schedule", 3), ("my day", 3), ("my calendar", 3),
            ("my events", 3), ("my meetings", 3), ("my afternoon", 3), ("my morning", 3),
            // Look/check patterns
            ("look like", 3), ("looks like", 3), ("check my", 2)
        ]

        // Creation patterns - creating/modifying events
        let createPatterns = [
            // Strong creation verbs
            ("schedule", 4), ("create", 4), ("add", 4), ("book", 4),
            ("make", 3), ("set up", 4), ("plan", 3), ("arrange", 3),
            // Event phrases
            ("put on", 3), ("new event", 5), ("new meeting", 5),
            // Time + action patterns
            ("at", 1), ("on", 1), ("for", 1) // Weak signals, need other context
        ]

        // Conversation patterns
        let conversationPatterns = [
            ("hello", 5), ("hi", 5), ("hey", 5), ("good morning", 5),
            ("good afternoon", 5), ("good evening", 5), ("thanks", 5),
            ("thank you", 5), ("goodbye", 5), ("bye", 5)
        ]

        // Calculate scores
        var queryScore = 0
        var createScore = 0
        var conversationScore = 0

        for (keyword, weight) in queryPatterns {
            if lowercased.contains(keyword) {
                queryScore += weight
            }
        }

        for (keyword, weight) in createPatterns {
            if lowercased.contains(keyword) {
                createScore += weight
            }
        }

        for (keyword, weight) in conversationPatterns {
            if lowercased.contains(keyword) {
                conversationScore += weight
            }
        }

        // Boost query score if starts with question words
        if lowercased.hasPrefix("what") || lowercased.hasPrefix("when") ||
           lowercased.hasPrefix("show") || lowercased.hasPrefix("tell") {
            queryScore += 5
        }

        // Boost create score if contains time indicators and action verbs
        if (lowercased.contains("at") || lowercased.contains("on")) &&
           (lowercased.contains("schedule") || lowercased.contains("book") || lowercased.contains("add")) {
            createScore += 3
        }

        print("📊 Intent scores - Query: \(queryScore), Create: \(createScore), Conversation: \(conversationScore)")

        // Return intent with highest score
        if queryScore >= createScore && queryScore >= conversationScore && queryScore > 0 {
            return .query
        } else if createScore > queryScore && createScore >= conversationScore && createScore > 2 {
            return .create
        } else if conversationScore > 0 {
            return .conversation
        }

        // Default: if uncertain, treat as query
        return .query
    }

    // MARK: - Event Creation Handling

    private func handleEventCreation(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async {
        print("📝 Handling event creation with SmartEventParser")

        // Parse the command using SmartEventParser
        let parseResult = smartEventParser.parse(transcript)

        switch parseResult {
        case .success(let entities, let confirmation):
            print("✅ SmartEventParser success with high confidence")

            // Convert ExtractedEntities to CalendarCommand
            guard let calendarCommand = await convertToCalendarCommand(entities) else {
                let errorResponse = AICalendarResponse(message: "I couldn't create the event. Please try again with more details.")
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
                return
            }

            let requiresConfirmation = self.commandRequiresConfirmation(calendarCommand)

            var aiResponse = AICalendarResponse(
                message: confirmation,
                command: calendarCommand,
                requiresConfirmation: requiresConfirmation,
                confirmationMessage: confirmation
            )

            if Config.aiOutputMode == .voiceOnly && requiresConfirmation {
                print("🎤 Voice-only mode: Awaiting confirmation")
                self.pendingCommand = calendarCommand
                self.conversationState = .awaitingConfirmation
                aiResponse.command = nil // Clear command for this turn
            }

            await MainActor.run {
                self.isProcessing = false
                completion(aiResponse)
            }

        case .needsClarification(let entities, let question):
            print("❓ SmartEventParser needs clarification: \(question)")

            // Store partial entities and set conversation state
            if let missingField = entities.missingFields.first {
                await MainActor.run {
                    self.conversationState = .creatingEvent(entities, missingField: missingField)
                    print("💾 Stored partial event, waiting for: \(missingField)")
                }
            }

            let aiResponse = AICalendarResponse(message: question)

            await MainActor.run {
                self.isProcessing = false
                completion(aiResponse)
            }

        case .failure(let message):
            print("❌ SmartEventParser failed: \(message)")

            // Fallback to old parser
            print("🔄 Falling back to original NaturalLanguageParser")
            do {
                let parsedEvent = try await self.parser.parseEvent(from: transcript)

                let calendarCommand = CalendarCommand(
                    type: .createEvent,
                    title: parsedEvent.title,
                    startDate: parsedEvent.startDate,
                    endDate: parsedEvent.endDate,
                    location: parsedEvent.location,
                    participants: parsedEvent.attendees
                )

                let aiResponse = AICalendarResponse(
                    message: self.generateResponseMessage(for: calendarCommand),
                    command: calendarCommand
                )

                await MainActor.run {
                    self.isProcessing = false
                    completion(aiResponse)
                }
            } catch {
                let errorResponse = AICalendarResponse(message: message)
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
            }
        }
    }

    // Convert ExtractedEntities to CalendarCommand
    private func convertToCalendarCommand(_ entities: ExtractedEntities) async -> CalendarCommand? {
        // Ensure we have minimum required fields
        guard let title = entities.title,
              let startDate = entities.time else {
            print("⚠️ Missing required fields: title or time")
            return nil
        }

        // Calculate end date
        let endDate: Date
        if let duration = entities.duration {
            endDate = startDate.addingTimeInterval(duration)
        } else {
            // Default to 1 hour
            endDate = startDate.addingTimeInterval(3600)
        }

        // Match attendee names to emails
        var participantEmails: [String] = []
        if !entities.attendeeNames.isEmpty {
            participantEmails = await matchAttendeesToEmails(entities.attendeeNames)
        }

        return CalendarCommand(
            type: .createEvent,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: entities.location,
            participants: participantEmails.isEmpty ? nil : participantEmails
        )
    }

    // Match attendee names to contact emails
    private func matchAttendeesToEmails(_ names: [String]) async -> [String] {
        var emails: [String] = []

        for name in names {
            // Handle special groups
            if name.hasPrefix("@") {
                // Skip for now, would need team/group management
                print("⚠️ Skipping group: \(name)")
                continue
            }

            // Search contacts
            let contacts = await parser.searchContacts(query: name)
            if let bestMatch = contacts.first, !contacts.isEmpty {
                if let email = bestMatch.email {
                    emails.append(email)
                    print("✅ Matched '\(name)' to \(email)")
                } else {
                    print("⚠️ Contact '\(name)' found but has no email")
                }
            } else {
                print("⚠️ No contact found for '\(name)'")
            }
        }

        return emails
    }

    // MARK: - Event Clarification Handling

    private func handleEventClarification(transcript: String, entities: ExtractedEntities, missingField: String, completion: @escaping (AICalendarResponse) -> Void) {
        print("📝 Processing clarification for field: \(missingField)")
        print("📝 User response: \(transcript)")

        Task {
            // Create a mutable copy of entities to update
            var updatedEntities = entities

            // Update entities based on which field was missing
            switch missingField.lowercased() {
            case "attendees", "invitees", "participants":
                // Extract attendee names from the response
                let names = smartEventParser.extractAttendeeNames(from: transcript)
                if !names.isEmpty {
                    updatedEntities.attendeeNames.append(contentsOf: names)
                    print("✅ Added attendees: \(names.joined(separator: ", "))")
                }

            case "time", "when", "date":
                // Parse time from the response
                if let time = smartEventParser.extractTime(from: transcript) {
                    updatedEntities.time = time
                    print("✅ Set time to: \(time)")
                }

            case "location", "where", "place":
                // Extract location from the response
                if let location = smartEventParser.extractLocation(from: transcript) {
                    updatedEntities.location = location
                    print("✅ Set location to: \(location)")
                }

            case "title", "name":
                // Use the response as the title
                let title = smartEventParser.generateTitle(from: transcript, eventType: nil)
                updatedEntities.title = title
                print("✅ Set title to: \(title ?? "nil")")

            default:
                print("⚠️ Unknown missing field: \(missingField)")
            }

            // Remove the field we just filled from missing fields
            updatedEntities.missingFields.removeAll { $0.lowercased() == missingField.lowercased() }

            // Check if there are still missing required fields
            let requiredFields = ["title", "time"]
            let stillMissing = requiredFields.filter { field in
                switch field {
                case "title": return updatedEntities.title == nil
                case "time": return updatedEntities.time == nil
                default: return false
                }
            }

            if !stillMissing.isEmpty {
                // Still need more information
                let nextMissingField = stillMissing.first!
                updatedEntities.missingFields = stillMissing

                print("⏭️ Still missing fields: \(stillMissing.joined(separator: ", "))")
                print("❓ Asking about next field: \(nextMissingField)")

                await MainActor.run {
                    self.conversationState = .creatingEvent(updatedEntities, missingField: nextMissingField)
                    print("💾 Updated conversation state to .creatingEvent with field: \(nextMissingField)")
                }

                // Generate next question
                let question = generateClarificationQuestion(for: nextMissingField, entities: updatedEntities)
                let response = AICalendarResponse(message: question)

                await MainActor.run {
                    self.isProcessing = false
                    completion(response)
                }

            } else {
                // We have all required fields - create the event
                print("✅ All required fields filled, creating event...")

                guard let calendarCommand = await convertToCalendarCommand(updatedEntities) else {
                    let errorResponse = AICalendarResponse(message: "Sorry, I couldn't create that event. Please try again.")
                    await MainActor.run {
                        self.conversationState = .idle
                        print("🔄 Reset conversation state to .idle (conversion error)")
                        self.isProcessing = false
                        completion(errorResponse)
                    }
                    return
                }

                // Generate confirmation message
                let confirmation = generateEventConfirmation(updatedEntities)
                let response = AICalendarResponse(message: confirmation, command: calendarCommand)

                await MainActor.run {
                    self.conversationState = .idle
                    print("🔄 Reset conversation state to .idle (event created)")
                    self.isProcessing = false
                    completion(response)
                }
            }
        }
    }

    private func generateClarificationQuestion(for field: String, entities: ExtractedEntities) -> String {
        switch field.lowercased() {
        case "title", "name":
            return "What would you like to call this event?"
        case "time", "when", "date":
            return "When should this event be scheduled?"
        case "attendees", "invitees", "participants":
            return "Who should I invite to this event?"
        case "location", "where", "place":
            return "Where will this event take place?"
        default:
            return "Can you provide more details about the \(field)?"
        }
    }

    private func generateEventConfirmation(_ entities: ExtractedEntities) -> String {
        var parts: [String] = []

        if let title = entities.title {
            parts.append(title)
        }

        if !entities.attendeeNames.isEmpty {
            parts.append("with \(entities.attendeeNames.joined(separator: ", "))")
        }

        if let time = entities.time {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append("on \(formatter.string(from: time))")
        }

        if let location = entities.location {
            parts.append("at \(location)")
        }

        let confirmation = "Got it! Creating \(parts.joined(separator: " "))"
        return confirmation
    }

    // MARK: - Query Handling

    private func handleQuery(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async throws {
        print("📅 Handling calendar query: \(transcript)")

        // Extract time range from query
        let (startDate, endDate) = extractTimeRange(from: transcript)
        print("📅 Query time range: \(startDate) to \(endDate)")

        // Filter events in the specified time range
        let relevantEvents = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }.sorted { $0.startDate < $1.startDate }

        print("📅 Found \(relevantEvents.count) events in range")

        // Generate natural language response using AI (with retry and fallback)
        let responseText: String
        do {
            let prompt = generateQueryPrompt(transcript: transcript, events: relevantEvents, startDate: startDate, endDate: endDate)
            let estimatedInputTokens = prompt.split(separator: " ").count
            print("📊 Estimated input tokens: ~\(estimatedInputTokens) words")

            // Try with retry logic for network issues
            // Reduced maxTokens from 300 to 150 for faster/cheaper responses
            let rawResponse = try await retryWithBackoff(maxRetries: 2, initialDelay: 1.0) {
                try await self.parser.generateText(prompt: prompt, maxTokens: 150)
            }

            let estimatedOutputTokens = rawResponse.split(separator: " ").count
            print("🤖 Raw LLM response (\(estimatedOutputTokens) words): \(rawResponse)")

            // Strip out any bulleted/numbered lists from LLM response
            let withoutLists = stripListsFromResponse(rawResponse)

            // Strip out dates from the response
            responseText = stripDatesFromResponse(withoutLists)
            print("✅ Cleaned response: \(responseText)")
        } catch {
            print("⚠️ LLM query generation failed: \(error.localizedDescription)")
            print("📝 Using simple fallback response")
            // Fallback to simple text-based response
            responseText = generateSimpleQueryResponse(events: relevantEvents, startDate: startDate, endDate: endDate)
        }

        // Convert events to EventResult format
        let eventResults = relevantEvents.map { event in
            EventResult(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                source: event.source.rawValue,
                color: nil
            )
        }

        let command = CalendarCommand(
            type: .queryEvents,
            queryStartDate: startDate,
            queryEndDate: endDate
        )

        let response = AICalendarResponse(
            message: responseText,
            command: command,
            eventResults: eventResults
        )

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func stripDatesFromResponse(_ text: String) -> String {
        var result = text

        // Remove common date patterns that might appear before/after times
        let datePatterns = [
            // "on [Month] [Day]" or "on [Month] [Day], [Year]" - with optional "st/nd/rd/th"
            #"\bon\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+"#,
            #"\bon\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+"#,

            // Just "[Month] [Day]" anywhere - without "on", with optional comma/year
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+(?=at)"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+(?=at)"#,

            // "[Month] [Day]," with comma (more general)
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?,\s+"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?,\s+"#,

            // "on [Weekday]" patterns
            #"\bon\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+"#,

            // Numeric date patterns like "1/14" or "01/14/2025"
            #"\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\s+"#,

            // "[Month] [Day]" without comma, followed by space and "at"
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?\s+(?=at\s+\d)"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?\s+(?=at\s+\d)"#
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        // Clean up extra spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🧹 After date stripping: \(result)")
        return result
    }

    private func stripListsFromResponse(_ text: String) -> String {
        print("📥 Input to stripListsFromResponse: \(text)")

        // Split into lines
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        var foundListSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip lines that are bulleted or numbered lists
            // Patterns: "- Event", "• Event", "* Event", "1. Event", "2) Event", "**Event**"
            let isBulletedList = trimmed.hasPrefix("-") ||
                                 trimmed.hasPrefix("•") ||
                                 trimmed.hasPrefix("*") ||
                                 trimmed.hasPrefix("–") ||  // en dash
                                 trimmed.hasPrefix("—")     // em dash
            let isNumberedList = trimmed.range(of: #"^\d+[\.\)\:]"#, options: .regularExpression) != nil

            // Also detect "Here's" or "Here are" or "Schedule:" which often precede lists
            let isListHeader = trimmed.lowercased().contains("here's your") ||
                              trimmed.lowercased().contains("here are") ||
                              trimmed.lowercased().hasPrefix("schedule:") ||
                              trimmed.lowercased().hasPrefix("events:")

            if isBulletedList || isNumberedList {
                print("🗑️ Removing list line: \(trimmed)")
                foundListSection = true
            } else if isListHeader && foundListSection {
                print("🗑️ Removing list header: \(trimmed)")
            } else if !trimmed.isEmpty {
                cleanedLines.append(line)
            }
        }

        // Join back and clean up extra whitespace
        let result = cleanedLines.joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("📤 Output from stripListsFromResponse: \(result)")
        return result
    }

    private func extractTimeRange(from text: String) -> (start: Date, end: Date) {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Today (many variations)
        if lowercased.contains("today") ||
           lowercased.contains("my day") ||
           lowercased.contains("this morning") ||
           lowercased.contains("this afternoon") ||
           lowercased.contains("this evening") ||
           lowercased.contains("tonight") {
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // Tomorrow
        if lowercased.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let startOfDay = calendar.startOfDay(for: tomorrow)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // Yesterday (for queries about past)
        if lowercased.contains("yesterday") {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfDay = calendar.startOfDay(for: yesterday)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // This week
        if lowercased.contains("this week") || (lowercased.contains("week") && !lowercased.contains("next")) {
            let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        }

        // Next week
        if lowercased.contains("next week") {
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now)!
            let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: nextWeek).date!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        }

        // This month
        if lowercased.contains("this month") || lowercased.contains("month") {
            let startOfMonth = calendar.dateComponents([.year, .month], from: now)
            let startDate = calendar.date(from: startOfMonth)!
            let endDate = calendar.date(byAdding: DateComponents(month: 1), to: startDate)!
            return (startDate, endDate)
        }

        // Specific day names (Monday, Tuesday, etc.)
        let weekdays = ["monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7, "sunday": 1]
        for (dayName, targetWeekday) in weekdays {
            if lowercased.contains(dayName) {
                // Find next occurrence of this weekday
                var targetDate = now
                while calendar.component(.weekday, from: targetDate) != targetWeekday {
                    targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
                }
                let startOfDay = calendar.startOfDay(for: targetDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
            }
        }

        // Default: today
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return (startOfDay, endOfDay)
    }

    private func generateSimpleQueryResponse(events: [UnifiedEvent], startDate: Date, endDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(startDate)
        let isTomorrow = calendar.isDateInTomorrow(startDate)
        let isThisWeek = calendar.isDate(startDate, equalTo: Date(), toGranularity: .weekOfYear)

        // Greeting based on time reference
        var greeting = ""
        if isToday {
            let hour = calendar.component(.hour, from: Date())
            if hour < 12 {
                greeting = "Good morning! "
            } else if hour < 17 {
                greeting = "Good afternoon! "
            } else {
                greeting = "Good evening! "
            }
        }

        let timeReferenceDate = isToday ? "today" : (isTomorrow ? "tomorrow" : "on \(dateFormatter.string(from: startDate))")

        // Empty schedule
        if events.isEmpty {
            if isToday {
                return "\(greeting)You have a clear schedule today. Enjoy your free time!"
            } else {
                return "You don't have any events \(timeReferenceDate). Your schedule is clear."
            }
        }

        let eventCount = events.count
        let eventWord = eventCount == 1 ? "event" : "events"

        // Opening
        var response = "\(greeting)Here's what your day looks like. "

        // Describe events conversationally
        if eventCount == 1 {
            let event = events[0]
            let time = timeFormatter.string(from: event.startDate)
            response += "You have \(event.title) at \(time)"
            if let location = event.location, !location.isEmpty {
                response += " at \(location)"
            }
            response += "."
        } else if eventCount == 2 {
            let first = events[0]
            let second = events[1]
            let time1 = timeFormatter.string(from: first.startDate)
            let time2 = timeFormatter.string(from: second.startDate)

            response += "You start with \(first.title) at \(time1), "
            response += "followed by \(second.title) at \(time2)."
        } else {
            // 3+ events
            let first = events[0]
            let last = events[eventCount - 1]
            let time1 = timeFormatter.string(from: first.startDate)
            let timeLast = timeFormatter.string(from: last.startDate)

            response += "You have \(eventCount) events. "
            response += "You start with \(first.title) at \(time1)"

            // Middle events
            if eventCount > 2 {
                let middle = events[1..<eventCount-1]
                for event in middle {
                    let time = timeFormatter.string(from: event.startDate)
                    response += ", followed by \(event.title) at \(time)"
                }
            }

            response += ", and wrap up with \(last.title) at \(timeLast)."
        }

        // Closing statement
        if isToday {
            let hour = calendar.component(.hour, from: Date())
            if hour < 12 {
                response += " Have a productive day!"
            } else if hour < 17 {
                response += " You've got this!"
            } else {
                response += " Finish strong!"
            }
        } else if isTomorrow {
            response += " Get some rest tonight!"
        } else {
            response += " Mark your calendar!"
        }

        return response
    }

    private func generateQueryPrompt(transcript: String, events: [UnifiedEvent], startDate: Date, endDate: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        // Limit to top 10 events to reduce token usage
        let limitedEvents = Array(events.prefix(10))
        let hasMoreEvents = events.count > 10

        var eventsDescription = ""
        if limitedEvents.isEmpty {
            eventsDescription = "No events"
        } else {
            eventsDescription = limitedEvents.map { event in
                let timeStr = timeFormatter.string(from: event.startDate)
                return "\(event.title) at \(timeStr)"
            }.joined(separator: ", ")
            if hasMoreEvents {
                eventsDescription += " (+\(events.count - 10) more)"
            }
        }

        // Only add context if it exists and is relevant
        let contextPrompt = conversationContext.isEmpty ? "" : "Context: \(conversationContext.joined(separator: "; "))\n"

        return """
        \(contextPrompt)Q: "\(transcript)"
        Events: \(eventsDescription)

        Respond conversationally with greeting, event summary (TITLE + TIME only, no dates/lists), and closing. Natural flow, 1-2 sentences.
        """
    }

    // MARK: - Conversation Handling

    private func handleConversation(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async throws {
        print("💬 Handling general conversation: \(transcript)")

        // Generate a friendly conversational response (with fallback)
        let responseText: String
        do {
            let prompt = "User: \"\(transcript)\"\nRespond briefly and naturally as a calendar assistant."

            responseText = try await parser.generateText(prompt: prompt, maxTokens: 50)
        } catch {
            print("⚠️ LLM conversation generation failed: \(error.localizedDescription)")
            print("📝 Using simple fallback response")
            // Simple pattern-based fallback
            responseText = generateSimpleConversationResponse(transcript: transcript)
        }

        let response = AICalendarResponse(message: responseText)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func generateSimpleConversationResponse(transcript: String) -> String {
        let lowercased = transcript.lowercased()

        // Greetings
        if lowercased.contains("hello") || lowercased.contains("hi ") || lowercased.starts(with: "hi") {
            return "Hello! How can I help you with your calendar today?"
        }

        // Thanks
        if lowercased.contains("thank") {
            return "You're welcome! Let me know if you need anything else."
        }

        // Goodbye
        if lowercased.contains("bye") || lowercased.contains("goodbye") {
            return "Goodbye! Have a great day!"
        }

        // Help
        if lowercased.contains("help") {
            return "I can help you view your schedule, create events, and answer questions about your calendar. Just ask me anything!"
        }

        // Default
        return "I'm here to help with your calendar. Try asking 'What's on my schedule today?' or 'Create a meeting tomorrow at 2pm'."
    }

    // MARK: - Confirmation Flow Handling

    private func handleConfirmation(transcript: String, completion: @escaping (AICalendarResponse) -> Void) {
        let lowercased = transcript.lowercased()
        var response: AICalendarResponse

        let positiveKeywords = ["yes", "yep", "yeah", "correct", "confirm", "do it", "okay", "ok"]
        if positiveKeywords.contains(where: lowercased.contains) {
            if let commandToExecute = self.pendingCommand {
                print("✅ User confirmed action. Executing command.")
                response = AICalendarResponse(message: "Okay, done.", command: commandToExecute)
            } else {
                response = AICalendarResponse(message: "Sorry, I forgot what we were doing. Please start over.")
            }
        } else {
            print("❌ User cancelled action.")
            response = AICalendarResponse(message: "Okay, cancelling.")
        }

        resetConversationState()
        
        DispatchQueue.main.async {
            self.isProcessing = false
            completion(response)
        }
    }
    
    func resetConversationState() {
        self.pendingCommand = nil
        self.conversationState = .idle
        self.conversationContext.removeAll()
        self.lastQueryTimeRange = nil
        self.lastQueryEvents.removeAll()
        print("🔄 Conversation state and context reset to idle.")
    }

    // MARK: - Helper Methods

    private func commandRequiresConfirmation(_ command: CalendarCommand) -> Bool {
        switch command.type {
        case .createEvent, .deleteEvent, .updateEvent, .rescheduleEvent, .clearSchedule, .moveEvent:
            return true
        default:
            return false
        }
    }

    private func generateConfirmationMessage(for command: CalendarCommand) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        switch command.type {
        case .createEvent:
            let title = command.title ?? "your event"
            if let date = command.startDate {
                return "So you want me to create an event titled '\(title)' for \(formatter.string(from: date))?"
            } else {
                return "So you want me to create an event titled '\(title)'?"
            }
        case .deleteEvent:
            let title = command.searchQuery ?? "this event"
            return "Are you sure you want to delete '\(title)'?"
        default:
            return "Are you sure you want to proceed?"
        }
    }
    
    private func generateResponseMessage(for command: CalendarCommand) -> String {
        switch command.type {
        case .createEvent:
            return "Okay, I'll create an event for '\(command.title ?? "your event")'..."
        case .queryEvents:
            return "Let me check your calendar..."
        default:
            return "Got it, I'll take care of that..."
        }
    }

}


