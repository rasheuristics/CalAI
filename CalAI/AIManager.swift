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
        let apiKey = Config.hasValidAPIKey ? Config.anthropicAPIKey : "placeholder-key"
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    func processVoiceCommand(_ transcript: String, completion: @escaping (AIResponse) -> Void) {
        isProcessing = true

        // Check if API key is configured
        guard Config.hasValidAPIKey else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(AIResponse(
                    action: .unknown,
                    eventTitle: nil,
                    startDate: nil,
                    endDate: nil,
                    message: "Please configure your Anthropic API key in Settings to use AI features. Using basic parsing instead."
                ))
            }
            return
        }

        Task {
            do {
                let response = try await processWithClaude(transcript)
                await MainActor.run {
                    self.isProcessing = false
                    completion(response)
                }
            } catch {
                // Fallback to simple parsing if API fails
                let fallbackResponse = parseCommand(transcript)
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

        let message = MessageParameter.Message(role: .user, content: .text(transcript))

        let request = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 300,
            system: .text(systemPrompt)
        )

        let response = try await anthropicService.createMessage(request)

        guard case let .text(responseText) = response.content.first else {
            throw AIError.invalidResponse
        }

        return try parseClaudeResponse(responseText)
    }

    private func parseClaudeResponse(_ responseText: String) throws -> AIResponse {
        // Extract JSON from response
        guard let jsonData = responseText.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        guard let actionString = json["action"] as? String else {
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
        }

        if let endDateString = json["endDate"] as? String {
            let isoFormatter = ISO8601DateFormatter()
            endDate = isoFormatter.date(from: endDateString)
        }

        return AIResponse(
            action: action,
            eventTitle: title,
            startDate: startDate,
            endDate: endDate,
            message: message
        )
    }

    private func parseCommand(_ transcript: String) -> AIResponse {
        let lowercased = transcript.lowercased()

        if lowercased.contains("create") || lowercased.contains("schedule") || lowercased.contains("add") {
            return parseCreateEventCommand(transcript)
        } else if lowercased.contains("show") || lowercased.contains("what") || lowercased.contains("events") {
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
                message: "I can help you create events or show your calendar. Try saying 'create meeting tomorrow at 2pm' or 'show my events'."
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

        // Simple extraction - look for words after "create", "schedule", "add"
        if let createIndex = words.firstIndex(where: { ["create", "schedule", "add"].contains($0.lowercased()) }) {
            let remainingWords = Array(words.dropFirst(createIndex + 1))

            // Find time-related words and extract title before them
            let timeWords = ["at", "on", "tomorrow", "today", "next", "this"]
            if let timeIndex = remainingWords.firstIndex(where: { word in
                timeWords.contains { word.lowercased().contains($0) }
            }) {
                let titleWords = Array(remainingWords.prefix(timeIndex))
                return titleWords.isEmpty ? nil : titleWords.joined(separator: " ")
            } else {
                // No time words found, use first few words as title
                let titleWords = Array(remainingWords.prefix(3))
                return titleWords.isEmpty ? nil : titleWords.joined(separator: " ")
            }
        }

        return nil
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

        // Simple time extraction patterns
        let timePatterns = [
            ("at (\\d{1,2})\\s*(pm|PM)", { hour in hour + (transcript.lowercased().contains("pm") ? 12 : 0) }),
            ("at (\\d{1,2})\\s*(am|AM)", { hour in hour }),
            ("(\\d{1,2})\\s*(pm|PM)", { hour in hour + (transcript.lowercased().contains("pm") ? 12 : 0) }),
            ("(\\d{1,2})\\s*(am|AM)", { hour in hour })
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

                    return calendar.date(from: components)
                }
            }
        }

        // Default to current time if no specific time mentioned
        return date
    }
}