//
//  ProactiveSuggestionsManager.swift
//  CalAI
//
//  AI-powered proactive suggestions and notifications
//  Created by Claude Code on 11/9/25.
//

import Foundation
import EventKit
import CoreLocation
import Combine

// MARK: - Suggestion Types

enum SuggestionType: String, Codable {
    case addTravelTime = "add_travel_time"
    case declineConflict = "decline_conflict"
    case rescheduleOverload = "reschedule_overload"
    case adjustReminder = "adjust_reminder"
    case blockFocusTime = "block_focus_time"
    case prepareForMeeting = "prepare_for_meeting"
}

enum SuggestionPriority: String, Codable {
    case low
    case medium
    case high
    case urgent

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

struct ProactiveSuggestion: Identifiable, Codable {
    let id: String
    let type: SuggestionType
    let priority: SuggestionPriority
    let title: String
    let message: String
    let actionTitle: String
    let relatedEventId: String?
    let createdAt: Date
    var isRead: Bool
    var isDismissed: Bool

    // Action data
    let actionData: [String: String]?

    init(
        id: String = UUID().uuidString,
        type: SuggestionType,
        priority: SuggestionPriority,
        title: String,
        message: String,
        actionTitle: String,
        relatedEventId: String? = nil,
        actionData: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.relatedEventId = relatedEventId
        self.createdAt = Date()
        self.isRead = false
        self.isDismissed = false
        self.actionData = actionData
    }
}

// MARK: - Proactive Suggestions Manager

class ProactiveSuggestionsManager: ObservableObject {
    static let shared = ProactiveSuggestionsManager()

    @Published var activeSuggestions: [ProactiveSuggestion] = []
    @Published var suggestionBadgeCount: Int = 0

    private let userDefaults = UserDefaults.standard
    private let suggestionsKey = "proactive_suggestions"
    private var cancellables = Set<AnyCancellable>()

    // User behavior tracking
    private var lastEventCheckTime: Date?
    private var typicalWorkHours: (start: Int, end: Int) = (9, 17) // 9 AM - 5 PM default
    private var averageCommuteDuration: TimeInterval = 1800 // 30 minutes default

    init() {
        loadSuggestions()
        setupBadgeCount()
    }

    // MARK: - Suggestion Generation

    /// Analyze calendar and generate proactive suggestions
    func analyzeCalen darAndGenerateSuggestions(events: [UnifiedEvent], travelTimeManager: TravelTimeManager?) {
        print("🤖 Analyzing calendar for proactive suggestions...")

        var newSuggestions: [ProactiveSuggestion] = []

        // 1. Check for events needing travel time
        newSuggestions.append(contentsOf: suggestTravelTime(for: events, travelTimeManager: travelTimeManager))

        // 2. Detect conflicts and suggest declining
        newSuggestions.append(contentsOf: suggestConflictResolution(for: events))

        // 3. Analyze workload and suggest rescheduling
        newSuggestions.append(contentsOf: suggestReschedulingForOverload(for: events))

        // 4. Suggest reminder adjustments
        newSuggestions.append(contentsOf: suggestReminderAdjustments(for: events))

        // 5. Suggest focus time blocking
        newSuggestions.append(contentsOf: suggestFocusTimeBlocking(for: events))

        // 6. Suggest meeting preparation
        newSuggestions.append(contentsOf: suggestMeetingPreparation(for: events))

        // Add new suggestions that don't already exist
        for suggestion in newSuggestions {
            if !activeSuggestions.contains(where: { $0.id == suggestion.id }) &&
               !isDuplicateSuggestion(suggestion) {
                activeSuggestions.append(suggestion)
            }
        }

        // Sort by priority and date
        activeSuggestions.sort { suggestion1, suggestion2 in
            if suggestion1.priority.sortOrder != suggestion2.priority.sortOrder {
                return suggestion1.priority.sortOrder < suggestion2.priority.sortOrder
            }
            return suggestion1.createdAt > suggestion2.createdAt
        }

        saveSuggestions()
        print("✅ Generated \(newSuggestions.count) new suggestions")
    }

    // MARK: - Travel Time Suggestions

    private func suggestTravelTime(for events: [UnifiedEvent], travelTimeManager: TravelTimeManager?) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let now = Date()
        let upcomingWindow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        for event in events {
            // Only check future events in the next 7 days
            guard event.startDate > now && event.startDate < upcomingWindow else { continue }

            // Check if event has location but no travel time buffer
            guard let location = event.location, !location.isEmpty else { continue }

            // Check if there's a previous event close to this one
            if let previousEvent = findPreviousEvent(before: event, in: events),
               let previousLocation = previousEvent.location, !previousLocation.isEmpty,
               previousLocation.lowercased() != location.lowercased() {

                let timeBetween = event.startDate.timeIntervalSince(previousEvent.endDate)

                // If less than typical commute time, suggest adding travel buffer
                if timeBetween < averageCommuteDuration {
                    let suggestion = ProactiveSuggestion(
                        type: .addTravelTime,
                        priority: .high,
                        title: "Add Travel Time",
                        message: "You have only \(Int(timeBetween / 60)) minutes between '\(previousEvent.title)' at \(previousLocation) and '\(event.title)' at \(location). Consider adding travel time.",
                        actionTitle: "Add 30 min buffer",
                        relatedEventId: event.id,
                        actionData: [
                            "eventId": event.id,
                            "suggestedBuffer": "1800",
                            "previousEventId": previousEvent.id
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    // MARK: - Conflict Resolution

    private func suggestConflictResolution(for events: [UnifiedEvent]) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let now = Date()

        // Find overlapping events
        for (index, event1) in events.enumerated() {
            guard event1.startDate > now else { continue }

            for event2 in events.dropFirst(index + 1) {
                if eventsOverlap(event1, event2) {
                    let suggestion = ProactiveSuggestion(
                        type: .declineConflict,
                        priority: .urgent,
                        title: "Schedule Conflict",
                        message: "'\(event1.title)' and '\(event2.title)' overlap on \(formatDate(event1.startDate)). You may need to decline one.",
                        actionTitle: "Resolve conflict",
                        relatedEventId: event1.id,
                        actionData: [
                            "event1Id": event1.id,
                            "event2Id": event2.id
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    // MARK: - Workload-Based Rescheduling

    private func suggestReschedulingForOverload(for events: [UnifiedEvent]) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let calendar = Calendar.current
        let now = Date()

        // Group events by day
        var eventsByDay: [Date: [UnifiedEvent]] = [:]
        for event in events {
            guard event.startDate > now else { continue }
            let dayStart = calendar.startOfDay(for: event.startDate)
            eventsByDay[dayStart, default: []].append(event)
        }

        // Check for overloaded days (more than 8 hours of meetings)
        for (day, dayEvents) in eventsByDay {
            let totalDuration = dayEvents.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = totalDuration / 3600

            if hours > 8 {
                // Find optional/movable events
                let movableEvents = dayEvents.filter { event in
                    // Events without many attendees are easier to move
                    return event.attendees?.count ?? 0 <= 2
                }

                if let eventToMove = movableEvents.first {
                    let suggestion = ProactiveSuggestion(
                        type: .rescheduleOverload,
                        priority: .medium,
                        title: "Heavy Meeting Day",
                        message: "You have \(String(format: "%.1f", hours)) hours of meetings on \(formatDate(day)). Consider rescheduling '\(eventToMove.title)' to reduce workload.",
                        actionTitle: "Suggest new time",
                        relatedEventId: eventToMove.id,
                        actionData: [
                            "eventId": eventToMove.id,
                            "currentDay": ISO8601DateFormatter().string(from: day)
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    // MARK: - Reminder Adjustments

    private func suggestReminderAdjustments(for events: [UnifiedEvent]) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let now = Date()

        for event in events {
            // Check events happening soon (next 24 hours)
            let timeUntilEvent = event.startDate.timeIntervalSince(now)
            guard timeUntilEvent > 0 && timeUntilEvent < 86400 else { continue }

            // Suggest earlier reminder for important events with location
            if event.location != nil && !event.location!.isEmpty {
                let hoursUntil = timeUntilEvent / 3600
                if hoursUntil < 2 && hoursUntil > 0.5 {
                    let suggestion = ProactiveSuggestion(
                        type: .adjustReminder,
                        priority: .low,
                        title: "Reminder Suggestion",
                        message: "'\(event.title)' starts in \(Int(hoursUntil)) hour(s). Set a reminder to prepare and account for travel time.",
                        actionTitle: "Set reminder",
                        relatedEventId: event.id,
                        actionData: [
                            "eventId": event.id,
                            "reminderMinutes": "30"
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    // MARK: - Focus Time Blocking

    private func suggestFocusTimeBlocking(for events: [UnifiedEvent]) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let calendar = Calendar.current
        let now = Date()

        // Find days with no focus time (long gaps for deep work)
        for dayOffset in 1...5 { // Check next 5 days
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: targetDay)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayEvents = events.filter { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }.sorted { $0.startDate < $1.startDate }

            // Look for gaps of 2+ hours for focus time
            if dayEvents.count > 0 {
                for i in 0..<dayEvents.count - 1 {
                    let gapDuration = dayEvents[i + 1].startDate.timeIntervalSince(dayEvents[i].endDate)
                    if gapDuration >= 7200 { // 2 hours
                        let suggestion = ProactiveSuggestion(
                            type: .blockFocusTime,
                            priority: .low,
                            title: "Focus Time Available",
                            message: "You have a \(Int(gapDuration / 3600))-hour gap on \(formatDate(targetDay)). Consider blocking it for focused work.",
                            actionTitle: "Block focus time",
                            relatedEventId: nil,
                            actionData: [
                                "suggestedStart": ISO8601DateFormatter().string(from: dayEvents[i].endDate),
                                "duration": String(Int(gapDuration / 60))
                            ]
                        )
                        suggestions.append(suggestion)
                        break // Only suggest one per day
                    }
                }
            }
        }

        return suggestions
    }

    // MARK: - Meeting Preparation

    private func suggestMeetingPreparation(for events: [UnifiedEvent]) -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []
        let now = Date()

        for event in events {
            let timeUntilEvent = event.startDate.timeIntervalSince(now)

            // Suggest preparation for important meetings 1-4 hours before
            if timeUntilEvent > 3600 && timeUntilEvent < 14400 {
                if let attendees = event.attendees, attendees.count > 3 {
                    let suggestion = ProactiveSuggestion(
                        type: .prepareForMeeting,
                        priority: .medium,
                        title: "Meeting Preparation",
                        message: "'\(event.title)' with \(attendees.count) attendees starts in \(Int(timeUntilEvent / 3600)) hour(s). Take time to review agenda and materials.",
                        actionTitle: "Prepare now",
                        relatedEventId: event.id,
                        actionData: [
                            "eventId": event.id
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    // MARK: - Helper Methods

    private func findPreviousEvent(before event: UnifiedEvent, in events: [UnifiedEvent]) -> UnifiedEvent? {
        return events
            .filter { $0.endDate <= event.startDate }
            .sorted { $0.endDate > $1.endDate }
            .first
    }

    private func eventsOverlap(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }

    private func isDuplicateSuggestion(_ new: ProactiveSuggestion) -> Bool {
        return activeSuggestions.contains { existing in
            existing.type == new.type &&
            existing.relatedEventId == new.relatedEventId &&
            !existing.isDismissed
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Suggestion Actions

    func markAsRead(_ suggestionId: String) {
        if let index = activeSuggestions.firstIndex(where: { $0.id == suggestionId }) {
            activeSuggestions[index].isRead = true
            saveSuggestions()
        }
    }

    func dismissSuggestion(_ suggestionId: String) {
        if let index = activeSuggestions.firstIndex(where: { $0.id == suggestionId }) {
            activeSuggestions[index].isDismissed = true
            saveSuggestions()
        }
    }

    func clearDismissedSuggestions() {
        activeSuggestions.removeAll { $0.isDismissed }
        saveSuggestions()
    }

    // MARK: - Persistence

    private func loadSuggestions() {
        if let data = userDefaults.data(forKey: suggestionsKey),
           let decoded = try? JSONDecoder().decode([ProactiveSuggestion].self, from: data) {
            activeSuggestions = decoded.filter { !$0.isDismissed }
        }
    }

    private func saveSuggestions() {
        if let encoded = try? JSONEncoder().encode(activeSuggestions) {
            userDefaults.set(encoded, forKey: suggestionsKey)
        }
    }

    private func setupBadgeCount() {
        $activeSuggestions
            .map { suggestions in
                suggestions.filter { !$0.isRead && !$0.isDismissed }.count
            }
            .assign(to: &$suggestionBadgeCount)
    }
}
