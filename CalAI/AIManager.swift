import Foundation
import SwiftAnthropic

enum AIAction {
    case createEvent
    case queryEvents
    case rescheduleEvent
    case cancelEvent
    case findTimeSlot
    case blockTime
    case extendEvent
    case moveEvent
    case batchOperation
    case unknown
}

enum AIError: Error {
    case invalidResponse
    case apiError
}

struct AIResponse {
    let action: AIAction
    let eventTitle: String?
    let startDate: Date?
    let endDate: Date?
    let message: String
    let requiresConfirmation: Bool
    let confirmationMessage: String?

    // Enhanced properties for multi-entity extraction
    let duration: TimeInterval?
    let attendees: [String]?
    let location: String?
    let originalEventId: String?
    let newStartDate: Date?
    let searchCriteria: String?
    let timeSlotDuration: TimeInterval?

    init(action: AIAction, eventTitle: String?, startDate: Date?, endDate: Date?, message: String, requiresConfirmation: Bool = false, confirmationMessage: String? = nil, duration: TimeInterval? = nil, attendees: [String]? = nil, location: String? = nil, originalEventId: String? = nil, newStartDate: Date? = nil, searchCriteria: String? = nil, timeSlotDuration: TimeInterval? = nil) {
        self.action = action
        self.eventTitle = eventTitle
        self.startDate = startDate
        self.endDate = endDate
        self.message = message
        self.requiresConfirmation = requiresConfirmation
        self.confirmationMessage = confirmationMessage
        self.duration = duration
        self.attendees = attendees
        self.location = location
        self.originalEventId = originalEventId
        self.newStartDate = newStartDate
        self.searchCriteria = searchCriteria
        self.timeSlotDuration = timeSlotDuration
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false

    private let anthropicService: AnthropicService
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        // Initialize with API key from config (use placeholder if empty)
        let apiKey = Config.hasValidAPIKey ? Config.currentAPIKey : "placeholder-key"
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    func validateAPIKey(completion: @escaping (Bool, String) -> Void) {
        guard Config.hasValidAPIKey else {
            completion(false, "No API key configured")
            return
        }

        print("🔑 Testing API key validity...")
        Task {
            do {
                let testMessage = MessageParameter.Message(role: .user, content: .text("Test"))
                let parameters = MessageParameter(
                    model: .claude35Sonnet,
                    messages: [testMessage],
                    maxTokens: 10
                )

                _ = try await anthropicService.createMessage(parameters)
                await MainActor.run {
                    completion(true, "API key is valid with proper permissions")
                }
            } catch {
                await MainActor.run {
                    let errorMessage = self.parseAPIError(error)
                    completion(false, errorMessage)
                }
            }
        }
    }

    private func parseAPIError(_ error: Error) -> String {
        let errorString = error.localizedDescription

        if errorString.contains("401") || errorString.contains("authentication") {
            return "Invalid API key - authentication failed"
        } else if errorString.contains("403") || errorString.contains("forbidden") {
            return "API key lacks required permissions"
        } else if errorString.contains("429") || errorString.contains("rate limit") {
            return "API rate limit exceeded or quota depleted"
        } else if errorString.contains("402") || errorString.contains("payment") {
            return "Payment required - check billing status"
        } else {
            return "API error: \(errorString)"
        }
    }

    func processVoiceCommand(_ transcript: String, completion: @escaping (AICalendarResponse) -> Void) {
        print("🧠 AI Manager processing transcript: \(transcript)")
        isProcessing = true

        // Validate transcript is not empty
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            print("❌ Empty transcript received")
            let errorResponse = AICalendarResponse(
                message: "I didn't catch that. Please try speaking again."
            )
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(errorResponse)
            }
            return
        }

        // Check if API key is configured
        guard Config.hasValidAPIKey else {
            print("❌ No valid API key configured, using fallback parsing")
            let fallbackResponse = parseCommandToCalendarResponse(cleanTranscript)
            DispatchQueue.main.async {
                self.isProcessing = false
                print("🔄 Fallback response: \(fallbackResponse.message)")
                completion(fallbackResponse)
            }
            return
        }

        print("✅ API key configured, processing with \(Config.aiProvider.displayName)")
        processWithRetryNew(transcript: cleanTranscript, maxRetries: 2, completion: completion)
    }

    private func processWithRetryNew(transcript: String, maxRetries: Int, currentAttempt: Int = 0, completion: @escaping (AICalendarResponse) -> Void) {
        Task {
            do {
                let response: AICalendarResponse
                switch Config.aiProvider {
                case .anthropic:
                    response = try await processWithClaudeNew(transcript)
                case .openai:
                    response = try await processWithOpenAIFunctionCalling(transcript)
                }
                print("✅ \(Config.aiProvider.displayName) response received: \(response.message)")
                await MainActor.run {
                    self.isProcessing = false
                    completion(response)
                }
            } catch {
                print("❌ \(Config.aiProvider.displayName) API error (attempt \(currentAttempt + 1)/\(maxRetries + 1)): \(error)")

                if currentAttempt < maxRetries {
                    print("🔄 Retrying in 1 second...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.processWithRetryNew(transcript: transcript, maxRetries: maxRetries, currentAttempt: currentAttempt + 1, completion: completion)
                    }
                } else {
                    // Try the alternative provider if primary fails
                    // Enhanced fallback handling
                    if Config.aiProvider == .anthropic && Config.hasOpenAIKey {
                        print("🔄 Anthropic failed, trying optimized OpenAI as fallback...")
                        do {
                            let response = try await self.processWithOpenAIFunctionCalling(transcript)
                            print("✅ OpenAI fallback successful: \(response.message)")
                            await MainActor.run {
                                self.isProcessing = false
                                completion(response)
                            }
                            return
                        } catch {
                            print("❌ OpenAI fallback also failed: \(error)")
                            let errorResponse = await self.handleOpenAIError(error, transcript: transcript)
                            await MainActor.run {
                                self.isProcessing = false
                                completion(errorResponse)
                            }
                            return
                        }
                    } else if Config.aiProvider == .openai && Config.hasAnthropicKey {
                        print("🔄 OpenAI failed, trying Anthropic as fallback...")
                        do {
                            let response = try await self.processWithClaudeNew(transcript)
                            print("✅ Anthropic fallback successful: \(response.message)")
                            await MainActor.run {
                                self.isProcessing = false
                                completion(response)
                            }
                            return
                        } catch {
                            print("❌ Anthropic fallback also failed: \(error)")
                        }
                    }

                    // Smart fallback based on the primary provider error
                    let smartFallbackResponse = await self.handleOpenAIError(error, transcript: transcript)
                    print("🔄 Smart fallback response: \(smartFallbackResponse.message)")
                    await MainActor.run {
                        self.isProcessing = false
                        completion(smartFallbackResponse)
                    }
                }
            }
        }
    }

    private func processWithRetry(transcript: String, maxRetries: Int, currentAttempt: Int = 0, completion: @escaping (AIResponse) -> Void) {
        Task {
            do {
                let response: AIResponse
                switch Config.aiProvider {
                case .anthropic:
                    response = try await processWithClaude(transcript)
                case .openai:
                    response = try await processWithOpenAI(transcript)
                }
                print("✅ \(Config.aiProvider.displayName) response received: \(response.message)")
                await MainActor.run {
                    self.isProcessing = false
                    completion(response)
                }
            } catch {
                print("❌ \(Config.aiProvider.displayName) API error (attempt \(currentAttempt + 1)/\(maxRetries + 1)): \(error)")

                if currentAttempt < maxRetries {
                    print("🔄 Retrying in 1 second...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.processWithRetry(transcript: transcript, maxRetries: maxRetries, currentAttempt: currentAttempt + 1, completion: completion)
                    }
                } else {
                    // Try the alternative provider if primary fails
                    if Config.aiProvider == .anthropic && Config.hasOpenAIKey {
                        print("🔄 Anthropic failed, trying OpenAI as fallback...")
                        do {
                            let response = try await self.processWithOpenAI(transcript)
                            print("✅ OpenAI fallback successful: \(response.message)")
                            await MainActor.run {
                                self.isProcessing = false
                                completion(response)
                            }
                            return
                        } catch {
                            print("❌ OpenAI fallback also failed: \(error)")
                        }
                    } else if Config.aiProvider == .openai && Config.hasAnthropicKey {
                        print("🔄 OpenAI failed, trying Anthropic as fallback...")
                        do {
                            let response = try await self.processWithClaude(transcript)
                            print("✅ Anthropic fallback successful: \(response.message)")
                            await MainActor.run {
                                self.isProcessing = false
                                completion(response)
                            }
                            return
                        } catch {
                            print("❌ Anthropic fallback also failed: \(error)")
                        }
                    }

                    print("❌ All AI providers failed, falling back to basic parsing")
                    // Fallback to simple parsing if all retries fail
                    let fallbackResponse = self.parseCommand(transcript)
                    print("🔄 Fallback response: \(fallbackResponse.message)")
                    await MainActor.run {
                        self.isProcessing = false
                        completion(fallbackResponse)
                    }
                }
            }
        }
    }

    private func processWithClaude(_ transcript: String) async throws -> AIResponse {
        let currentDate = dateFormatter.string(from: Date())

        let systemPrompt = """
        You are an advanced smart calendar assistant. Analyze user voice commands and extract comprehensive calendar information.

        Current date and time: \(currentDate)

        Respond with a JSON object containing:
        - "action": "createEvent", "queryEvents", "rescheduleEvent", "cancelEvent", "findTimeSlot", "blockTime", "extendEvent", "moveEvent", "batchOperation", or "unknown"
        - "title": event title (string or null)
        - "startDate": ISO 8601 date string or null
        - "endDate": ISO 8601 date string or null
        - "message": response message to user
        - "duration": duration in seconds (number or null)
        - "attendees": array of attendee names/emails (array or null)
        - "location": event location (string or null)
        - "originalEventId": for rescheduling/moving events (string or null)
        - "newStartDate": new time for rescheduled events (ISO 8601 or null)
        - "searchCriteria": for finding specific events (string or null)
        - "timeSlotDuration": duration for time slot searches in seconds (number or null)

        Enhanced Command Recognition:

        SCHEDULING OPERATIONS:
        - "Create/Schedule/Book/Add [event] [time] [attendees] [location]"
        - "Find me a 2-hour slot tomorrow" → findTimeSlot with timeSlotDuration: 7200
        - "Block 3 hours for deep work Friday morning" → blockTime with duration: 10800

        MODIFICATION OPERATIONS:
        - "Reschedule my 3pm meeting to tomorrow" → rescheduleEvent
        - "Move lunch to 1pm" → moveEvent
        - "Extend my current meeting by 30 minutes" → extendEvent
        - "Cancel my appointment with Dr. Smith" → cancelEvent

        BATCH OPERATIONS:
        - "Cancel all meetings after 5pm today" → batchOperation
        - "Move all Tuesday meetings to Wednesday" → batchOperation

        INTELLIGENT QUERIES:
        - "Find time for lunch with John between 12 and 2pm" → findTimeSlot
        - "When's my next free 2-hour block?" → findTimeSlot
        - "Show meetings with Sarah this week" → queryEvents with searchCriteria

        TIME PARSING:
        - Relative: tomorrow, today, next week, this Friday
        - Specific: 2pm, 3:30pm, 9 in the morning
        - Duration: 30 minutes, 2 hours, 45 mins
        - Ranges: between 12 and 2pm, before 5pm, after lunch

        ENTITY EXTRACTION:
        - Attendees: "with John", "invite Sarah and Mike"
        - Location: "at the office", "in conference room A", "downtown"
        - Duration: "for 2 hours", "30-minute meeting"

        Examples:
        "Reschedule my 3pm meeting to tomorrow at 2pm" → {"action":"rescheduleEvent","title":"meeting","startDate":"2024-01-16T15:00:00Z","newStartDate":"2024-01-17T14:00:00Z","message":"Rescheduled meeting to tomorrow at 2pm"}

        "Find me a 2-hour slot tomorrow morning" → {"action":"findTimeSlot","timeSlotDuration":7200,"startDate":"2024-01-17T09:00:00Z","endDate":"2024-01-17T12:00:00Z","message":"Finding 2-hour time slot for tomorrow morning"}

        "Schedule lunch with John and Sarah at noon in the cafeteria" → {"action":"createEvent","title":"lunch","startDate":"2024-01-16T12:00:00Z","endDate":"2024-01-16T13:00:00Z","attendees":["John","Sarah"],"location":"cafeteria","message":"Scheduled lunch with John and Sarah"}
        """

        print("📤 Sending request to Claude with transcript: \(transcript)")

        let message = MessageParameter.Message(role: .user, content: .text(transcript))

        let request = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 300,
            system: .text(systemPrompt)
        )

        let response = try await anthropicService.createMessage(request)
        print("📥 Received response from Claude")

        guard case let .text(responseText) = response.content.first else {
            print("❌ Invalid response format from Claude")
            throw AIError.invalidResponse
        }

        print("📋 Claude response text: \(responseText)")
        return try parseAIResponse(responseText)
    }

    private func processWithOpenAI(_ transcript: String) async throws -> AIResponse {
        let currentDate = dateFormatter.string(from: Date())

        let systemPrompt = """
        You are an advanced smart calendar assistant. Analyze user voice commands and extract comprehensive calendar information.

        Current date and time: \(currentDate)

        Respond with a JSON object containing:
        - "action": "createEvent", "queryEvents", "rescheduleEvent", "cancelEvent", "findTimeSlot", "blockTime", "extendEvent", "moveEvent", "batchOperation", or "unknown"
        - "title": event title (string or null)
        - "startDate": ISO 8601 date string or null
        - "endDate": ISO 8601 date string or null
        - "message": response message to user
        - "duration": duration in seconds (number or null)
        - "attendees": array of attendee names/emails (array or null)
        - "location": event location (string or null)
        - "originalEventId": for rescheduling/moving events (string or null)
        - "newStartDate": new time for rescheduled events (ISO 8601 or null)
        - "searchCriteria": for finding specific events (string or null)
        - "timeSlotDuration": duration for time slot searches in seconds (number or null)

        Enhanced Command Recognition:

        SCHEDULING OPERATIONS:
        - "Create/Schedule/Book/Add [event] [time] [attendees] [location]"
        - "Find me a 2-hour slot tomorrow" → findTimeSlot with timeSlotDuration: 7200
        - "Block 3 hours for deep work Friday morning" → blockTime with duration: 10800

        MODIFICATION OPERATIONS:
        - "Reschedule my 3pm meeting to tomorrow" → rescheduleEvent
        - "Move lunch to 1pm" → moveEvent
        - "Extend my current meeting by 30 minutes" → extendEvent
        - "Cancel my appointment with Dr. Smith" → cancelEvent

        BATCH OPERATIONS:
        - "Cancel all meetings after 5pm today" → batchOperation
        - "Move all Tuesday meetings to Wednesday" → batchOperation

        INTELLIGENT QUERIES:
        - "Find time for lunch with John between 12 and 2pm" → findTimeSlot
        - "When's my next free 2-hour block?" → findTimeSlot
        - "Show meetings with Sarah this week" → queryEvents with searchCriteria

        TIME PARSING:
        - Relative: tomorrow, today, next week, this Friday
        - Specific: 2pm, 3:30pm, 9 in the morning
        - Duration: 30 minutes, 2 hours, 45 mins
        - Ranges: between 12 and 2pm, before 5pm, after lunch

        ENTITY EXTRACTION:
        - Attendees: "with John", "invite Sarah and Mike"
        - Location: "at the office", "in conference room A", "downtown"
        - Duration: "for 2 hours", "30-minute meeting"

        Examples:
        "Reschedule my 3pm meeting to tomorrow at 2pm" → {"action":"rescheduleEvent","title":"meeting","startDate":"2024-01-16T15:00:00Z","newStartDate":"2024-01-17T14:00:00Z","message":"Rescheduled meeting to tomorrow at 2pm"}

        "Find me a 2-hour slot tomorrow morning" → {"action":"findTimeSlot","timeSlotDuration":7200,"startDate":"2024-01-17T09:00:00Z","endDate":"2024-01-17T12:00:00Z","message":"Finding 2-hour time slot for tomorrow morning"}

        "Schedule lunch with John and Sarah at noon in the cafeteria" → {"action":"createEvent","title":"lunch","startDate":"2024-01-16T12:00:00Z","endDate":"2024-01-16T13:00:00Z","attendees":["John","Sarah"],"location":"cafeteria","message":"Scheduled lunch with John and Sarah"}
        """

        print("📤 Sending request to OpenAI with transcript: \(transcript)")

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": transcript
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError
        }

        print("📥 Received response from OpenAI with status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ OpenAI API error: \(message)")
            }
            throw AIError.apiError
        }

        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("❌ Invalid response format from OpenAI")
            throw AIError.invalidResponse
        }

        print("📋 OpenAI response text: \(content)")
        return try parseAIResponse(content)
    }

    private func parseAIResponse(_ responseText: String) throws -> AIResponse {
        print("🔍 Parsing AI response: \(responseText)")

        // Validate response is not empty
        guard !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Empty AI response received")
            throw AIError.invalidResponse
        }

        // Try to extract JSON from response (Claude might wrap it in text)
        var jsonString = responseText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Enhanced JSON extraction with multiple fallback patterns
        if jsonString.contains("```json") {
            let components = jsonString.components(separatedBy: "```json")
            if components.count > 1 {
                let jsonPart = components[1].components(separatedBy: "```")[0]
                jsonString = jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if jsonString.contains("```") {
            let components = jsonString.components(separatedBy: "```")
            if components.count > 1 {
                jsonString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Try to find JSON object markers if no code blocks
        if !jsonString.hasPrefix("{") && jsonString.contains("{") {
            if let startIndex = jsonString.firstIndex(of: "{"),
               let endIndex = jsonString.lastIndex(of: "}") {
                jsonString = String(jsonString[startIndex...endIndex])
            }
        }

        print("🔧 Extracted JSON string: \(jsonString)")

        // Validate JSON string looks reasonable
        guard jsonString.hasPrefix("{") && jsonString.hasSuffix("}") else {
            print("❌ Invalid JSON format: missing braces")
            throw AIError.invalidResponse
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert to data")
            throw AIError.invalidResponse
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse JSON object")
                throw AIError.invalidResponse
            }

            print("✅ Parsed JSON: \(json)")

            guard let actionString = json["action"] as? String else {
                print("❌ No action found in JSON")
                throw AIError.invalidResponse
            }

            let action: AIAction
            switch actionString {
            case "createEvent":
                action = .createEvent
            case "queryEvents":
                action = .queryEvents
            default:
                action = .unknown
            }

            let title = json["title"] as? String
            let message = json["message"] as? String ?? "Task completed"

            // Validate createEvent has required fields
            if action == .createEvent {
                guard let eventTitle = title, !eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("❌ CreateEvent action missing title")
                    throw AIError.invalidResponse
                }
            }

            var startDate: Date?
            var endDate: Date?

            if let startDateString = json["startDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                startDate = isoFormatter.date(from: startDateString)
                print("📅 Parsed start date: \(startDate?.description ?? "nil")")

                // Validate start date is reasonable (not too far in past/future)
                if let date = startDate {
                    let calendar = Calendar.current
                    let now = Date()
                    let maxFuture = calendar.date(byAdding: .year, value: 2, to: now) ?? now
                    let maxPast = calendar.date(byAdding: .year, value: -1, to: now) ?? now

                    if date > maxFuture || date < maxPast {
                        print("⚠️ Start date outside reasonable range, using fallback")
                        startDate = calendar.date(byAdding: .hour, value: 1, to: now)
                    }
                }
            }

            if let endDateString = json["endDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                endDate = isoFormatter.date(from: endDateString)
                print("📅 Parsed end date: \(endDate?.description ?? "nil")")

                // Validate end date is after start date
                if let start = startDate, let end = endDate, end <= start {
                    print("⚠️ End date before start date, adjusting")
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start)
                }
            }

            // For createEvent, ensure we have a start date
            if action == .createEvent && startDate == nil {
                print("⚠️ CreateEvent missing start date, using default (1 hour from now)")
                startDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            }

            // Determine if confirmation is needed
            let needsConfirmation = action == .createEvent
            let confirmMessage = needsConfirmation ? generateConfirmationMessage(action: action, title: title, startDate: startDate, endDate: endDate) : nil

            let response = AIResponse(
                action: action,
                eventTitle: title,
                startDate: startDate,
                endDate: endDate,
                message: message,
                requiresConfirmation: needsConfirmation,
                confirmationMessage: confirmMessage
            )

            print("✅ Created AIResponse: action=\(action), title=\(title ?? "nil"), message=\(message)")
            return response

        } catch {
            print("❌ JSON parsing error: \(error)")
            throw AIError.invalidResponse
        }
    }

    private func generateConfirmationMessage(action: AIAction, title: String?, startDate: Date?, endDate: Date?) -> String {
        switch action {
        case .createEvent:
            let eventTitle = title ?? "event"
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            if let start = startDate {
                let startTime = formatter.string(from: start)
                if let end = endDate {
                    let endFormatter = DateFormatter()
                    endFormatter.timeStyle = .short
                    let endTime = endFormatter.string(from: end)
                    return "Create '\(eventTitle)' from \(startTime) to \(endTime)?"
                } else {
                    return "Create '\(eventTitle)' at \(startTime)?"
                }
            } else {
                return "Create '\(eventTitle)'?"
            }
        case .queryEvents:
            return "Show your upcoming events?"
        case .rescheduleEvent:
            return "Reschedule '\(title ?? "event")'?"
        case .cancelEvent:
            return "Cancel '\(title ?? "event")'?"
        case .findTimeSlot:
            return "Find available time slot?"
        case .blockTime:
            return "Block time for '\(title ?? "focus work")'?"
        case .extendEvent:
            return "Extend '\(title ?? "event")'?"
        case .moveEvent:
            return "Move '\(title ?? "event")'?"
        case .batchOperation:
            return "Perform batch operation?"
        case .unknown:
            return "Proceed with this action?"
        }
    }

    private func parseCommand(_ transcript: String) -> AIResponse {
        let lowercased = transcript.lowercased()

        // Enhanced regex patterns for complex command recognition

        // Reschedule/Move patterns
        if let rescheduleMatch = parseRescheduleCommand(transcript) {
            return rescheduleMatch
        }

        // Cancel patterns
        if let cancelMatch = parseCancelCommand(transcript) {
            return cancelMatch
        }

        // Find time slot patterns
        if let timeSlotMatch = parseFindTimeSlotCommand(transcript) {
            return timeSlotMatch
        }

        // Block time patterns
        if let blockTimeMatch = parseBlockTimeCommand(transcript) {
            return blockTimeMatch
        }

        // Extend event patterns
        if let extendMatch = parseExtendCommand(transcript) {
            return extendMatch
        }

        // Batch operation patterns
        if let batchMatch = parseBatchOperationCommand(transcript) {
            return batchMatch
        }

        // Check for availability queries
        if lowercased.contains("am i free") || lowercased.contains("are you free") ||
           lowercased.contains("free at") || lowercased.contains("available") ||
           lowercased.contains("busy") || lowercased.contains("do i have") {
            return parseAvailabilityQuery(transcript)
        }

        // Enhanced creation patterns with multi-entity extraction
        else if lowercased.contains("create") || lowercased.contains("schedule") || lowercased.contains("add") ||
           lowercased.contains("book") || lowercased.contains("i want to") || lowercased.contains("i need to") ||
           lowercased.contains("meeting") || lowercased.contains("appointment") ||
           lowercased.contains("event") || lowercased.contains("lunch") || lowercased.contains("dinner") {
            return parseEnhancedCreateEventCommand(transcript)
        }

        // Enhanced calendar queries with search criteria
        else if lowercased.contains("show") || lowercased.contains("what") || lowercased.contains("events") ||
                  lowercased.contains("calendar") || lowercased.contains("today") ||
                  lowercased.contains("week") || lowercased.contains("month") || lowercased.contains("with") {
            return parseEnhancedQueryCommand(transcript)
        } else {
            return AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "I can help you with advanced calendar operations. Try 'reschedule my 3pm meeting', 'find me a 2-hour slot tomorrow', or 'cancel all meetings after 5pm'.",
                requiresConfirmation: false,
                confirmationMessage: nil
            )
        }
    }

    private func parseAvailabilityQuery(_ transcript: String) -> AIResponse {
        let queryDate = extractDate(from: transcript)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        if let date = queryDate {
            let formattedDate = dateFormatter.string(from: date)
            return AIResponse(
                action: .queryEvents,
                eventTitle: nil,
                startDate: date,
                endDate: nil,
                message: "Checking your availability for \(formattedDate)",
                requiresConfirmation: false,
                confirmationMessage: nil
            )
        } else {
            return AIResponse(
                action: .queryEvents,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "Checking your calendar availability",
                requiresConfirmation: false,
                confirmationMessage: nil
            )
        }
    }

    private func parseCreateEventCommand(_ transcript: String) -> AIResponse {
        let title = extractEventTitle(from: transcript)
        let startDate = extractDate(from: transcript)

        if let title = title, let startDate = startDate {
            let confirmationMessage = generateConfirmationMessage(
                action: .createEvent,
                title: title,
                startDate: startDate,
                endDate: nil
            )

            return AIResponse(
                action: .createEvent,
                eventTitle: title,
                startDate: startDate,
                endDate: nil,
                message: "Created event: \(title)",
                requiresConfirmation: true,
                confirmationMessage: confirmationMessage
            )
        } else {
            return AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "I need more details. Try saying 'create meeting tomorrow at 2pm'.",
                requiresConfirmation: false,
                confirmationMessage: nil
            )
        }
    }

    private func extractEventTitle(from transcript: String) -> String? {
        let words = transcript.components(separatedBy: .whitespaces)
        let lowercased = transcript.lowercased()

        // Enhanced extraction for natural language patterns
        var startIndex: Int?

        // Look for various trigger words and phrases
        let triggerPatterns = [
            "create", "schedule", "add", "i want to create", "i want to schedule",
            "i need to create", "i need to schedule", "i want to", "i need to"
        ]

        for pattern in triggerPatterns {
            if let range = lowercased.range(of: pattern) {
                let patternEndIndex = transcript.distance(from: transcript.startIndex, to: range.upperBound)
                let wordsBeforePattern = transcript.prefix(patternEndIndex).components(separatedBy: .whitespaces)
                startIndex = wordsBeforePattern.count
                break
            }
        }

        // If no trigger found, look for direct mentions of meeting/appointment
        if startIndex == nil {
            if lowercased.contains("meeting") || lowercased.contains("appointment") || lowercased.contains("event") {
                // Find the context around these words
                for (index, word) in words.enumerated() {
                    if ["meeting", "appointment", "event"].contains(word.lowercased()) {
                        // Use words around this as context
                        startIndex = max(0, index - 2)
                        break
                    }
                }
            }
        }

        guard let start = startIndex, start < words.count else { return nil }

        let remainingWords = Array(words.dropFirst(start))

        // Find time-related words and extract title before them
        let timeWords = ["at", "on", "tomorrow", "today", "next", "this", "pm", "am", "o'clock"]
        if let timeIndex = remainingWords.firstIndex(where: { word in
            timeWords.contains { word.lowercased().contains($0) }
        }) {
            let titleWords = Array(remainingWords.prefix(timeIndex))
            let cleanedTitle = titleWords.joined(separator: " ")
                .replacingOccurrences(of: "create", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "schedule", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "add", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "a ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedTitle.isEmpty ? "meeting" : cleanedTitle
        } else {
            // No time words found, use first few words as title
            let titleWords = Array(remainingWords.prefix(4))
            let cleanedTitle = titleWords.joined(separator: " ")
                .replacingOccurrences(of: "create", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "schedule", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "add", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "a ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedTitle.isEmpty ? "meeting" : cleanedTitle
        }
    }

    private func extractDate(from transcript: String) -> Date? {
        let lowercased = transcript.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercased.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return extractTime(from: transcript, for: tomorrow)
        } else if lowercased.contains("today") {
            return extractTime(from: transcript, for: now)
        } else if lowercased.contains("next week") {
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return extractTime(from: transcript, for: nextWeek)
        } else {
            // Try to extract time for today
            return extractTime(from: transcript, for: now)
        }
    }

    private func extractTime(from transcript: String, for date: Date) -> Date? {
        let calendar = Calendar.current
        let lowercased = transcript.lowercased()

        // Enhanced time extraction patterns
        let timePatterns = [
            ("at (\\d{1,2})\\s*(pm|PM)", { hour in hour == 12 ? 12 : hour + 12 }),
            ("at (\\d{1,2})\\s*(am|AM)", { hour in hour == 12 ? 0 : hour }),
            ("(\\d{1,2})\\s*(pm|PM)", { hour in hour == 12 ? 12 : hour + 12 }),
            ("(\\d{1,2})\\s*(am|AM)", { hour in hour == 12 ? 0 : hour }),
            ("at (\\d{1,2}):(\\d{2})\\s*(pm|PM)", { hour in hour == 12 ? 12 : hour + 12 }),
            ("at (\\d{1,2}):(\\d{2})\\s*(am|AM)", { hour in hour == 12 ? 0 : hour }),
            ("(\\d{1,2}):(\\d{2})\\s*(pm|PM)", { hour in hour == 12 ? 12 : hour + 12 }),
            ("(\\d{1,2}):(\\d{2})\\s*(am|AM)", { hour in hour == 12 ? 0 : hour })
        ]

        for (pattern, hourTransform) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, options: [], range: NSRange(location: 0, length: transcript.count)) {

                let hourRange = Range(match.range(at: 1), in: transcript)!
                let hourString = String(transcript[hourRange])

                if let hour = Int(hourString) {
                    let adjustedHour = hourTransform(hour)
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.hour = adjustedHour
                    components.minute = 0

                    // Check for minutes if pattern includes them
                    if match.numberOfRanges > 3,
                       let minuteRange = Range(match.range(at: 2), in: transcript),
                       let minutes = Int(String(transcript[minuteRange])) {
                        components.minute = minutes
                    }

                    return calendar.date(from: components)
                }
            }
        }

        // Check for common time phrases
        if lowercased.contains("noon") || lowercased.contains("12 pm") {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 12
            components.minute = 0
            return calendar.date(from: components)
        }

        if lowercased.contains("midnight") || lowercased.contains("12 am") {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 0
            components.minute = 0
            return calendar.date(from: components)
        }

        // Default to a reasonable time (2 PM) if no specific time mentioned
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 14
        components.minute = 0
        return calendar.date(from: components)
    }

    // MARK: - Enhanced Command Parsing Functions

    private func parseRescheduleCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        // Regex patterns for reschedule commands
        let reschedulePatterns = [
            "reschedule.*?(\\w+).*?to (tomorrow|today|next \\w+)",
            "move.*?(\\w+).*?to (tomorrow|today|next \\w+)",
            "change.*?(\\w+).*?to (tomorrow|today|next \\w+)"
        ]

        for pattern in reschedulePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                let eventTitle = extractEventTitle(from: transcript) ?? "meeting"
                let newDate = extractDate(from: transcript)

                return AIResponse(
                    action: .rescheduleEvent,
                    eventTitle: eventTitle,
                    startDate: nil,
                    endDate: nil,
                    message: "Rescheduling \(eventTitle)",
                    requiresConfirmation: true,
                    confirmationMessage: "Reschedule \(eventTitle) to \(newDate?.description ?? "new time")?",
                    newStartDate: newDate
                )
            }
        }

        return nil
    }

    private func parseCancelCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        if lowercased.contains("cancel") || lowercased.contains("delete") || lowercased.contains("remove") {
            let eventTitle = extractEventTitle(from: transcript) ?? "event"

            return AIResponse(
                action: .cancelEvent,
                eventTitle: eventTitle,
                startDate: nil,
                endDate: nil,
                message: "Cancelling \(eventTitle)",
                requiresConfirmation: true,
                confirmationMessage: "Cancel \(eventTitle)?"
            )
        }

        return nil
    }

    private func parseFindTimeSlotCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        if lowercased.contains("find") && (lowercased.contains("time") || lowercased.contains("slot")) {
            let duration = extractDuration(from: transcript)
            let date = extractDate(from: transcript)

            return AIResponse(
                action: .findTimeSlot,
                eventTitle: nil,
                startDate: date,
                endDate: nil,
                message: "Finding available time slot",
                requiresConfirmation: false,
                confirmationMessage: nil,
                timeSlotDuration: duration
            )
        }

        return nil
    }

    private func parseBlockTimeCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        if lowercased.contains("block") && lowercased.contains("time") {
            let duration = extractDuration(from: transcript)
            let date = extractDate(from: transcript)
            let purpose = extractPurpose(from: transcript)

            return AIResponse(
                action: .blockTime,
                eventTitle: purpose ?? "Blocked time",
                startDate: date,
                endDate: nil,
                message: "Blocking time for \(purpose ?? "focus work")",
                requiresConfirmation: true,
                confirmationMessage: "Block \(duration ?? 3600) seconds for \(purpose ?? "focus work")?",
                duration: duration
            )
        }

        return nil
    }

    private func parseExtendCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        if lowercased.contains("extend") {
            let duration = extractDuration(from: transcript)
            let eventTitle = extractEventTitle(from: transcript) ?? "current meeting"

            return AIResponse(
                action: .extendEvent,
                eventTitle: eventTitle,
                startDate: nil,
                endDate: nil,
                message: "Extending \(eventTitle)",
                requiresConfirmation: true,
                confirmationMessage: "Extend \(eventTitle) by \(duration ?? 1800) seconds?",
                duration: duration
            )
        }

        return nil
    }

    private func parseBatchOperationCommand(_ transcript: String) -> AIResponse? {
        let lowercased = transcript.lowercased()

        if lowercased.contains("all") && (lowercased.contains("cancel") || lowercased.contains("move")) {
            let criteria = extractBatchCriteria(from: transcript)

            return AIResponse(
                action: .batchOperation,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "Performing batch operation",
                requiresConfirmation: true,
                confirmationMessage: "Perform batch operation on \(criteria ?? "selected events")?",
                searchCriteria: criteria
            )
        }

        return nil
    }

    private func parseEnhancedCreateEventCommand(_ transcript: String) -> AIResponse {
        let title = extractEventTitle(from: transcript)
        let startDate = extractDate(from: transcript)
        let attendees = extractAttendees(from: transcript)
        let location = extractLocation(from: transcript)
        let duration = extractDuration(from: transcript)

        let confirmationMessage = generateConfirmationMessage(
            action: .createEvent,
            title: title ?? "Event",
            startDate: startDate,
            endDate: nil
        )

        return AIResponse(
            action: .createEvent,
            eventTitle: title,
            startDate: startDate,
            endDate: nil,
            message: "Creating \(title ?? "event")",
            requiresConfirmation: true,
            confirmationMessage: confirmationMessage,
            duration: duration,
            attendees: attendees,
            location: location
        )
    }

    private func parseEnhancedQueryCommand(_ transcript: String) -> AIResponse {
        let searchCriteria = extractSearchCriteria(from: transcript)
        let date = extractDate(from: transcript)

        return AIResponse(
            action: .queryEvents,
            eventTitle: nil,
            startDate: date,
            endDate: nil,
            message: searchCriteria != nil ? "Searching for events with \(searchCriteria!)" : "Here are your events",
            requiresConfirmation: false,
            confirmationMessage: nil,
            searchCriteria: searchCriteria
        )
    }

    // MARK: - Multi-Entity Extraction Functions

    private func extractDuration(from transcript: String) -> TimeInterval? {
        let patterns = [
            "(\\d+)\\s*hours?": 3600,
            "(\\d+)\\s*hrs?": 3600,
            "(\\d+)\\s*minutes?": 60,
            "(\\d+)\\s*mins?": 60,
            "half\\s*hour": 1800,
            "thirty\\s*minutes": 1800,
            "quarter\\s*hour": 900,
            "fifteen\\s*minutes": 900
        ]

        for (pattern, multiplier) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                if pattern.contains("\\d+") {
                    let numberRange = match.range(at: 1)
                    if let range = Range(numberRange, in: transcript),
                       let number = Int(String(transcript[range])) {
                        return TimeInterval(number * multiplier)
                    }
                } else {
                    return TimeInterval(multiplier)
                }
            }
        }

        return nil
    }

    private func extractAttendees(from transcript: String) -> [String]? {
        let patterns = [
            "with ([\\w\\s,]+)",
            "invite ([\\w\\s,]+)",
            "including ([\\w\\s,]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                let attendeesRange = match.range(at: 1)
                if let range = Range(attendeesRange, in: transcript) {
                    let attendeesString = String(transcript[range])
                    return attendeesString.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            }
        }

        return nil
    }

    private func extractLocation(from transcript: String) -> String? {
        let patterns = [
            "at ([\\w\\s]+)",
            "in ([\\w\\s]+)",
            "@ ([\\w\\s]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                let locationRange = match.range(at: 1)
                if let range = Range(locationRange, in: transcript) {
                    return String(transcript[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return nil
    }

    private func extractPurpose(from transcript: String) -> String? {
        let patterns = [
            "for ([\\w\\s]+)",
            "to ([\\w\\s]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                let purposeRange = match.range(at: 1)
                if let range = Range(purposeRange, in: transcript) {
                    return String(transcript[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return nil
    }

    private func extractBatchCriteria(from transcript: String) -> String? {
        let patterns = [
            "after (\\d+\\w+)",
            "before (\\d+\\w+)",
            "on (\\w+day)",
            "this (\\w+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: transcript, range: NSRange(transcript.startIndex..., in: transcript)) {

                let criteriaRange = match.range(at: 1)
                if let range = Range(criteriaRange, in: transcript) {
                    return String(transcript[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return nil
    }

    private func extractSearchCriteria(from transcript: String) -> String? {
        if transcript.lowercased().contains("with ") {
            return extractAttendees(from: transcript)?.first
        }

        return nil
    }

    private func parseCommandToCalendarResponse(_ transcript: String) -> AICalendarResponse {
        let aiResponse = parseCommand(transcript)
        return convertAIResponseToCalendarResponse(aiResponse)
    }

    // MARK: - New OpenAI Function Calling Implementation

    private func processWithOpenAIFunctionCalling(_ transcript: String) async throws -> AICalendarResponse {
        let now = Date()
        let calendar = Calendar.current
        let timezone = TimeZone.current

        let isoFormatter = ISO8601DateFormatter()
        let currentDateTime = isoFormatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        let humanReadableDate = dateFormatter.string(from: now)

        let systemPrompt = """
        You are an expert calendar assistant with advanced natural language understanding trained on 150+ command variations. Parse ANY voice command for calendar operations with extreme accuracy.

        CURRENT CONTEXT:
        - Current Date/Time: \(currentDateTime) (\(humanReadableDate))
        - Timezone: \(timezone.identifier)
        - Day of Week: \(calendar.component(.weekday, from: now)) (1=Sunday, 7=Saturday)

        COMPREHENSIVE COMMAND UNDERSTANDING:

        🗓️ SCHEDULING VARIATIONS:
        - "Schedule/Book/Set up/Put/Add" + person/event + time
        - "Can you set an appointment" / "Find me an open slot" / "Block off time"
        - "Reschedule/Move/Push back/Change" + event + new time
        - Examples: "Book Dr. Lee for Tuesday at 3", "Find me a 30-minute window", "Move my call to 11 AM"

        🔍 CHECKING VARIATIONS:
        - "What's on my schedule" / "Show me" / "Do I have" / "Am I free"
        - "When's my next" / "How busy am I" / "What's my availability"
        - "Tell me if there are conflicts" / "Am I double-booked"
        - Examples: "Show me today's agenda", "Am I open tomorrow afternoon", "Check for overlaps"

        👥 ATTENDEE VARIATIONS:
        - "Invite/Add/Include" + people + "to" + event
        - "Send meeting request to" / "Share calendar with" / "Remove from"
        - "Forward the invite" / "Cancel and let them know"
        - Examples: "Add Sarah to lunch Friday", "Include Dr. Lee in the call", "Remove Alex from review"

        🛠️ MANAGEMENT VARIATIONS:
        - "Create recurring" / "Change duration" / "Extend by" / "Shorten to"
        - "Clear my schedule" / "Delete all" / "Move to new room"
        - "Set reminder" / "Turn off notifications" / "Rename to"
        - Examples: "Make Monday 9 AM weekly", "Clear Friday afternoon", "Extend by 15 minutes"

        📊 SUMMARY VARIATIONS:
        - "Summarize" / "Give me breakdown" / "How many hours" / "Show me all"
        - "What's my busiest day" / "List deadlines" / "Count meetings"
        - "Weekly summary" / "Travel plans" / "Check for overlaps"
        - Examples: "Recap my week", "Which day is most packed", "List October travel"

        PARSING RULES:
        1. ALWAYS convert relative times to absolute ISO 8601 timestamps
        2. Default meeting duration is 1 hour unless specified ("30-minute", "half-hour", "two hours")
        3. Handle all time references: "morning"=9AM, "afternoon"=2PM, "evening"=7PM, "lunch"=12PM
        4. Parse relative dates: "tomorrow", "next week", "this weekend", "next Friday"
        5. Extract duration words: "30-minute", "hour-long", "quick", "brief"=30min, "long"=2hr
        6. Identify action words: "schedule", "book", "move", "cancel", "extend", "invite"
        7. Recognize informal language: "grab lunch", "check-in", "touch base", "catch up"

        FUNCTION MAPPING:
        - create_event: schedule, book, add, set up, put, plan, reserve, block
        - query_events: show, what, list, tell me, when, upcoming, schedule for
        - check_availability: free, available, busy, open, conflicts, double-booked
        - reschedule_event: move, reschedule, push, change time, shift
        - extend_event: extend, make longer, add time, stretch
        - invite_attendees: invite, add people, include, send to
        - get_workload_summary: summarize, breakdown, how many, busiest, recap
        - show_help: help, commands, what can I do, what can you do, available commands, list commands

        CRITICAL: Extract ALL information - times, people, locations, durations, and intent.
        """

        let tools = [
            // Core scheduling
            [
                "type": "function",
                "function": [
                    "name": "create_event",
                    "description": "Schedule, book, add, set up, put, or plan any calendar event from natural language",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Event title extracted from command. Handle variants like 'meeting with', 'call with', 'lunch', etc."
                            ],
                            "startDate": [
                                "type": "string",
                                "description": "Start time in ISO 8601 format. Parse 'tomorrow at 3', 'next Friday morning', 'lunch time' etc."
                            ],
                            "endDate": [
                                "type": "string",
                                "description": "End time in ISO 8601 format. Extract from duration hints like '30-minute', 'hour-long', 'quick'"
                            ],
                            "location": [
                                "type": "string",
                                "description": "Location from context: 'conference room', 'office', 'Zoom', addresses"
                            ],
                            "notes": [
                                "type": "string",
                                "description": "Additional context, agenda, purpose mentioned"
                            ],
                            "participants": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "Names mentioned: 'with John', 'invite Sarah', attendee lists"
                            ]
                        ],
                        "required": ["title", "startDate"]
                    ]
                ]
            ],
            // Information queries
            [
                "type": "function",
                "function": [
                    "name": "query_events",
                    "description": "Show, list, find, tell about calendar events. Handles 'what's on my schedule', 'show me', etc.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "queryStartDate": [
                                "type": "string",
                                "description": "Start of search range. Parse 'today', 'this week', 'next month'"
                            ],
                            "queryEndDate": [
                                "type": "string",
                                "description": "End of search range for date ranges"
                            ],
                            "searchQuery": [
                                "type": "string",
                                "description": "Keywords to filter: person names, meeting types, locations"
                            ]
                        ]
                    ]
                ]
            ],
            // Availability checking
            [
                "type": "function",
                "function": [
                    "name": "check_availability",
                    "description": "Check if free, available, busy, open, or for conflicts/double-booking",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "startDate": [
                                "type": "string",
                                "description": "Start time to check availability"
                            ],
                            "endDate": [
                                "type": "string",
                                "description": "End time for availability window"
                            ]
                        ],
                        "required": ["startDate"]
                    ]
                ]
            ],
            // Event modifications
            [
                "type": "function",
                "function": [
                    "name": "reschedule_event",
                    "description": "Move, reschedule, push back, change time, or shift existing events",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "searchQuery": [
                                "type": "string",
                                "description": "Event to find: 'team meeting', 'my call', specific titles"
                            ],
                            "newStartDate": [
                                "type": "string",
                                "description": "New start time in ISO 8601 format"
                            ],
                            "newEndDate": [
                                "type": "string",
                                "description": "New end time if specified"
                            ]
                        ],
                        "required": ["searchQuery", "newStartDate"]
                    ]
                ]
            ],
            // Time management
            [
                "type": "function",
                "function": [
                    "name": "find_time_slot",
                    "description": "Find open slot, available time, or free window for scheduling",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "durationMinutes": [
                                "type": "integer",
                                "description": "Duration needed in minutes. Parse '30-minute', 'hour', 'brief', 'quick'"
                            ],
                            "preferredTimeRange": [
                                "type": "string",
                                "description": "Preferred time: 'morning', 'afternoon', 'tomorrow', 'this week'"
                            ],
                            "participants": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "People who need to attend for availability checking"
                            ]
                        ],
                        "required": ["durationMinutes"]
                    ]
                ]
            ],
            // Attendee management
            [
                "type": "function",
                "function": [
                    "name": "invite_attendees",
                    "description": "Invite, add, include people or send meeting requests",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "eventSearch": [
                                "type": "string",
                                "description": "Event to modify: 'lunch Friday', 'tomorrow's call', etc."
                            ],
                            "attendeesToAdd": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "People to invite or add"
                            ]
                        ],
                        "required": ["eventSearch", "attendeesToAdd"]
                    ]
                ]
            ],
            // Schedule management
            [
                "type": "function",
                "function": [
                    "name": "get_workload_summary",
                    "description": "Summarize, breakdown, analyze schedule. 'How busy', 'busiest day', 'recap week'",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "summaryType": [
                                "type": "string",
                                "description": "Type: 'weekly', 'daily', 'monthly', 'travel', 'meeting_count', 'busiest_day'"
                            ],
                            "timeRange": [
                                "type": "string",
                                "description": "Period: 'this week', 'next month', 'last week'"
                            ]
                        ],
                        "required": ["summaryType"]
                    ]
                ]
            ],
            // Help system
            [
                "type": "function",
                "function": [
                    "name": "show_help",
                    "description": "Show available voice commands when user says 'help', 'what can I do', 'commands', etc.",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ]
        ]

        print("📤 Sending optimized request to OpenAI GPT-4o with advanced function calling...")

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": "Parse this voice command for calendar action: \"\(transcript)\""
                ]
            ],
            "tools": tools,
            "tool_choice": "auto",
            "max_tokens": 500,
            "temperature": 0.1,
            "presence_penalty": 0.0,
            "frequency_penalty": 0.0
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError
        }

        print("📥 Received response from OpenAI with status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ OpenAI API error: \(message)")
            }
            throw AIError.apiError
        }

        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            print("❌ Invalid response format from OpenAI")
            throw AIError.invalidResponse
        }

        let content = message["content"] as? String ?? "I'll help you with that calendar task."

        // Check if tool was called (modern format)
        if let toolCalls = message["tool_calls"] as? [[String: Any]],
           let firstToolCall = toolCalls.first,
           let function = firstToolCall["function"] as? [String: Any],
           let functionName = function["name"] as? String,
           let argumentsString = function["arguments"] as? String,
           let argumentsData = argumentsString.data(using: .utf8),
           let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {

            print("🔧 Advanced function called: \(functionName)")
            print("📝 Function arguments: \(arguments)")

            let command = try createCalendarCommand(functionName: functionName, arguments: arguments)
            let requiresConfirmation = functionName == "create_event"
            let confirmationMessage = requiresConfirmation ? generateConfirmationMessageForCommand(command) : nil

            // Generate more natural response based on the command
            let naturalResponse = generateNaturalResponse(for: command, content: content)

            return AICalendarResponse(
                message: naturalResponse,
                command: command,
                requiresConfirmation: requiresConfirmation,
                confirmationMessage: confirmationMessage
            )
        } else {
            // No tool called, return conversational response
            return AICalendarResponse(message: content.isEmpty ? "I'm ready to help with your calendar." : content)
        }
    }

    private func processWithClaudeNew(_ transcript: String) async throws -> AICalendarResponse {
        // Use existing Claude implementation but convert to new response type
        let aiResponse = try await processWithClaude(transcript)
        return convertAIResponseToCalendarResponse(aiResponse)
    }

    private func createCalendarCommand(functionName: String, arguments: [String: Any]) throws -> CalendarCommand {
        let isoFormatter = ISO8601DateFormatter()

        switch functionName {
        case "create_event":
            guard let title = arguments["title"] as? String else {
                throw AIError.invalidResponse
            }

            let startDate = (arguments["startDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let endDate = (arguments["endDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let location = arguments["location"] as? String
            let notes = arguments["notes"] as? String
            let participants = arguments["participants"] as? [String]

            return CalendarCommand(
                type: .createEvent,
                title: title,
                startDate: startDate,
                endDate: endDate,
                location: location,
                notes: notes,
                participants: participants
            )

        case "query_events":
            let queryStartDate = (arguments["queryStartDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let queryEndDate = (arguments["queryEndDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let searchQuery = arguments["searchQuery"] as? String

            return CalendarCommand(
                type: .queryEvents,
                queryStartDate: queryStartDate,
                queryEndDate: queryEndDate,
                searchQuery: searchQuery
            )

        case "check_availability":
            let startDate = (arguments["startDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let endDate = (arguments["endDate"] as? String).flatMap { isoFormatter.date(from: $0) }

            return CalendarCommand(
                type: .checkAvailability,
                startDate: startDate,
                endDate: endDate
            )

        case "reschedule_event":
            let newStartDate = (arguments["newStartDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let newEndDate = (arguments["newEndDate"] as? String).flatMap { isoFormatter.date(from: $0) }
            let searchQuery = arguments["searchQuery"] as? String

            return CalendarCommand(
                type: .rescheduleEvent,
                searchQuery: searchQuery,
                newStartDate: newStartDate,
                newEndDate: newEndDate
            )

        case "find_time_slot":
            let durationMinutes = arguments["durationMinutes"] as? Int
            let preferredTimeRange = arguments["preferredTimeRange"] as? String
            let participants = arguments["participants"] as? [String]

            return CalendarCommand(
                type: .findTimeSlot,
                participants: participants,
                timeSlotDuration: durationMinutes,
                preferredTimeRange: preferredTimeRange
            )

        case "invite_attendees":
            let eventSearch = arguments["eventSearch"] as? String
            let attendeesToAdd = arguments["attendeesToAdd"] as? [String]

            return CalendarCommand(
                type: .inviteAttendees,
                searchQuery: eventSearch,
                attendeesToAdd: attendeesToAdd
            )

        case "get_workload_summary":
            let summaryType = arguments["summaryType"] as? String
            let timeRange = arguments["timeRange"] as? String

            return CalendarCommand(
                type: .getWorkloadSummary,
                summaryType: summaryType,
                preferredTimeRange: timeRange
            )

        case "show_help":
            return CalendarCommand(type: .showHelp)

        default:
            throw AIError.invalidResponse
        }
    }

    private func generateConfirmationMessageForCommand(_ command: CalendarCommand) -> String {
        switch command.type {
        case .createEvent:
            let eventTitle = command.title ?? "event"
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            if let start = command.startDate {
                let startTime = formatter.string(from: start)
                if let end = command.endDate {
                    let endFormatter = DateFormatter()
                    endFormatter.timeStyle = .short
                    let endTime = endFormatter.string(from: end)
                    return "Create '\(eventTitle)' from \(startTime) to \(endTime)?"
                } else {
                    return "Create '\(eventTitle)' at \(startTime)?"
                }
            } else {
                return "Create '\(eventTitle)'?"
            }
        case .queryEvents:
            return "Show your events?"
        case .checkAvailability:
            return "Check your availability?"
        default:
            return "Proceed with this action?"
        }
    }

    private func convertAIResponseToCalendarResponse(_ aiResponse: AIResponse) -> AICalendarResponse {
        let command: CalendarCommand?

        switch aiResponse.action {
        case .createEvent:
            command = CalendarCommand(
                type: .createEvent,
                title: aiResponse.eventTitle,
                startDate: aiResponse.startDate,
                endDate: aiResponse.endDate,
                location: aiResponse.location,
                participants: aiResponse.attendees
            )
        case .queryEvents:
            command = CalendarCommand(
                type: .queryEvents,
                queryStartDate: aiResponse.startDate,
                queryEndDate: aiResponse.endDate,
                searchQuery: aiResponse.searchCriteria
            )
        default:
            command = nil
        }

        return AICalendarResponse(
            message: aiResponse.message,
            command: command,
            requiresConfirmation: aiResponse.requiresConfirmation,
            confirmationMessage: aiResponse.confirmationMessage
        )
    }

    // MARK: - Enhanced Response Generation

    private func generateNaturalResponse(for command: CalendarCommand, content: String) -> String {
        switch command.type {
        case .createEvent:
            let title = command.title ?? "event"
            if let startDate = command.startDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let timeString = formatter.string(from: startDate)
                return "I'll create '\(title)' for \(timeString). Please confirm to proceed."
            } else {
                return "I'll create '\(title)' for you. Please confirm to proceed."
            }

        case .queryEvents:
            if let searchQuery = command.searchQuery {
                return "I'll search for events matching '\(searchQuery)'."
            } else {
                return "I'll show your upcoming events."
            }

        case .checkAvailability:
            if let startDate = command.startDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let timeString = formatter.string(from: startDate)
                return "I'll check your availability for \(timeString)."
            } else {
                return "I'll check your availability."
            }

        default:
            return content.isEmpty ? "Task completed successfully." : content
        }
    }

    // MARK: - Enhanced Error Handling

    private func handleOpenAIError(_ error: Error, transcript: String) async -> AICalendarResponse {
        print("🚨 OpenAI API error occurred: \(error)")

        // Check if it's a network error
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return AICalendarResponse(message: "No internet connection. Please check your network and try again.")
            case .timedOut:
                return AICalendarResponse(message: "Request timed out. Please try again.")
            default:
                return AICalendarResponse(message: "Network error occurred. Please try again.")
            }
        }

        // Check for API key issues
        if error.localizedDescription.contains("401") || error.localizedDescription.contains("authentication") {
            return AICalendarResponse(message: "API authentication failed. Please check your OpenAI API key in settings.")
        }

        // Check for rate limiting
        if error.localizedDescription.contains("429") || error.localizedDescription.contains("rate limit") {
            return AICalendarResponse(message: "Too many requests. Please wait a moment and try again.")
        }

        // Fallback to local parsing
        print("🔄 Falling back to local command parsing...")
        return parseCommandToCalendarResponse(transcript)
    }
}