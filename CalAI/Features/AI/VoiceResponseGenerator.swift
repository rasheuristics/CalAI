import Foundation

// MARK: - Voice Response Structure

struct VoiceResponse {
    let greeting: String
    let body: String
    let insight: String?
    let followUp: String?

    var fullMessage: String {
        var parts = [greeting, body]
        if let insight = insight {
            parts.append(insight)
        }
        if let followUp = followUp {
            parts.append(followUp)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Voice Response Generator

class VoiceResponseGenerator {

    // MARK: - Greeting Generation

    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 6 && hour < 12 {
            return "Good morning!"
        } else if hour >= 12 && hour < 18 {
            return "Good afternoon!"
        } else {
            return "Good evening!"
        }
    }

    // MARK: - Conflict Detection

    func checkConflicts(
        newEventStart: Date,
        newEventEnd: Date,
        in events: [UnifiedEvent]
    ) -> [UnifiedEvent] {
        return events.filter { event in
            // Check if events overlap
            // Two events overlap if: event1.end > event2.start AND event2.end > event1.start
            newEventEnd > event.startDate && event.endDate > newEventStart
        }
    }

    func formatConflictWarning(conflicts: [UnifiedEvent]) -> String? {
        guard !conflicts.isEmpty else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if conflicts.count == 1 {
            let event = conflicts[0]
            return "This overlaps with \(event.title) at \(timeFormatter.string(from: event.startDate))."
        } else {
            return "This conflicts with \(conflicts.count) existing events."
        }
    }

    // MARK: - Event List Formatting

    func formatEventList(
        _ events: [UnifiedEvent],
        maxEvents: Int = 5,
        includeDate: Bool = false
    ) -> String {
        guard !events.isEmpty else {
            return "You don't have any events scheduled."
        }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        let eventsToShow = Array(sortedEvents.prefix(maxEvents))
        let remainingCount = sortedEvents.count - eventsToShow.count

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var parts: [String] = []

        // Format each event
        for (index, event) in eventsToShow.enumerated() {
            let time = timeFormatter.string(from: event.startDate)
            let dateStr = includeDate ? dateFormatter.string(from: event.startDate) : nil

            var eventDesc = ""

            if index == 0 {
                eventDesc = "You start with \(event.title) at \(time)"
            } else if index == eventsToShow.count - 1 && remainingCount == 0 {
                eventDesc = "then \(event.title) at \(time)"
            } else {
                eventDesc = "followed by \(event.title) at \(time)"
            }

            if let date = dateStr, includeDate {
                eventDesc += " on \(date)"
            }

            parts.append(eventDesc)
        }

        var result = parts.joined(separator: ", ")

        // Add remaining count
        if remainingCount > 0 {
            result += ", and \(remainingCount) more event\(remainingCount == 1 ? "" : "s")"
        }

        result += "."

        return result
    }

    // MARK: - Insight Generation

    func generateScheduleInsight(
        events: [UnifiedEvent],
        timeRange: (start: Date, end: Date)
    ) -> String? {
        guard !events.isEmpty else { return nil }

        let calendar = Calendar.current
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        // Check for back-to-back meetings
        var hasBackToBack = false
        for i in 0..<sortedEvents.count-1 {
            let gap = sortedEvents[i+1].startDate.timeIntervalSince(sortedEvents[i].endDate)
            if gap < 300 { // Less than 5 minutes
                hasBackToBack = true
                break
            }
        }

        if hasBackToBack {
            return "You have back-to-back meetings with minimal breaks."
        }

        // Check for free afternoon/morning
        let isToday = calendar.isDateInToday(timeRange.start)
        if isToday {
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: timeRange.start)!
            let evening = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: timeRange.start)!

            let morningEvents = sortedEvents.filter { $0.startDate < noon }
            let afternoonEvents = sortedEvents.filter { $0.startDate >= noon && $0.startDate < evening }

            if morningEvents.isEmpty && !afternoonEvents.isEmpty {
                return "Your morning is free."
            } else if afternoonEvents.isEmpty && !morningEvents.isEmpty {
                return "Your afternoon is free."
            }
        }

        // Check for busy day
        let totalMinutes = sortedEvents.reduce(0) { total, event in
            let duration = event.endDate.timeIntervalSince(event.startDate) / 60
            return total + Int(duration)
        }

        if totalMinutes > 360 { // More than 6 hours
            return "It's a busy day with over 6 hours of meetings."
        }

        // Find longest free gap
        var longestGap: TimeInterval = 0
        for i in 0..<sortedEvents.count-1 {
            let gap = sortedEvents[i+1].startDate.timeIntervalSince(sortedEvents[i].endDate)
            if gap > longestGap {
                longestGap = gap
            }
        }

        if longestGap >= 7200 { // 2+ hours free
            let hours = Int(longestGap / 3600)
            return "You have a \(hours)-hour gap for focused work."
        }

        return nil
    }

    // MARK: - Follow-Up Generation

    func generateFollowUp(for intent: String, context: FollowUpContext) -> String? {
        switch intent {
        case "create":
            if context.hasParticipants {
                return nil // Already has participants
            }
            return "Would you like me to set a reminder?"

        case "delete":
            return "Would you like to reschedule it?"

        case "modify":
            if context.affectsOthers {
                return "Should I notify the participants?"
            }
            return nil

        case "query":
            if context.hasConflicts {
                return "Would you like me to help resolve conflicts?"
            }
            return nil

        default:
            return nil
        }
    }

    // MARK: - Query Response Generation

    func generateQueryResponse(
        events: [UnifiedEvent],
        timeRange: (start: Date, end: Date),
        queryType: String = "general"
    ) -> VoiceResponse {
        let greeting = getGreeting()
        let count = events.count
        let calendar = Calendar.current

        // Determine time reference
        let timeRef: String
        if calendar.isDateInToday(timeRange.start) {
            timeRef = "today"
        } else if calendar.isDateInTomorrow(timeRange.start) {
            timeRef = "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            timeRef = "on \(formatter.string(from: timeRange.start))"
        }

        // Build body
        var body: String
        if count == 0 {
            body = "You don't have any events \(timeRef). Your schedule is clear."
        } else {
            let eventWord = count == 1 ? "event" : "events"
            body = "You have \(count) \(eventWord) \(timeRef). "
            body += formatEventList(events, maxEvents: 5)
        }

        // Generate insight
        let insight = generateScheduleInsight(events: events, timeRange: timeRange)

        // No follow-up for queries by default
        let followUp: String? = nil

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Create Response Generation

    func generateCreateResponse(
        eventTitle: String,
        eventDate: Date,
        conflicts: [UnifiedEvent],
        duration: TimeInterval? = nil
    ) -> VoiceResponse {
        let greeting = "Done!"

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short

        var body = "I've scheduled \(eventTitle) for \(timeFormatter.string(from: eventDate))."

        // Add conflict warning as insight
        let insight = formatConflictWarning(conflicts: conflicts)

        // Add follow-up
        let context = FollowUpContext(hasParticipants: false, affectsOthers: false, hasConflicts: !conflicts.isEmpty)
        let followUp = conflicts.isEmpty ? generateFollowUp(for: "create", context: context) : nil

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Delete Response Generation

    func generateDeleteResponse(eventTitle: String) -> VoiceResponse {
        let greeting = "Done!"
        let body = "I've deleted \(eventTitle) from your calendar."
        let insight: String? = nil
        let followUp = generateFollowUp(for: "delete", context: FollowUpContext())

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Search Response Generation

    func generateSearchResponse(
        query: String,
        results: [UnifiedEvent]
    ) -> VoiceResponse {
        let greeting = "" // No greeting for search results

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short

        var body: String
        if results.isEmpty {
            body = "I couldn't find any events matching '\(query)'."
        } else if results.count == 1 {
            let event = results[0]
            body = "Your \(event.title) is scheduled for \(timeFormatter.string(from: event.startDate))"
            if let location = event.location, !location.isEmpty {
                body += " at \(location)"
            }
            body += "."
        } else {
            body = "I found \(results.count) events matching '\(query)'. "
            body += formatEventList(results, maxEvents: 3, includeDate: true)
        }

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: nil,
            followUp: nil
        )
    }

    // MARK: - Availability Response Generation

    func generateAvailabilityResponse(
        isFree: Bool,
        conflictingEvent: UnifiedEvent?,
        freeSlots: [(start: Date, end: Date)],
        queryTime: Date
    ) -> VoiceResponse {
        let greeting = "" // No greeting for quick answers

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var body: String
        if isFree {
            body = "Yes, you're free at \(timeFormatter.string(from: queryTime))."
            if !freeSlots.isEmpty, let firstSlot = freeSlots.first {
                body += " You're available until \(timeFormatter.string(from: firstSlot.end))."
            }
        } else if let conflict = conflictingEvent {
            body = "No, you have \(conflict.title) at \(timeFormatter.string(from: conflict.startDate))."

            // Suggest next free slot
            if !freeSlots.isEmpty, let nextSlot = freeSlots.first {
                body += " Your next free slot is at \(timeFormatter.string(from: nextSlot.start))."
            }
        } else {
            body = "You're not available at that time."
        }

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: nil,
            followUp: nil
        )
    }
}

// MARK: - Supporting Structures

struct FollowUpContext {
    var hasParticipants: Bool = false
    var affectsOthers: Bool = false
    var hasConflicts: Bool = false
}
