import Foundation
import SwiftAnthropic

/// AI-powered conflict detection with intelligent resolution suggestions
class SmartConflictDetector {
    private let anthropicService: AnthropicService
    private let calendar = Calendar.current

    init() {
        let apiKey = Config.hasValidAPIKey ? Config.currentAPIKey : "placeholder-key"
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    // MARK: - Smart Conflict Detection

    /// Detect conflicts and suggest optimal resolutions
    func analyzeConflict(
        newEvent: UnifiedEvent,
        conflictingEvents: [UnifiedEvent]
    ) async throws -> ConflictAnalysis {
        let prompt = buildConflictAnalysisPrompt(
            newEvent: newEvent,
            conflicts: conflictingEvents
        )

        let message = MessageParameter.Message(role: .user, content: .text(prompt))
        let parameters = MessageParameter(
            model: .claude35Sonnet,
            messages: [message],
            maxTokens: 800
        )

        let response = try await anthropicService.createMessage(parameters)
        return try parseConflictAnalysis(response)
    }

    /// Detect potential scheduling issues before they happen
    func predictSchedulingIssues(
        for event: UnifiedEvent,
        context: SchedulingContext
    ) -> [SchedulingWarning] {
        var warnings: [SchedulingWarning] = []

        // Check for back-to-back meetings
        if let previous = context.previousEvent,
           event.startDate.timeIntervalSince(previous.endDate) < 300 { // < 5 mins
            warnings.append(SchedulingWarning(
                type: .backToBack,
                severity: .medium,
                message: "Back-to-back meeting with no buffer time",
                suggestion: "Add 15-minute buffer for preparation"
            ))
        }

        // Check for travel time requirements
        if let previous = context.previousEvent,
           requiresTravelTime(from: previous, to: event) {
            let travelTime = estimateTravelTime(from: previous.location, to: event.location)
            let availableTime = event.startDate.timeIntervalSince(previous.endDate)

            if availableTime < travelTime {
                warnings.append(SchedulingWarning(
                    type: .insufficientTravelTime,
                    severity: .high,
                    message: "Insufficient travel time between locations",
                    suggestion: "Need \(Int(travelTime/60)) minutes to travel, only \(Int(availableTime/60)) available"
                ))
            }
        }

        // Check for lunch time conflicts
        let hour = calendar.component(.hour, from: event.startDate)
        if hour == 12 && event.endDate.timeIntervalSince(event.startDate) > 3600 {
            warnings.append(SchedulingWarning(
                type: .lunchTimeConflict,
                severity: .low,
                message: "Long meeting during lunch hour",
                suggestion: "Consider scheduling before 12pm or after 1pm"
            ))
        }

        // Check for after-hours meetings
        if hour >= 18 || hour < 8 {
            warnings.append(SchedulingWarning(
                type: .outsideWorkingHours,
                severity: .medium,
                message: "Meeting scheduled outside typical working hours",
                suggestion: "Ensure all participants are available"
            ))
        }

        // Check for overbooked day
        if context.eventsToday >= 6 {
            warnings.append(SchedulingWarning(
                type: .overbooked,
                severity: .medium,
                message: "Already \(context.eventsToday) events scheduled today",
                suggestion: "Consider moving to a less busy day"
            ))
        }

        return warnings
    }

    /// Find the best alternative time slots
    func suggestAlternatives(
        for event: UnifiedEvent,
        avoiding conflicts: [UnifiedEvent],
        preferences: TimeSlotPreferences = .default
    ) -> [AlternativeTimeSlot] {
        var alternatives: [AlternativeTimeSlot] = []
        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Try same day, different times
        let sameDay = findAvailableSlots(
            on: event.startDate,
            duration: duration,
            avoiding: conflicts,
            preferences: preferences
        )
        alternatives.append(contentsOf: sameDay.map {
            AlternativeTimeSlot(
                start: $0.start,
                end: $0.end,
                reason: "Same day, \($0.reasons.joined(separator: ", "))",
                score: $0.score * 1.2 // Bonus for same day
            )
        })

        // Try next day
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: event.startDate) {
            let nextDaySlots = findAvailableSlots(
                on: nextDay,
                duration: duration,
                avoiding: conflicts,
                preferences: preferences
            )
            alternatives.append(contentsOf: nextDaySlots.map {
                AlternativeTimeSlot(
                    start: $0.start,
                    end: $0.end,
                    reason: "Tomorrow, \($0.reasons.joined(separator: ", "))",
                    score: $0.score * 0.9
                )
            })
        }

        return alternatives.sorted { $0.score > $1.score }.prefix(5).map { $0 }
    }

    // MARK: - Helper Methods

    private func buildConflictAnalysisPrompt(
        newEvent: UnifiedEvent,
        conflicts: [UnifiedEvent]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let newEventDesc = """
        New Event:
        - Title: \(newEvent.title ?? "Untitled")
        - Time: \(formatter.string(from: newEvent.startDate)) - \(formatter.string(from: newEvent.endDate))
        - Location: \(newEvent.location ?? "None")
        """

        let conflictsDesc = conflicts.enumerated().map { index, event in
            """
            Conflict \(index + 1):
            - Title: \(event.title ?? "Untitled")
            - Time: \(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))
            - Location: \(event.location ?? "None")
            """
        }.joined(separator: "\n\n")

        return """
        Analyze this scheduling conflict and provide resolution recommendations.

        \(newEventDesc)

        Conflicting Events:
        \(conflictsDesc)

        Provide analysis in JSON:
        {
          "severity": "low|medium|high",
          "conflictType": "time_overlap|location_conflict|duplicate",
          "primaryIssue": "Description of main issue",
          "recommendations": [
            {
              "action": "reschedule|cancel|modify",
              "target": "new|conflict_1|conflict_2",
              "reason": "Why this is recommended",
              "priority": 1-5
            }
          ],
          "autoResolvable": boolean
        }
        """
    }

    private func parseConflictAnalysis(_ response: MessageResponse) throws -> ConflictAnalysis {
        guard let content = response.content.first,
              case .text(let text) = content else {
            throw ConflictDetectorError.invalidResponse
        }

        guard let jsonData = extractJSON(from: text)?.data(using: .utf8) else {
            throw ConflictDetectorError.noJSONFound
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ConflictAnalysis.self, from: jsonData)
    }

    private func extractJSON(from text: String) -> String? {
        if let start = text.range(of: "{"),
           let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return nil
    }

    private func requiresTravelTime(from: UnifiedEvent, to: UnifiedEvent) -> Bool {
        guard let fromLocation = from.location,
              let toLocation = to.location,
              fromLocation != toLocation else {
            return false
        }
        return true
    }

    private func estimateTravelTime(from: String?, to: String?) -> TimeInterval {
        // Simplified: In production, use MapKit or Google Maps API
        guard from != nil && to != nil else { return 0 }
        return 30 * 60 // 30 minutes default
    }

    private func findAvailableSlots(
        on date: Date,
        duration: TimeInterval,
        avoiding conflicts: [UnifiedEvent],
        preferences: TimeSlotPreferences
    ) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let dayStart = calendar.startOfDay(for: date)
        let workStart = calendar.date(bySettingHour: preferences.workStartHour, minute: 0, second: 0, of: dayStart)!
        let workEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: 0, second: 0, of: dayStart)!

        let dayConflicts = conflicts.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }

        var currentTime = workStart

        for conflict in dayConflicts {
            if conflict.startDate > currentTime {
                let gapDuration = conflict.startDate.timeIntervalSince(currentTime)
                if gapDuration >= duration {
                    let score = calculateTimeSlotScore(start: currentTime, duration: duration, preferences: preferences)
                    slots.append(TimeSlot(
                        start: currentTime,
                        end: currentTime.addingTimeInterval(duration),
                        score: score,
                        conflicts: [],
                        reasons: ["Available slot before \(conflict.title ?? "event")"]
                    ))
                }
            }
            currentTime = max(currentTime, conflict.endDate)
        }

        // Check final gap
        if currentTime < workEnd {
            let gapDuration = workEnd.timeIntervalSince(currentTime)
            if gapDuration >= duration {
                let score = calculateTimeSlotScore(start: currentTime, duration: duration, preferences: preferences)
                slots.append(TimeSlot(
                    start: currentTime,
                    end: currentTime.addingTimeInterval(duration),
                    score: score,
                    conflicts: [],
                    reasons: ["End of day availability"]
                ))
            }
        }

        return slots
    }

    private func calculateTimeSlotScore(start: Date, duration: TimeInterval, preferences: TimeSlotPreferences) -> Double {
        var score = 0.5
        let hour = calendar.component(.hour, from: start)

        if preferences.optimalHours.contains(hour) {
            score += 0.3
        }

        if hour == 12 { score -= 0.2 } // Lunch time penalty
        if duration > 3600 && hour < 12 { score += 0.2 } // Morning bonus for long meetings

        return min(max(score, 0), 1.0)
    }
}

// MARK: - Supporting Types

struct ConflictAnalysis: Codable {
    let severity: String
    let conflictType: String
    let primaryIssue: String
    let recommendations: [ResolutionRecommendation]
    let autoResolvable: Bool
}

struct ResolutionRecommendation: Codable {
    let action: String
    let target: String
    let reason: String
    let priority: Int
}

struct SchedulingContext {
    let previousEvent: UnifiedEvent?
    let nextEvent: UnifiedEvent?
    let eventsToday: Int
    let eventsThisWeek: Int
}

struct SchedulingWarning {
    let type: WarningType
    let severity: Severity
    let message: String
    let suggestion: String

    enum WarningType {
        case backToBack
        case insufficientTravelTime
        case lunchTimeConflict
        case outsideWorkingHours
        case overbooked
        case duplicate
    }

    enum Severity {
        case low
        case medium
        case high

        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}

struct AlternativeTimeSlot {
    let start: Date
    let end: Date
    let reason: String
    let score: Double
}

enum ConflictDetectorError: Error, LocalizedError {
    case invalidResponse
    case noJSONFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "AI returned invalid response"
        case .noJSONFound: return "Could not parse JSON from response"
        }
    }
}
