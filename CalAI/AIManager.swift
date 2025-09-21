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

    func processVoiceCommand(_ transcript: String, completion: @escaping (AIResponse) -> Void) {
        print("🧠 AI Manager processing transcript: \(transcript)")
        isProcessing = true

        // Check if API key is configured
        guard Config.hasValidAPIKey else {
            print("❌ No valid API key configured, using fallback parsing")
            let fallbackResponse = parseCommand(transcript)
            DispatchQueue.main.async {
                self.isProcessing = false
                print("🔄 Fallback response: \(fallbackResponse.message)")
                completion(fallbackResponse)
            }
            return
        }

        print("✅ API key configured, processing with \(Config.aiProvider.displayName)")
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
                print("❌ \(Config.aiProvider.displayName) API error: \(error), falling back to basic parsing")
                // Fallback to simple parsing if API fails
                let fallbackResponse = parseCommand(transcript)
                print("🔄 Fallback response: \(fallbackResponse.message)")
                await MainActor.run {
                    self.isProcessing = false
                    completion(fallbackResponse)
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
            "model": "gpt-4",
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

        // Try to extract JSON from response (Claude might wrap it in text)
        var jsonString = responseText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If response contains markdown-style JSON blocks, extract the JSON
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

        print("🔧 Extracted JSON string: \(jsonString)")

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

            var startDate: Date?
            var endDate: Date?

            if let startDateString = json["startDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                startDate = isoFormatter.date(from: startDateString)
                print("📅 Parsed start date: \(startDate?.description ?? "nil")")
            }

            if let endDateString = json["endDate"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                endDate = isoFormatter.date(from: endDateString)
                print("📅 Parsed end date: \(endDate?.description ?? "nil")")
            }

            let response = AIResponse(
                action: action,
                eventTitle: title,
                startDate: startDate,
                endDate: endDate,
                message: message
            )

            print("✅ Created AIResponse: action=\(action), title=\(title ?? "nil"), message=\(message)")
            return response

        } catch {
            print("❌ JSON parsing error: \(error)")
            throw AIError.invalidResponse
        }
    }

    private func parseCommand(_ transcript: String) -> AIResponse {
        let lowercased = transcript.lowercased()

        // More natural language patterns for creating events
        if lowercased.contains("create") || lowercased.contains("schedule") || lowercased.contains("add") ||
           lowercased.contains("i want to") || lowercased.contains("i need to") ||
           lowercased.contains("meeting") || lowercased.contains("appointment") ||
           lowercased.contains("event") {
            return parseCreateEventCommand(transcript)
        } else if lowercased.contains("show") || lowercased.contains("what") || lowercased.contains("events") ||
                  lowercased.contains("calendar") || lowercased.contains("today") ||
                  lowercased.contains("week") || lowercased.contains("month") {
            return AIResponse(
                action: .queryEvents,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "Showing your events"
            )
        } else {
            return AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "I can help you create events or show your calendar. Try saying 'I want to create a meeting tomorrow at 2pm' or 'show my events'."
            )
        }
    }

    private func parseCreateEventCommand(_ transcript: String) -> AIResponse {
        let title = extractEventTitle(from: transcript)
        let startDate = extractDate(from: transcript)

        if let title = title, let startDate = startDate {
            return AIResponse(
                action: .createEvent,
                eventTitle: title,
                startDate: startDate,
                endDate: nil,
                message: "Created event: \(title)"
            )
        } else {
            return AIResponse(
                action: .unknown,
                eventTitle: nil,
                startDate: nil,
                endDate: nil,
                message: "I need more details. Try saying 'create meeting tomorrow at 2pm'."
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