import Foundation

/// Smart scheduling service that analyzes calendar patterns and suggests optimal meeting times
class SmartSchedulingService {

    // MARK: - Types

    struct SchedulingSuggestion {
        let suggestedTime: Date
        let confidence: Float  // 0.0 - 1.0
        let reasons: [String]  // Why this time is good
        let alternatives: [Date]  // Alternative times
        let warnings: [String]?  // Potential issues
    }

    struct CalendarPatterns {
        let preferredMeetingHours: [Int]  // Hours (0-23) with most meetings
        let averageGapBetweenMeetings: TimeInterval
        let typicalMeetingDuration: TimeInterval
        let busiestDays: [Int]  // Day of week (1=Sunday, 7=Saturday)
        let quietestDays: [Int]
        let hasLunchPattern: Bool
        let lunchHourRange: ClosedRange<Int>?
        let confidence: PatternConfidence  // How reliable are these patterns
        let eventCount: Int  // Number of events analyzed
    }

    enum PatternConfidence {
        case none       // 0-2 events: No patterns
        case low        // 3-9 events: Unreliable patterns
        case medium     // 10-29 events: Some patterns emerging
        case high       // 30+ events: Strong patterns

        var description: String {
            switch self {
            case .none: return "No pattern data yet"
            case .low: return "Limited pattern data"
            case .medium: return "Moderate pattern confidence"
            case .high: return "High pattern confidence"
            }
        }
    }

    // MARK: - Pattern Analysis

    /// Analyze user's calendar patterns to understand scheduling preferences
    func analyzeCalendarPatterns(events: [UnifiedEvent]) -> CalendarPatterns {
        let calendar = Calendar.current
        let now = Date()

        // Look at events from the past 30 days to understand patterns
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let recentEvents = events.filter { $0.startDate >= thirtyDaysAgo && $0.startDate <= now }

        let eventCount = recentEvents.count

        // Determine confidence level based on event count
        let confidence: PatternConfidence
        switch eventCount {
        case 0...2:
            confidence = .none
        case 3...9:
            confidence = .low
        case 10...29:
            confidence = .medium
        default:
            confidence = .high
        }

        // Use sensible defaults for sparse/empty calendars
        let defaultHours = [10, 14, 16]  // 10AM, 2PM, 4PM
        let defaultDuration: TimeInterval = 1800  // 30 minutes
        let defaultGap: TimeInterval = 900  // 15 minutes

        // Analyze preferred meeting hours (or use defaults)
        var hourCounts: [Int: Int] = [:]
        for event in recentEvents {
            let hour = calendar.component(.hour, from: event.startDate)
            hourCounts[hour, default: 0] += 1
        }
        let preferredHours: [Int]
        if eventCount >= 3 {
            preferredHours = hourCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        } else {
            preferredHours = defaultHours
        }

        // Calculate average gap between meetings (or use default)
        let sortedEvents = recentEvents.sorted { $0.startDate < $1.startDate }
        var gaps: [TimeInterval] = []
        for i in 0..<(sortedEvents.count - 1) {
            let gap = sortedEvents[i + 1].startDate.timeIntervalSince(sortedEvents[i].endDate)
            if gap > 0 && gap < 3600 * 4 {  // Only count gaps under 4 hours
                gaps.append(gap)
            }
        }
        let avgGap = gaps.isEmpty ? defaultGap : gaps.reduce(0, +) / Double(gaps.count)

        // Calculate typical meeting duration (or use default)
        let durations = recentEvents.map { $0.endDate.timeIntervalSince($0.startDate) }
        let avgDuration = durations.isEmpty ? defaultDuration : durations.reduce(0, +) / Double(durations.count)

        // Analyze busiest/quietest days (or use defaults)
        var dayCounts: [Int: Int] = [:]
        for event in recentEvents {
            let weekday = calendar.component(.weekday, from: event.startDate)
            dayCounts[weekday, default: 0] += 1
        }
        let busiestDays: [Int]
        let quietestDays: [Int]
        if eventCount >= 5 {
            busiestDays = dayCounts.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
            quietestDays = dayCounts.sorted { $0.value < $1.value }.prefix(2).map { $0.key }
        } else {
            // Default: Tuesday/Thursday busiest, Monday/Friday quietest
            busiestDays = [3, 5]
            quietestDays = [2, 6]
        }

        // Detect lunch pattern (12pm-2pm) - only if enough data
        let hasLunchPattern: Bool
        let lunchRange: ClosedRange<Int>?
        if eventCount >= 10 {
            let lunchEvents = recentEvents.filter {
                let hour = calendar.component(.hour, from: $0.startDate)
                return hour >= 11 && hour <= 14
            }
            hasLunchPattern = lunchEvents.count > recentEvents.count / 4
            lunchRange = hasLunchPattern ? 12...13 : nil
        } else {
            hasLunchPattern = false
            lunchRange = nil
        }

        print("📊 Pattern Analysis: \(eventCount) events, confidence: \(confidence.description)")

        return CalendarPatterns(
            preferredMeetingHours: preferredHours,
            averageGapBetweenMeetings: avgGap,
            typicalMeetingDuration: avgDuration,
            busiestDays: busiestDays,
            quietestDays: quietestDays,
            hasLunchPattern: hasLunchPattern,
            lunchHourRange: lunchRange,
            confidence: confidence,
            eventCount: eventCount
        )
    }

    // MARK: - Time Suggestions

    /// Suggest optimal time for a new meeting based on patterns and constraints
    func suggestOptimalTime(
        for duration: TimeInterval,
        events: [UnifiedEvent],
        preferredDate: Date? = nil,
        participantTimeZones: [TimeZone]? = nil
    ) -> SchedulingSuggestion {

        let calendar = Calendar.current
        let patterns = analyzeCalendarPatterns(events: events)
        let searchDate = preferredDate ?? Date()

        // Find available slots in the next 7 days
        var bestTime: Date?
        var bestScore: Float = 0
        var reasons: [String] = []
        var alternatives: [Date] = []
        var warnings: [String] = []

        // Search through next 7 days
        for dayOffset in 0..<7 {
            guard let searchDay = calendar.date(byAdding: .day, value: dayOffset, to: searchDate) else { continue }

            // Try each hour from 8am to 6pm
            for hour in 8...18 {
                guard let candidateTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: searchDay) else { continue }

                // Check if time is available
                let candidateEnd = candidateTime.addingTimeInterval(duration)
                let hasConflict = events.contains { event in
                    event.startDate < candidateEnd && event.endDate > candidateTime
                }

                if hasConflict { continue }

                // Score this time slot
                var score: Float = 0.0
                var timeReasons: [String] = []

                // Preferred hours bonus
                if patterns.preferredMeetingHours.contains(hour) {
                    score += 0.3
                    timeReasons.append("Matches your typical meeting time")
                }

                // Avoid lunch hours
                if let lunchRange = patterns.lunchHourRange, lunchRange.contains(hour) {
                    score -= 0.2
                    warnings.append("During typical lunch hours")
                } else {
                    score += 0.1
                }

                // Check buffer time before/after
                let bufferBefore = events.first { $0.endDate <= candidateTime && candidateTime.timeIntervalSince($0.endDate) < 1800 }
                let bufferAfter = events.first { $0.startDate >= candidateEnd && $0.startDate.timeIntervalSince(candidateEnd) < 1800 }

                if bufferBefore == nil && bufferAfter == nil {
                    score += 0.2
                    timeReasons.append("Good buffer time before/after")
                } else if bufferBefore != nil || bufferAfter != nil {
                    score -= 0.1
                    warnings.append("Back-to-back with other meetings")
                }

                // Prefer quieter days
                let weekday = calendar.component(.weekday, from: candidateTime)
                if patterns.quietestDays.contains(weekday) {
                    score += 0.15
                    timeReasons.append("On a typically lighter day")
                } else if patterns.busiestDays.contains(weekday) {
                    score -= 0.1
                }

                // Morning vs afternoon preference
                if hour < 12 {
                    score += 0.1
                    timeReasons.append("Morning time slot")
                }

                // Time zone consideration
                if let timezones = participantTimeZones, !timezones.isEmpty {
                    let allReasonable = timezones.allSatisfy { tz in
                        let offset = tz.secondsFromGMT() - TimeZone.current.secondsFromGMT()
                        let theirHour = hour + offset / 3600
                        return theirHour >= 8 && theirHour <= 18
                    }
                    if allReasonable {
                        score += 0.2
                        timeReasons.append("Works for all time zones")
                    } else {
                        score -= 0.3
                        warnings.append("May be outside business hours for some participants")
                    }
                }

                // Sooner is better (slight preference)
                score += Float(7 - dayOffset) * 0.02

                // Track best time
                if score > bestScore {
                    if bestTime != nil {
                        alternatives.insert(bestTime!, at: 0)
                    }
                    bestScore = score
                    bestTime = candidateTime
                    reasons = timeReasons
                }

                // Track alternatives
                if score > 0.5 && alternatives.count < 3 && candidateTime != bestTime {
                    alternatives.append(candidateTime)
                }
            }
        }

        // Default to tomorrow at 10am if no good time found
        let finalTime = bestTime ?? calendar.date(byAdding: .day, value: 1, to: searchDate)!

        return SchedulingSuggestion(
            suggestedTime: finalTime,
            confidence: max(0.3, bestScore),
            reasons: reasons.isEmpty ? ["Available time slot"] : reasons,
            alternatives: Array(alternatives.prefix(3)),
            warnings: warnings.isEmpty ? nil : warnings
        )
    }

    // MARK: - Conflict Detection

    /// Check for potential scheduling conflicts and provide warnings
    func detectSchedulingIssues(
        proposedTime: Date,
        duration: TimeInterval,
        events: [UnifiedEvent]
    ) -> [String] {
        var issues: [String] = []
        let calendar = Calendar.current
        let proposedEnd = proposedTime.addingTimeInterval(duration)

        // Check for direct conflicts
        let conflicts = events.filter { event in
            event.startDate < proposedEnd && event.endDate > proposedTime
        }
        if !conflicts.isEmpty {
            issues.append("Conflicts with \(conflicts.count) existing event(s)")
        }

        // Check for back-to-back meetings
        let backToBack = events.filter { event in
            abs(event.endDate.timeIntervalSince(proposedTime)) < 60 ||
            abs(proposedEnd.timeIntervalSince(event.startDate)) < 60
        }
        if !backToBack.isEmpty {
            issues.append("Back-to-back with other meetings - no break time")
        }

        // Check for too many meetings in one day
        let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: proposedTime) }
        if dayEvents.count >= 6 {
            issues.append("This would be meeting #\(dayEvents.count + 1) on this day")
        }

        // Check if outside business hours
        let hour = calendar.component(.hour, from: proposedTime)
        if hour < 8 || hour >= 18 {
            issues.append("Outside typical business hours (8am-6pm)")
        }

        // Check if on weekend
        let weekday = calendar.component(.weekday, from: proposedTime)
        if weekday == 1 || weekday == 7 {
            issues.append("Scheduled on weekend")
        }

        return issues
    }

    // MARK: - Helper Methods

    /// Format scheduling suggestion as natural language
    func formatSuggestion(_ suggestion: SchedulingSuggestion) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var message = "I suggest \(formatter.string(from: suggestion.suggestedTime))"

        if !suggestion.reasons.isEmpty {
            message += " because:\n"
            for reason in suggestion.reasons {
                message += "• \(reason)\n"
            }
        }

        if let warnings = suggestion.warnings, !warnings.isEmpty {
            message += "\nNote: \(warnings.joined(separator: ", "))"
        }

        if !suggestion.alternatives.isEmpty {
            message += "\n\nAlternatives: "
            let altTimes = suggestion.alternatives.map { formatter.string(from: $0) }
            message += altTimes.joined(separator: ", ")
        }

        return message
    }
}
