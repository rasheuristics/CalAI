import Foundation
import SwiftAnthropic

/// Service for AI-powered event suggestions based on user patterns
class SmartSuggestionsService {
    private let anthropicService: AnthropicService
    private let calendar = Calendar.current

    init() {
        let apiKey = Config.hasValidAPIKey ? Config.currentAPIKey : "placeholder-key"
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    // MARK: - Event Suggestions

    /// Generate smart event suggestions based on user's calendar patterns
    func generateSuggestions(
        from events: [UnifiedEvent],
        currentDate: Date = Date()
    ) async throws -> [EventSuggestion] {
        let analysis = analyzeEventPatterns(events)
        let prompt = buildSuggestionPrompt(analysis: analysis, currentDate: currentDate)

        let message = MessageParameter.Message(role: .user, content: .text(prompt))
        let parameters = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 1000
        )

        let response = try await anthropicService.createMessage(parameters)
        let suggestions = parseSuggestions(from: response)

        return suggestions
    }

    /// Suggest optimal time slots for a new event based on existing schedule
    func suggestTimeSlots(
        for duration: TimeInterval,
        on date: Date,
        existingEvents: [UnifiedEvent],
        preferences: TimeSlotPreferences = .default
    ) -> [TimeSlot] {
        var suggestions: [TimeSlot] = []
        let dayStart = calendar.startOfDay(for: date)

        // Get user's preferred working hours
        let workStart = calendar.date(bySettingHour: preferences.workStartHour, minute: 0, second: 0, of: dayStart)!
        let workEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: 0, second: 0, of: dayStart)!

        // Filter events for the day
        let dayEvents = existingEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }.sorted { $0.startDate < $1.startDate }

        // Find gaps between events
        var currentTime = workStart

        for event in dayEvents {
            if event.startDate > currentTime {
                let gapDuration = event.startDate.timeIntervalSince(currentTime)
                if gapDuration >= duration {
                    let score = calculateTimeSlotScore(
                        start: currentTime,
                        duration: duration,
                        preferences: preferences
                    )
                    suggestions.append(TimeSlot(
                        start: currentTime,
                        end: currentTime.addingTimeInterval(duration),
                        score: score,
                        reason: reasonForTimeSlot(start: currentTime, preferences: preferences)
                    ))
                }
            }
            currentTime = max(currentTime, event.endDate)
        }

        // Check gap after last event
        if currentTime < workEnd {
            let gapDuration = workEnd.timeIntervalSince(currentTime)
            if gapDuration >= duration {
                let score = calculateTimeSlotScore(
                    start: currentTime,
                    duration: duration,
                    preferences: preferences
                )
                suggestions.append(TimeSlot(
                    start: currentTime,
                    end: currentTime.addingTimeInterval(duration),
                    score: score,
                    reason: reasonForTimeSlot(start: currentTime, preferences: preferences)
                ))
            }
        }

        // Sort by score (highest first)
        return suggestions.sorted { $0.score > $1.score }
    }

    // MARK: - Pattern Analysis

    private func analyzeEventPatterns(_ events: [UnifiedEvent]) -> EventPatternAnalysis {
        let last30Days = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentEvents = events.filter { $0.startDate >= last30Days }

        // Analyze recurring patterns
        let recurringTitles = findRecurringEventTitles(recentEvents)

        // Analyze time preferences
        let morningEvents = recentEvents.filter { calendar.component(.hour, from: $0.startDate) < 12 }.count
        let afternoonEvents = recentEvents.filter {
            let hour = calendar.component(.hour, from: $0.startDate)
            return hour >= 12 && hour < 17
        }.count
        let eveningEvents = recentEvents.filter { calendar.component(.hour, from: $0.startDate) >= 17 }.count

        // Analyze common locations
        let locations = recentEvents.compactMap { $0.location }
        let locationFrequency = Dictionary(grouping: locations) { $0 }.mapValues { $0.count }

        return EventPatternAnalysis(
            recurringTitles: recurringTitles,
            morningEventCount: morningEvents,
            afternoonEventCount: afternoonEvents,
            eveningEventCount: eveningEvents,
            commonLocations: locationFrequency.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        )
    }

    private func findRecurringEventTitles(_ events: [UnifiedEvent]) -> [String: Int] {
        let titles = events.compactMap { $0.title }
        return Dictionary(grouping: titles) { $0 }
            .mapValues { $0.count }
            .filter { $0.value >= 2 } // Appears at least twice
    }

    private func buildSuggestionPrompt(analysis: EventPatternAnalysis, currentDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return """
        Based on the user's calendar patterns, suggest 3-5 relevant events they might want to schedule.

        Current date: \(formatter.string(from: currentDate))

        Pattern Analysis:
        - Recurring events: \(analysis.recurringTitles.map { "\($0.key) (\($0.value) times)" }.joined(separator: ", "))
        - Time preferences: Morning (\(analysis.morningEventCount)), Afternoon (\(analysis.afternoonEventCount)), Evening (\(analysis.eveningEventCount))
        - Common locations: \(analysis.commonLocations.joined(separator: ", "))

        Provide suggestions in JSON format:
        [
          {
            "title": "Event title",
            "suggestedDate": "ISO8601 date",
            "duration": duration_in_minutes,
            "reason": "Why this is suggested",
            "priority": 1-5
          }
        ]

        Focus on:
        1. Recurring events that might be due again
        2. Work-life balance suggestions
        3. Seasonal or time-appropriate activities
        """
    }

    private func parseSuggestions(from response: MessageResponse) -> [EventSuggestion] {
        guard let content = response.content.first,
              case .text(let text) = content else {
            return []
        }

        // Extract JSON from response
        guard let jsonData = extractJSON(from: text)?.data(using: .utf8) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([EventSuggestion].self, from: jsonData)
        } catch {
            print("❌ Failed to parse suggestions: \(error)")
            return []
        }
    }

    private func extractJSON(from text: String) -> String? {
        // Find JSON array in the response
        if let start = text.range(of: "["),
           let end = text.range(of: "]", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return nil
    }

    private func calculateTimeSlotScore(
        start: Date,
        duration: TimeInterval,
        preferences: TimeSlotPreferences
    ) -> Double {
        var score = 0.5 // Base score

        let hour = calendar.component(.hour, from: start)

        // Prefer user's optimal hours
        if preferences.optimalHours.contains(hour) {
            score += 0.3
        }

        // Avoid lunch hours (12-13)
        if hour == 12 {
            score -= 0.2
        }

        // Prefer morning for longer meetings
        if duration > 3600 && hour < 12 {
            score += 0.2
        }

        return min(max(score, 0), 1.0)
    }

    private func reasonForTimeSlot(start: Date, preferences: TimeSlotPreferences) -> String {
        let hour = calendar.component(.hour, from: start)

        if preferences.optimalHours.contains(hour) {
            return "Matches your preferred working hours"
        } else if hour < 12 {
            return "Good morning slot for focused work"
        } else if hour >= 12 && hour < 17 {
            return "Afternoon slot with good availability"
        } else {
            return "Available time slot"
        }
    }
}

// MARK: - Supporting Types

struct EventPatternAnalysis {
    let recurringTitles: [String: Int]
    let morningEventCount: Int
    let afternoonEventCount: Int
    let eveningEventCount: Int
    let commonLocations: [String]
}

struct EventSuggestion: Codable {
    let title: String
    let suggestedDate: Date
    let duration: Int // minutes
    let reason: String
    let priority: Int // 1-5
}

struct TimeSlot {
    let start: Date
    let end: Date
    let score: Double // 0-1, higher is better
    let reason: String
}

struct TimeSlotPreferences {
    let workStartHour: Int
    let workEndHour: Int
    let optimalHours: [Int]

    static let `default` = TimeSlotPreferences(
        workStartHour: 9,
        workEndHour: 17,
        optimalHours: [9, 10, 11, 14, 15, 16]
    )
}
