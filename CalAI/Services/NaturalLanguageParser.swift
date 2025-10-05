import Foundation
import SwiftAnthropic

/// Parses natural language input into structured event data
class NaturalLanguageParser {
    private let anthropicService: AnthropicService
    private let calendar = Calendar.current

    init() {
        let apiKey = Config.hasValidAPIKey ? Config.currentAPIKey : "placeholder-key"
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    /// Parse natural language text into a structured event
    func parseEvent(from text: String, referenceDate: Date = Date()) async throws -> ParsedEvent {
        let prompt = buildParsePrompt(text: text, referenceDate: referenceDate)

        let message = MessageParameter.Message(role: .user, content: .text(prompt))
        let parameters = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 500
        )

        let response = try await anthropicService.createMessage(parameters)
        return try parseResponse(response, referenceDate: referenceDate)
    }

    /// Parse multiple events from text (e.g., "Meeting at 2pm and dinner at 7pm")
    func parseMultipleEvents(from text: String, referenceDate: Date = Date()) async throws -> [ParsedEvent] {
        let prompt = buildMultiEventParsePrompt(text: text, referenceDate: referenceDate)

        let message = MessageParameter.Message(role: .user, content: .text(prompt))
        let parameters = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 800
        )

        let response = try await anthropicService.createMessage(parameters)
        return try parseMultipleResponse(response, referenceDate: referenceDate)
    }

    // MARK: - Prompt Building

    private func buildParsePrompt(text: String, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short

        return """
        Parse this natural language event into structured JSON:
        "\(text)"

        Reference date/time: \(formatter.string(from: referenceDate))

        Extract:
        - title: Event name
        - startTime: ISO8601 datetime
        - duration: Minutes (default 60 if not specified)
        - location: Location if mentioned
        - attendees: Array of people if mentioned
        - isAllDay: Boolean
        - recurrence: "none", "daily", "weekly", "monthly" if mentioned

        Handle relative dates like:
        - "tomorrow", "next week", "Monday"
        - "in 2 hours", "at 3pm"

        Return ONLY valid JSON:
        {
          "title": "string",
          "startTime": "ISO8601",
          "duration": number,
          "location": "string or null",
          "attendees": ["array or empty"],
          "isAllDay": boolean,
          "recurrence": "string"
        }
        """
    }

    private func buildMultiEventParsePrompt(text: String, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short

        return """
        Parse ALL events from this text into structured JSON array:
        "\(text)"

        Reference date/time: \(formatter.string(from: referenceDate))

        Return ONLY a JSON array of events:
        [
          {
            "title": "string",
            "startTime": "ISO8601",
            "duration": number,
            "location": "string or null",
            "attendees": ["array"],
            "isAllDay": boolean,
            "recurrence": "none|daily|weekly|monthly"
          }
        ]
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: MessageResponse, referenceDate: Date) throws -> ParsedEvent {
        guard let content = response.content.first,
              case .text(let text) = content else {
            throw ParserError.invalidResponse
        }

        guard let jsonData = extractJSON(from: text)?.data(using: .utf8) else {
            throw ParserError.noJSONFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(ParsedEventDTO.self, from: jsonData)

        return ParsedEvent(
            title: parsed.title,
            startDate: parsed.startTime,
            duration: TimeInterval(parsed.duration * 60),
            location: parsed.location,
            attendees: parsed.attendees,
            isAllDay: parsed.isAllDay,
            recurrence: RecurrencePattern(rawValue: parsed.recurrence) ?? .none
        )
    }

    private func parseMultipleResponse(_ response: MessageResponse, referenceDate: Date) throws -> [ParsedEvent] {
        guard let content = response.content.first,
              case .text(let text) = content else {
            throw ParserError.invalidResponse
        }

        guard let jsonData = extractJSON(from: text)?.data(using: .utf8) else {
            throw ParserError.noJSONFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsedArray = try decoder.decode([ParsedEventDTO].self, from: jsonData)

        return parsedArray.map { dto in
            ParsedEvent(
                title: dto.title,
                startDate: dto.startTime,
                duration: TimeInterval(dto.duration * 60),
                location: dto.location,
                attendees: dto.attendees,
                isAllDay: dto.isAllDay,
                recurrence: RecurrencePattern(rawValue: dto.recurrence) ?? .none
            )
        }
    }

    private func extractJSON(from text: String) -> String? {
        // Try to find JSON object or array
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        } else if let start = text.range(of: "["),
                  let end = text.range(of: "]", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return nil
    }
}

// MARK: - Supporting Types

struct ParsedEvent {
    let title: String
    let startDate: Date
    let duration: TimeInterval
    let location: String?
    let attendees: [String]
    let isAllDay: Bool
    let recurrence: RecurrencePattern

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }
}

private struct ParsedEventDTO: Codable {
    let title: String
    let startTime: Date
    let duration: Int // minutes
    let location: String?
    let attendees: [String]
    let isAllDay: Bool
    let recurrence: String
}

enum RecurrencePattern: String, Codable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

enum ParserError: Error, LocalizedError {
    case invalidResponse
    case noJSONFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "AI returned an invalid response"
        case .noJSONFound:
            return "Could not find valid JSON in response"
        case .parsingFailed:
            return "Failed to parse event data"
        }
    }
}

// MARK: - Quick Event Templates

extension NaturalLanguageParser {
    /// Common event templates for quick creation
    static var quickTemplates: [EventTemplate] {
        [
            EventTemplate(
                id: "meeting-30",
                title: "Meeting",
                duration: 30 * 60,
                icon: "person.2.fill"
            ),
            EventTemplate(
                id: "meeting-60",
                title: "1 Hour Meeting",
                duration: 60 * 60,
                icon: "person.3.fill"
            ),
            EventTemplate(
                id: "lunch",
                title: "Lunch",
                duration: 60 * 60,
                icon: "fork.knife"
            ),
            EventTemplate(
                id: "coffee",
                title: "Coffee Break",
                duration: 15 * 60,
                icon: "cup.and.saucer.fill"
            ),
            EventTemplate(
                id: "focus",
                title: "Focus Time",
                duration: 90 * 60,
                icon: "brain.head.profile"
            ),
            EventTemplate(
                id: "workout",
                title: "Workout",
                duration: 45 * 60,
                icon: "figure.run"
            )
        ]
    }
}

struct EventTemplate: Identifiable {
    let id: String
    let title: String
    let duration: TimeInterval
    let icon: String
}
