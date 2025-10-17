import Foundation
import EventKit

// MARK: - Smart Rescheduling Models

/// Request to reschedule one or more events
struct RescheduleRequest: Identifiable {
    let id: String
    let events: [UnifiedEvent]
    let reason: RescheduleReason
    let constraints: RescheduleConstraints
    let preferredTimeSlots: [TimeSlot]?
    var createdAt: Date

    enum RescheduleReason: String, Codable {
        case conflict = "Conflict"
        case travelDelay = "Travel Delay"
        case personalPreference = "Personal Preference"
        case optimization = "Schedule Optimization"
        case emergency = "Emergency"
        case other = "Other"

        var priority: Int {
            switch self {
            case .emergency: return 0
            case .conflict: return 1
            case .travelDelay: return 2
            case .optimization: return 3
            case .personalPreference: return 4
            case .other: return 5
            }
        }
    }
}

/// Constraints for rescheduling
struct RescheduleConstraints {
    let mustRescheduleBefore: Date?      // Deadline for rescheduling
    let preferredDaysOfWeek: [Int]?      // 1=Sunday, 2=Monday, etc.
    let preferredTimeRange: ScheduleTimeRange?   // Preferred time of day
    let minimumDuration: TimeInterval?   // Minimum meeting duration
    let maximumDuration: TimeInterval?   // Maximum meeting duration
    var avoidConflicts: Bool             // Automatically avoid conflicts
    var maintainAttendees: Bool          // Keep same attendees
    var maintainLocation: Bool           // Keep same location
    let bufferTime: TimeInterval?        // Required buffer before/after

    static var `default`: RescheduleConstraints {
        RescheduleConstraints(
            mustRescheduleBefore: Optional<Date>.none,
            preferredDaysOfWeek: Optional<[Int]>.none,
            preferredTimeRange: Optional<ScheduleTimeRange>.none,
            minimumDuration: Optional<TimeInterval>.none,
            maximumDuration: Optional<TimeInterval>.none,
            avoidConflicts: true,
            maintainAttendees: true,
            maintainLocation: true,
            bufferTime: Optional<TimeInterval>.some(15 * 60)  // 15 minutes
        )
    }
}

/// Time range for scheduling
struct ScheduleTimeRange {
    let start: Date      // Start time
    let end: Date        // End time

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }

    func overlaps(with other: ScheduleTimeRange) -> Bool {
        start < other.end && end > other.start
    }
}

/// Available time slot for rescheduling
struct TimeSlot: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let score: Double               // 0-100, how good this slot is
    let conflicts: [UnifiedEvent]   // Conflicting events (if any)
    let reasons: [String]           // Why this slot is recommended

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    var hasConflicts: Bool {
        !conflicts.isEmpty
    }

    var scoreCategory: ScoreCategory {
        if score >= 90 { return .excellent }
        else if score >= 75 { return .good }
        else if score >= 50 { return .fair }
        else { return .poor }
    }

    enum ScoreCategory: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

/// Result of a rescheduling operation
struct RescheduleResult {
    let success: Bool
    let originalEvent: UnifiedEvent
    let newTimeSlot: TimeSlot?
    let updatedEvent: UnifiedEvent?
    let conflicts: [UnifiedEvent]
    let message: String
}

/// Bulk rescheduling operation
struct BulkRescheduleOperation {
    let events: [UnifiedEvent]
    let strategy: RescheduleStrategy
    let constraints: RescheduleConstraints
    var results: [RescheduleResult] = []

    enum RescheduleStrategy {
        case sequential     // Reschedule events one after another
        case parallel       // Reschedule independently
        case optimized      // Find global optimal schedule
        case compact        // Pack events closely together
        case spread         // Spread events throughout the day
    }

    var successRate: Double {
        guard !results.isEmpty else { return 0 }
        let successful = results.filter { $0.success }.count
        return Double(successful) / Double(results.count) * 100
    }

    var hasConflicts: Bool {
        results.contains { !$0.conflicts.isEmpty }
    }
}

// MARK: - Smart Rescheduling Engine

class SmartReschedulingEngine {

    /// Find optimal time slots for rescheduling an event
    static func findTimeSlots(
        for event: UnifiedEvent,
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent],
        searchDays: Int = 14
    ) -> [TimeSlot] {
        var slots: [TimeSlot] = []

        let calendar = Calendar.current
        let now = Date()
        let searchEnd = calendar.date(byAdding: .day, value: searchDays, to: now) ?? now

        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Search each day
        var currentDay = calendar.startOfDay(for: now)
        while currentDay < searchEnd {
            // Get available hours for this day
            let availableHours = getAvailableHours(
                for: currentDay,
                duration: duration,
                constraints: constraints,
                allEvents: allEvents
            )

            for hour in availableHours {
                let slotStart = calendar.date(byAdding: .hour, value: hour, to: currentDay)!
                let slotEnd = slotStart.addingTimeInterval(duration)

                let conflicts = findConflicts(
                    start: slotStart,
                    end: slotEnd,
                    events: allEvents,
                    excludingEvent: event.id
                )

                let score = calculateSlotScore(
                    start: slotStart,
                    end: slotEnd,
                    originalEvent: event,
                    conflicts: conflicts,
                    constraints: constraints,
                    allEvents: allEvents
                )

                let reasons = generateReasons(
                    start: slotStart,
                    end: slotEnd,
                    score: score,
                    conflicts: conflicts,
                    constraints: constraints
                )

                slots.append(TimeSlot(
                    start: slotStart,
                    end: slotEnd,
                    score: score,
                    conflicts: conflicts,
                    reasons: reasons
                ))
            }

            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }

        // Sort by score (best first) and return top results
        return slots.sorted { $0.score > $1.score }.prefix(20).map { $0 }
    }

    /// Reschedule multiple events using bulk strategy
    static func bulkReschedule(
        events: [UnifiedEvent],
        strategy: BulkRescheduleOperation.RescheduleStrategy,
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> BulkRescheduleOperation {
        var operation = BulkRescheduleOperation(
            events: events,
            strategy: strategy,
            constraints: constraints
        )

        switch strategy {
        case .sequential:
            operation.results = rescheduleSequential(events: events, constraints: constraints, allEvents: allEvents)
        case .parallel:
            operation.results = rescheduleParallel(events: events, constraints: constraints, allEvents: allEvents)
        case .optimized:
            operation.results = rescheduleOptimized(events: events, constraints: constraints, allEvents: allEvents)
        case .compact:
            operation.results = rescheduleCompact(events: events, constraints: constraints, allEvents: allEvents)
        case .spread:
            operation.results = rescheduleSpread(events: events, constraints: constraints, allEvents: allEvents)
        }

        return operation
    }

    // MARK: - Private Helpers

    private static func getAvailableHours(
        for day: Date,
        duration: TimeInterval,
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [Int] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day)

        // Check preferred days of week
        if let preferredDays = constraints.preferredDaysOfWeek,
           !preferredDays.isEmpty,
           !preferredDays.contains(weekday) {
            return []
        }

        // Default working hours: 8 AM - 6 PM
        var startHour = 8
        var endHour = 18

        // Adjust based on preferred time range
        if let timeRange = constraints.preferredTimeRange {
            startHour = calendar.component(.hour, from: timeRange.start)
            endHour = calendar.component(.hour, from: timeRange.end)
        }

        return Array(startHour...endHour)
    }

    private static func findConflicts(
        start: Date,
        end: Date,
        events: [UnifiedEvent],
        excludingEvent: String
    ) -> [UnifiedEvent] {
        return events.filter { event in
            event.id != excludingEvent &&
            event.startDate < end &&
            event.endDate > start
        }
    }

    private static func calculateSlotScore(
        start: Date,
        end: Date,
        originalEvent: UnifiedEvent,
        conflicts: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> Double {
        var score: Double = 100

        // Penalty for conflicts
        if !conflicts.isEmpty {
            score -= Double(conflicts.count) * 30
        }

        // Penalty for being far from original time
        let originalTime = originalEvent.startDate
        let timeDifference = abs(start.timeIntervalSince(originalTime))
        let daysDifference = timeDifference / (24 * 60 * 60)
        score -= min(daysDifference * 5, 30)  // Max 30 point penalty

        // Bonus for preferred time range
        if let timeRange = constraints.preferredTimeRange {
            let slotTimeOfDay = Calendar.current.component(.hour, from: start)
            let preferredHour = Calendar.current.component(.hour, from: timeRange.start)

            if abs(slotTimeOfDay - preferredHour) <= 1 {
                score += 10
            }
        }

        // Bonus for maintaining same day of week
        let calendar = Calendar.current
        if calendar.component(.weekday, from: start) == calendar.component(.weekday, from: originalEvent.startDate) {
            score += 5
        }

        // Penalty for being outside working hours
        let hour = calendar.component(.hour, from: start)
        if hour < 8 || hour > 18 {
            score -= 20
        }

        // Bonus for having buffer time before/after
        if let bufferTime = constraints.bufferTime {
            let hasBufferBefore = !hasEventWithin(
                time: start.addingTimeInterval(-bufferTime),
                and: start,
                events: allEvents
            )
            let hasBufferAfter = !hasEventWithin(
                time: end,
                and: end.addingTimeInterval(bufferTime),
                events: allEvents
            )

            if hasBufferBefore && hasBufferAfter {
                score += 10
            }
        }

        return max(0, min(100, score))
    }

    private static func hasEventWithin(
        time start: Date,
        and end: Date,
        events: [UnifiedEvent]
    ) -> Bool {
        return events.contains { event in
            event.startDate < end && event.endDate > start
        }
    }

    private static func generateReasons(
        start: Date,
        end: Date,
        score: Double,
        conflicts: [UnifiedEvent],
        constraints: RescheduleConstraints
    ) -> [String] {
        var reasons: [String] = []

        if conflicts.isEmpty {
            reasons.append("No conflicts")
        } else {
            reasons.append("\(conflicts.count) conflict(s)")
        }

        let hour = Calendar.current.component(.hour, from: start)
        if hour >= 9 && hour <= 17 {
            reasons.append("During working hours")
        }

        if let timeRange = constraints.preferredTimeRange {
            let preferredHour = Calendar.current.component(.hour, from: timeRange.start)
            if abs(hour - preferredHour) <= 1 {
                reasons.append("Matches preferred time")
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: start)
        reasons.append("On \(dayName)")

        return reasons
    }

    // MARK: - Bulk Rescheduling Strategies

    private static func rescheduleSequential(
        events: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [RescheduleResult] {
        var results: [RescheduleResult] = []
        var updatedEvents = allEvents

        for event in events {
            let slots = findTimeSlots(
                for: event,
                constraints: constraints,
                allEvents: updatedEvents,
                searchDays: 14
            )

            if let bestSlot = slots.first(where: { $0.conflicts.isEmpty }) ?? slots.first {
                // Create updated event with new times
                let updatedEvent = UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: bestSlot.start,
                    endDate: bestSlot.end,
                    location: event.location,
                    description: event.description,
                    isAllDay: event.isAllDay,
                    source: event.source,
                    organizer: event.organizer,
                    originalEvent: event.originalEvent,
                    calendarId: event.calendarId,
                    calendarName: event.calendarName,
                    calendarColor: event.calendarColor
                )

                // Update the events list for next iteration
                updatedEvents.removeAll { $0.id == event.id }
                updatedEvents.append(updatedEvent)

                results.append(RescheduleResult(
                    success: true,
                    originalEvent: event,
                    newTimeSlot: bestSlot,
                    updatedEvent: updatedEvent,
                    conflicts: bestSlot.conflicts,
                    message: "Rescheduled to \(formatDate(bestSlot.start))"
                ))
            } else {
                results.append(RescheduleResult(
                    success: false,
                    originalEvent: event,
                    newTimeSlot: nil,
                    updatedEvent: nil,
                    conflicts: [],
                    message: "No suitable time slots found"
                ))
            }
        }

        return results
    }

    private static func rescheduleParallel(
        events: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [RescheduleResult] {
        return events.map { event in
            let slots = findTimeSlots(
                for: event,
                constraints: constraints,
                allEvents: allEvents,
                searchDays: 14
            )

            if let bestSlot = slots.first {
                let updatedEvent = UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: bestSlot.start,
                    endDate: bestSlot.end,
                    location: event.location,
                    description: event.description,
                    isAllDay: event.isAllDay,
                    source: event.source,
                    organizer: event.organizer,
                    originalEvent: event.originalEvent,
                    calendarId: event.calendarId,
                    calendarName: event.calendarName,
                    calendarColor: event.calendarColor
                )

                return RescheduleResult(
                    success: true,
                    originalEvent: event,
                    newTimeSlot: bestSlot,
                    updatedEvent: updatedEvent,
                    conflicts: bestSlot.conflicts,
                    message: "Rescheduled to \(formatDate(bestSlot.start))"
                )
            } else {
                return RescheduleResult(
                    success: false,
                    originalEvent: event,
                    newTimeSlot: nil,
                    updatedEvent: nil,
                    conflicts: [],
                    message: "No suitable time slots found"
                )
            }
        }
    }

    private static func rescheduleOptimized(
        events: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [RescheduleResult] {
        // Use sequential for now, could be enhanced with genetic algorithm
        return rescheduleSequential(events: events, constraints: constraints, allEvents: allEvents)
    }

    private static func rescheduleCompact(
        events: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [RescheduleResult] {
        // Sort events by duration (longest first)
        let sortedEvents = events.sorted {
            let duration1 = $0.endDate.timeIntervalSince($0.startDate)
            let duration2 = $1.endDate.timeIntervalSince($1.startDate)
            return duration1 > duration2
        }

        // Pack them tightly together
        var results: [RescheduleResult] = []
        var currentTime = Date()

        for event in sortedEvents {
            let slots = findTimeSlots(
                for: event,
                constraints: constraints,
                allEvents: allEvents,
                searchDays: 7  // Shorter search window for compact
            )

            // Find earliest available slot
            if let earliestSlot = slots.first(where: { $0.conflicts.isEmpty }) {
                let updatedEvent = UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: earliestSlot.start,
                    endDate: earliestSlot.end,
                    location: event.location,
                    description: event.description,
                    isAllDay: event.isAllDay,
                    source: event.source,
                    organizer: event.organizer,
                    originalEvent: event.originalEvent,
                    calendarId: event.calendarId,
                    calendarName: event.calendarName,
                    calendarColor: event.calendarColor
                )

                currentTime = earliestSlot.end

                results.append(RescheduleResult(
                    success: true,
                    originalEvent: event,
                    newTimeSlot: earliestSlot,
                    updatedEvent: updatedEvent,
                    conflicts: [],
                    message: "Compacted to \(formatDate(earliestSlot.start))"
                ))
            } else {
                results.append(RescheduleResult(
                    success: false,
                    originalEvent: event,
                    newTimeSlot: nil,
                    updatedEvent: nil,
                    conflicts: [],
                    message: "Could not compact schedule"
                ))
            }
        }

        return results
    }

    private static func rescheduleSpread(
        events: [UnifiedEvent],
        constraints: RescheduleConstraints,
        allEvents: [UnifiedEvent]
    ) -> [RescheduleResult] {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var results: [RescheduleResult] = []

        let totalDays = 7
        let eventsPerDay = max(1, events.count / totalDays)

        var dayOffset = 0
        for (index, event) in sortedEvents.enumerated() {
            if index > 0 && index % eventsPerDay == 0 {
                dayOffset += 1
            }

            let slots = findTimeSlots(
                for: event,
                constraints: constraints,
                allEvents: allEvents,
                searchDays: 14
            )

            // Filter slots to preferred day offset
            let calendar = Calendar.current
            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let targetDay = calendar.startOfDay(for: targetDate)

            let spreadSlots = slots.filter { slot in
                calendar.isDate(slot.start, inSameDayAs: targetDate)
            }

            if let spreadSlot = spreadSlots.first ?? slots.first {
                let updatedEvent = UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: spreadSlot.start,
                    endDate: spreadSlot.end,
                    location: event.location,
                    description: event.description,
                    isAllDay: event.isAllDay,
                    source: event.source,
                    organizer: event.organizer,
                    originalEvent: event.originalEvent,
                    calendarId: event.calendarId,
                    calendarName: event.calendarName,
                    calendarColor: event.calendarColor
                )

                results.append(RescheduleResult(
                    success: true,
                    originalEvent: event,
                    newTimeSlot: spreadSlot,
                    updatedEvent: updatedEvent,
                    conflicts: spreadSlot.conflicts,
                    message: "Spread to \(formatDate(spreadSlot.start))"
                ))
            } else {
                results.append(RescheduleResult(
                    success: false,
                    originalEvent: event,
                    newTimeSlot: nil,
                    updatedEvent: nil,
                    conflicts: [],
                    message: "Could not spread schedule"
                ))
            }
        }

        return results
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}
