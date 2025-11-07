import Foundation
import EventKit

// MARK: - Event Conflict Models

/// Represents a scheduling conflict between two or more events
struct ScheduleConflict: Identifiable, Equatable {
    let id: UUID
    let conflictingEvents: [UnifiedEvent]
    let overlapStart: Date
    let overlapEnd: Date
    let severity: ConflictSeverity

    init(events: [UnifiedEvent], overlapStart: Date, overlapEnd: Date) {
        self.id = UUID()
        self.conflictingEvents = events
        self.overlapStart = overlapStart
        self.overlapEnd = overlapEnd
        self.severity = ConflictSeverity.calculate(for: events, overlapDuration: overlapEnd.timeIntervalSince(overlapStart))
    }

    var overlapDuration: TimeInterval {
        overlapEnd.timeIntervalSince(overlapStart)
    }

    var overlapDurationFormatted: String {
        let hours = Int(overlapDuration) / 3600
        let minutes = (Int(overlapDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    static func == (lhs: ScheduleConflict, rhs: ScheduleConflict) -> Bool {
        lhs.id == rhs.id
    }
}

/// Severity level of a scheduling conflict
enum ConflictSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }

    var icon: String {
        switch self {
        case .low: return "exclamationmark.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "exclamationmark.bubble"
        }
    }

    /// Calculate severity based on event characteristics and overlap duration
    static func calculate(for events: [UnifiedEvent], overlapDuration: TimeInterval) -> ConflictSeverity {
        var score = 0

        // More events = higher severity
        if events.count >= 3 {
            score += 2
        } else if events.count == 2 {
            score += 1
        }

        // Longer overlap = higher severity
        let overlapMinutes = Int(overlapDuration) / 60
        if overlapMinutes >= 60 {
            score += 3
        } else if overlapMinutes >= 30 {
            score += 2
        } else if overlapMinutes >= 15 {
            score += 1
        }

        // All-day events are less severe
        let hasAllDayEvent = events.contains { $0.isAllDay }
        if hasAllDayEvent {
            score -= 1
        }

        // Events from different sources suggest higher importance
        let uniqueSources = Set(events.map { $0.source })
        if uniqueSources.count >= 2 {
            score += 1
        }

        // Map score to severity
        if score >= 5 {
            return .critical
        } else if score >= 3 {
            return .high
        } else if score >= 1 {
            return .medium
        } else {
            return .low
        }
    }
}

/// AI-generated suggestions for resolving conflicts
struct ConflictResolution: Identifiable {
    let id: UUID
    let conflict: ScheduleConflict
    let suggestions: [ResolutionSuggestion]

    init(conflict: ScheduleConflict, suggestions: [ResolutionSuggestion]) {
        self.id = UUID()
        self.conflict = conflict
        self.suggestions = suggestions
    }
}

/// Individual resolution suggestion
struct ResolutionSuggestion: Identifiable, Equatable {
    let id: UUID
    let type: ResolutionType
    let title: String
    let description: String
    let targetEvent: UnifiedEvent?
    let suggestedTime: Date?
    let confidence: Double // 0.0 to 1.0

    init(type: ResolutionType, title: String, description: String, targetEvent: UnifiedEvent? = nil, suggestedTime: Date? = nil, confidence: Double = 0.8) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.targetEvent = targetEvent
        self.suggestedTime = suggestedTime
        self.confidence = confidence
    }

    static func == (lhs: ResolutionSuggestion, rhs: ResolutionSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of resolution actions
enum ResolutionType: String, CaseIterable {
    case reschedule = "Reschedule"
    case decline = "Decline"
    case shorten = "Shorten"
    case markOptional = "Mark Optional"
    case noAction = "Keep Both"

    var icon: String {
        switch self {
        case .reschedule: return "calendar.badge.clock"
        case .decline: return "xmark.circle"
        case .shorten: return "arrow.down.right.and.arrow.up.left"
        case .markOptional: return "questionmark.circle"
        case .noAction: return "checkmark.circle"
        }
    }
}
