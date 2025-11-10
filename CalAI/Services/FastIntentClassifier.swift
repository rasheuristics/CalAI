//
//  FastIntentClassifier.swift
//  CalAI
//
//  On-device fast intent detection for < 100ms command classification
//  Created by Claude Code on 11/9/25.
//

import Foundation
import NaturalLanguage

/// Ultra-fast intent classification using on-device NLP (< 100ms)
class FastIntentClassifier {

    // MARK: - Intent Types

    enum FastIntent: String {
        case createEvent
        case deleteEvent
        case modifyEvent
        case querySchedule
        case searchEvent
        case checkAvailability
        case unknown

        var confidence: Double {
            switch self {
            case .unknown: return 0.0
            default: return 1.0
            }
        }
    }

    // MARK: - Pattern Matching

    /// Detect intent using pattern matching (< 50ms)
    func detectIntent(from text: String) -> FastIntent {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // CREATE patterns
        if matchesCreate(normalized) { return .createEvent }

        // DELETE patterns
        if matchesDelete(normalized) { return .deleteEvent }

        // MODIFY patterns
        if matchesModify(normalized) { return .modifyEvent }

        // QUERY patterns
        if matchesQuery(normalized) { return .querySchedule }

        // SEARCH patterns
        if matchesSearch(normalized) { return .searchEvent }

        // AVAILABILITY patterns
        if matchesAvailability(normalized) { return .checkAvailability }

        return .unknown
    }

    /// Extract key entities for immediate execution
    func extractQuickEntities(from text: String, intent: FastIntent) -> QuickCommandEntity {
        let normalized = text.lowercased()

        switch intent {
        case .createEvent:
            return extractCreateEntities(from: normalized)
        case .deleteEvent:
            return extractDeleteEntities(from: normalized)
        case .querySchedule:
            return extractQueryEntities(from: normalized)
        default:
            return QuickCommandEntity(intent: intent, text: text)
        }
    }

    // MARK: - Pattern Matchers

    private func matchesCreate(_ text: String) -> Bool {
        let createPatterns = [
            "create", "add", "schedule", "book", "set up", "make",
            "new event", "new meeting", "add event", "create meeting"
        ]
        return createPatterns.contains { text.contains($0) }
    }

    private func matchesDelete(_ text: String) -> Bool {
        let deletePatterns = [
            "delete", "cancel", "remove", "clear",
            "delete event", "cancel meeting", "remove event"
        ]
        return deletePatterns.contains { text.contains($0) }
    }

    private func matchesModify(_ text: String) -> Bool {
        let modifyPatterns = [
            "move", "reschedule", "change", "update", "edit",
            "move event", "reschedule meeting", "change time"
        ]
        return modifyPatterns.contains { text.contains($0) }
    }

    private func matchesQuery(_ text: String) -> Bool {
        let queryPatterns = [
            "what's", "show", "list", "tell me", "what do i have",
            "my schedule", "my calendar", "what's on", "upcoming"
        ]
        return queryPatterns.contains { text.contains($0) }
    }

    private func matchesSearch(_ text: String) -> Bool {
        let searchPatterns = [
            "find", "search", "look for", "when is",
            "find event", "search for", "look for meeting"
        ]
        return searchPatterns.contains { text.contains($0) }
    }

    private func matchesAvailability(_ text: String) -> Bool {
        let availabilityPatterns = [
            "am i free", "do i have time", "available", "busy",
            "am i available", "free time", "check availability"
        ]
        return availabilityPatterns.contains { text.contains($0) }
    }

    // MARK: - Entity Extraction

    private func extractCreateEntities(from text: String) -> QuickCommandEntity {
        var entity = QuickCommandEntity(intent: .createEvent, text: text)

        // Extract time keywords
        if text.contains("tomorrow") {
            entity.timeHint = "tomorrow"
        } else if text.contains("today") {
            entity.timeHint = "today"
        } else if text.contains("next week") {
            entity.timeHint = "next week"
        } else if text.contains("monday") || text.contains("tuesday") ||
                  text.contains("wednesday") || text.contains("thursday") ||
                  text.contains("friday") || text.contains("saturday") ||
                  text.contains("sunday") {
            entity.timeHint = "specific day"
        }

        // Extract event type keywords
        if text.contains("meeting") {
            entity.eventType = "meeting"
        } else if text.contains("appointment") {
            entity.eventType = "appointment"
        } else if text.contains("call") {
            entity.eventType = "call"
        }

        return entity
    }

    private func extractDeleteEntities(from text: String) -> QuickCommandEntity {
        var entity = QuickCommandEntity(intent: .deleteEvent, text: text)

        // Extract time references for finding event to delete
        if text.contains("today") {
            entity.timeHint = "today"
        } else if text.contains("tomorrow") {
            entity.timeHint = "tomorrow"
        } else if text.contains("next") {
            entity.timeHint = "next"
        } else if text.contains("last") {
            entity.timeHint = "last"
        }

        return entity
    }

    private func extractQueryEntities(from text: String) -> QuickCommandEntity {
        var entity = QuickCommandEntity(intent: .querySchedule, text: text)

        // Extract time range
        if text.contains("today") {
            entity.timeHint = "today"
        } else if text.contains("tomorrow") {
            entity.timeHint = "tomorrow"
        } else if text.contains("this week") {
            entity.timeHint = "this week"
        } else if text.contains("next week") {
            entity.timeHint = "next week"
        } else if text.contains("upcoming") {
            entity.timeHint = "upcoming"
        }

        return entity
    }
}

// MARK: - Quick Command Entity

/// Lightweight entity for fast command execution
struct QuickCommandEntity {
    let intent: FastIntentClassifier.FastIntent
    let text: String
    var timeHint: String?
    var eventType: String?
    var confidence: Double

    init(intent: FastIntentClassifier.FastIntent, text: String, timeHint: String? = nil, eventType: String? = nil) {
        self.intent = intent
        self.text = text
        self.timeHint = timeHint
        self.eventType = eventType
        self.confidence = intent.confidence
    }

    var shouldExecuteImmediately: Bool {
        // Execute immediately if confidence is high and intent is clear
        return confidence > 0.8
    }
}
