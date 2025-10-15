import Foundation
import SwiftAnthropic

/// AI-powered conflict resolution suggestion generator
class ConflictResolutionAI {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Generate AI-powered suggestions for resolving a conflict
    func generateSuggestions(for conflict: ScheduleConflict, allEvents: [UnifiedEvent], completion: @escaping (ConflictResolution) -> Void) {
        print("🤖 Generating AI-powered conflict resolution suggestions...")

        guard conflict.conflictingEvents.count >= 2 else {
            print("⚠️ Conflict must have at least 2 events")
            completion(ConflictResolution(conflict: conflict, suggestions: []))
            return
        }

        // Build context about the conflict
        let event1 = conflict.conflictingEvents[0]
        let event2 = conflict.conflictingEvents[1]

        // Calculate overlap duration
        let overlapDuration = conflict.overlapEnd.timeIntervalSince(conflict.overlapStart)
        let overlapFormatted = formatDuration(overlapDuration)

        let prompt = """
        You are a smart calendar assistant. Two events are overlapping:

        Event 1: "\(event1.title)"
        - Time: \(dateFormatter.string(from: event1.startDate)) to \(dateFormatter.string(from: event1.endDate))
        - Source: \(event1.source)
        \(event1.location != nil ? "- Location: \(event1.location!)" : "")

        Event 2: "\(event2.title)"
        - Time: \(dateFormatter.string(from: event2.startDate)) to \(dateFormatter.string(from: event2.endDate))
        - Source: \(event2.source)
        \(event2.location != nil ? "- Location: \(event2.location!)" : "")

        Overlap: \(overlapFormatted)
        Severity: \(conflict.severity.rawValue)

        Analyze these events and provide 3 practical suggestions to resolve the conflict. Consider:
        1. Which event might be more important based on title/details
        2. Whether one could be rescheduled more easily
        3. If shortening one event could eliminate the overlap
        4. If the user could attend both if they're nearby
        5. If one could be marked as optional/tentative

        Format your response as exactly 3 suggestions, each on a new line starting with a number:
        1. [Suggestion]
        2. [Suggestion]
        3. [Suggestion]

        Keep suggestions concise and actionable.
        """

        Task {
            do {
                let response = try await callLLM(prompt: prompt)

                // Parse suggestions from response
                let suggestions = parseSuggestions(from: response, conflict: conflict, allEvents: allEvents)

                let resolution = ConflictResolution(
                    conflict: conflict,
                    suggestions: suggestions
                )

                DispatchQueue.main.async {
                    completion(resolution)
                }
            } catch {
                print("❌ Error generating conflict suggestions: \(error)")

                // Fallback to rule-based suggestions
                let fallbackSuggestions = generateRuleBasedSuggestions(for: conflict, allEvents: allEvents)
                let resolution = ConflictResolution(
                    conflict: conflict,
                    suggestions: fallbackSuggestions
                )

                DispatchQueue.main.async {
                    completion(resolution)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Parse AI suggestions from LLM response
    private func parseSuggestions(from response: String, conflict: ScheduleConflict, allEvents: [UnifiedEvent]) -> [ResolutionSuggestion] {
        var suggestions: [ResolutionSuggestion] = []

        // Split response into lines
        let lines = response.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            // Look for numbered suggestions (1., 2., 3., etc.)
            if let match = line.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                let suggestionText = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)

                // Classify the suggestion type based on keywords
                let type = classifySuggestionType(suggestionText)

                // Determine target event (which event to act on)
                let targetEvent = determineTargetEvent(from: suggestionText, conflict: conflict)

                let suggestion = ResolutionSuggestion(
                    type: type,
                    title: type.rawValue,
                    description: suggestionText,
                    targetEvent: targetEvent,
                    suggestedTime: nil,
                    confidence: 0.85
                )

                suggestions.append(suggestion)
            }
        }

        // If we didn't parse enough suggestions, add rule-based ones
        if suggestions.count < 3 {
            let additionalSuggestions = generateRuleBasedSuggestions(for: conflict, allEvents: allEvents)
            suggestions.append(contentsOf: additionalSuggestions.prefix(3 - suggestions.count))
        }

        return Array(suggestions.prefix(3))
    }

    /// Classify suggestion type based on keywords
    private func classifySuggestionType(_ text: String) -> ResolutionType {
        let lowercased = text.lowercased()

        if lowercased.contains("reschedule") || lowercased.contains("move") || lowercased.contains("different time") {
            return .reschedule
        } else if lowercased.contains("decline") || lowercased.contains("cancel") || lowercased.contains("delete") {
            return .decline
        } else if lowercased.contains("shorten") || lowercased.contains("reduce") || lowercased.contains("end early") {
            return .shorten
        } else if lowercased.contains("optional") || lowercased.contains("tentative") || lowercased.contains("maybe") {
            return .markOptional
        } else {
            return .noAction
        }
    }

    /// Determine which event the suggestion applies to
    private func determineTargetEvent(from text: String, conflict: ScheduleConflict) -> UnifiedEvent? {
        let lowercased = text.lowercased()

        for event in conflict.conflictingEvents {
            if lowercased.contains(event.title.lowercased()) {
                return event
            }
        }

        // Default to first event if unclear
        return conflict.conflictingEvents.first
    }

    /// Generate rule-based suggestions when AI is unavailable
    private func generateRuleBasedSuggestions(for conflict: ScheduleConflict, allEvents: [UnifiedEvent]) -> [ResolutionSuggestion] {
        var suggestions: [ResolutionSuggestion] = []

        guard conflict.conflictingEvents.count >= 2 else {
            return suggestions
        }

        let event1 = conflict.conflictingEvents[0]
        let event2 = conflict.conflictingEvents[1]

        // Suggestion 1: Reschedule the shorter event
        let shorterEvent = event1.endDate.timeIntervalSince(event1.startDate) < event2.endDate.timeIntervalSince(event2.startDate) ? event1 : event2

        suggestions.append(ResolutionSuggestion(
            type: .reschedule,
            title: "Reschedule",
            description: "Reschedule \"\(shorterEvent.title)\" to a different time slot",
            targetEvent: shorterEvent,
            confidence: 0.8
        ))

        // Suggestion 2: Shorten the later event
        let laterEvent = event1.startDate > event2.startDate ? event1 : event2

        suggestions.append(ResolutionSuggestion(
            type: .shorten,
            title: "Shorten Event",
            description: "Shorten \"\(laterEvent.title)\" to start after the first event ends",
            targetEvent: laterEvent,
            confidence: 0.7
        ))

        // Suggestion 3: Keep both
        suggestions.append(ResolutionSuggestion(
            type: .noAction,
            title: "Keep Both",
            description: "Keep both events and mark one as tentative if they're both important",
            confidence: 0.6
        ))

        return suggestions
    }

    // MARK: - LLM Integration

    /// Call the configured LLM (Anthropic or OpenAI)
    private func callLLM(prompt: String) async throws -> String {
        guard Config.hasValidAPIKey else {
            throw NSError(domain: "ConflictResolutionAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key configured"])
        }

        switch Config.aiProvider {
        case .anthropic:
            return try await callAnthropic(prompt: prompt)
        case .openai:
            return try await callOpenAI(prompt: prompt)
        }
    }

    /// Call Anthropic API
    private func callAnthropic(prompt: String) async throws -> String {
        let service = AnthropicServiceFactory.service(apiKey: Config.anthropicAPIKey, betaHeaders: nil)

        let message = MessageParameter.Message(role: .user, content: .text(prompt))
        let parameters = MessageParameter(model: .claude35Sonnet, messages: [message], maxTokens: 300)

        let response = try await service.createMessage(parameters)

        guard case .text(let text) = response.content.first else {
            throw NSError(domain: "ConflictResolutionAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Anthropic"])
        }

        return text
    }

    /// Call OpenAI API
    private func callOpenAI(prompt: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "ConflictResolutionAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 300
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ConflictResolutionAI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ConflictResolutionAI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }

        return content
    }
}
