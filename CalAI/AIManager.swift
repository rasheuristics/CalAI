import Foundation
import SwiftAnthropic

enum AIAction {
    case createEvent
    case queryEvents
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

    init(action: AIAction, eventTitle: String?, startDate: Date?, endDate: Date?, message: String, requiresConfirmation: Bool = false, confirmationMessage: String? = nil) {
        self.action = action
        self.eventTitle = eventTitle
        self.startDate = startDate
        self.endDate = endDate
        self.message = message
        self.requiresConfirmation = requiresConfirmation
        self.confirmationMessage = confirmationMessage
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

    func processVoiceCommand(_ transcript: String, completion: @escaping (AIResponse) -> Void) {
        print("🧠 AI Manager processing transcript: \(transcript)")
        isProcessing = true

        // Validate transcript is not empty
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            print("❌ Empty transcript received")
            let errorResponse = AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
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
            let fallbackResponse = parseCommand(cleanTranscript)
            DispatchQueue.main.async {
                self.isProcessing = false
                print("🔄 Fallback response: \(fallbackResponse.message)")
                completion(fallbackResponse)
            }
            return
        }

        print("✅ API key configured, processing with \(Config.aiProvider.displayName)")
        processWithRetry(transcript: cleanTranscript, maxRetries: 2, completion: completion)
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
        You are a smart calendar assistant. Analyze user voice commands and extract calendar event information.

        Current date and time: \(currentDate)

        Respond with a JSON object containing:
        - "action": "createEvent", "queryEvents", or "unknown"
        - "title": event title (string or null)
        - "startDate": ISO 8601 date string or null
        - "endDate": ISO 8601 date string or null (optional)
        - "message": response message to user

        For date parsing:
        - "tomorrow" = next day
        - "today" = current day
        - "next week" = same day next week
        - Parse times like "2pm", "at 3", "9 in the morning"
        - Default duration is 1 hour if no end time specified

        Examples:
        "Create meeting tomorrow at 2pm" → {"action":"createEvent","title":"meeting","startDate":"2024-01-16T14:00:00Z","endDate":"2024-01-16T15:00:00Z","message":"Created meeting for tomorrow at 2pm"}

        "Show my events" → {"action":"queryEvents","title":null,"startDate":null,"endDate":null,"message":"Here are your upcoming events"}
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
        You are a smart calendar assistant. Analyze user voice commands and extract calendar event information.

        Current date and time: \(currentDate)

        Respond with a JSON object containing:
        - "action": "createEvent", "queryEvents", or "unknown"
        - "title": event title (string or null)
        - "startDate": ISO 8601 date string or null
        - "endDate": ISO 8601 date string or null (optional)
        - "message": response message to user

        For date parsing:
        - "tomorrow" = next day
        - "today" = current day
        - "next week" = same day next week
        - Parse times like "2pm", "at 3", "9 in the morning"
        - Default duration is 1 hour if no end time specified

        Examples:
        "Create meeting tomorrow at 2pm" → {"action":"createEvent","title":"meeting","startDate":"2024-01-16T14:00:00Z","endDate":"2024-01-16T15:00:00Z","message":"Created meeting for tomorrow at 2pm"}

        "Show my events" → {"action":"queryEvents","title":null,"startDate":null,"endDate":null,"message":"Here are your upcoming events"}
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
        case .unknown:
            return "Proceed with this action?"
        }
    }

    private func parseCommand(_ transcript: String) -> AIResponse {
        let lowercased = transcript.lowercased()

        // Check for availability queries first
        if lowercased.contains("am i free") || lowercased.contains("are you free") ||
           lowercased.contains("free at") || lowercased.contains("available") ||
           lowercased.contains("busy") || lowercased.contains("do i have") {
            return parseAvailabilityQuery(transcript)
        }
        // More natural language patterns for creating events
        else if lowercased.contains("create") || lowercased.contains("schedule") || lowercased.contains("add") ||
           lowercased.contains("i want to") || lowercased.contains("i need to") ||
           lowercased.contains("meeting") || lowercased.contains("appointment") ||
           lowercased.contains("event") {
            return parseCreateEventCommand(transcript)
        }
        // Calendar queries
        else if lowercased.contains("show") || lowercased.contains("what") || lowercased.contains("events") ||
                  lowercased.contains("calendar") || lowercased.contains("today") ||
                  lowercased.contains("week") || lowercased.contains("month") {
            return AIResponse(
                action: .queryEvents,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "Here are your events",
                requiresConfirmation: false,
                confirmationMessage: nil
            )
        } else {
            return AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "I can help you create events or show your calendar. Try saying 'I want to create a meeting tomorrow at 2pm' or 'show my events'.",
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
}