import Foundation
import Intents

/// Intent classification result
enum IntentType {
    case task       // User wants to create a task
    case event      // User wants to create an event
    case query      // User wants to query their calendar
    case update     // User wants to update something
    case delete     // User wants to delete something
    case unknown    // Could not determine intent

    var description: String {
        switch self {
        case .task: return "task"
        case .event: return "event"
        case .query: return "query"
        case .update: return "update"
        case .delete: return "delete"
        case .unknown: return "unknown"
        }
    }
}

/// Classification result with confidence
struct IntentClassification {
    let type: IntentType
    let confidence: Double
    let details: String
}

/// Uses Apple's Intents framework to classify user commands as tasks vs events
class IntentClassifier {

    // MARK: - Public API

    /// Classify a natural language command into task vs event
    func classify(_ text: String) -> IntentClassification {
        print("🔍 IntentClassifier: Analyzing '\(text)'")

        let lowercased = text.lowercased()

        // Step 1: Check for explicit queries first
        if isQuery(lowercased) {
            print("✅ Classified as QUERY")
            return IntentClassification(
                type: .query,
                confidence: 0.95,
                details: "Detected query keywords"
            )
        }

        // Step 2: Check for update/modify commands
        if isUpdate(lowercased) {
            print("✅ Classified as UPDATE")
            return IntentClassification(
                type: .update,
                confidence: 0.90,
                details: "Detected update keywords"
            )
        }

        // Step 3: Check for delete/cancel commands
        if isDelete(lowercased) {
            print("✅ Classified as DELETE")
            return IntentClassification(
                type: .delete,
                confidence: 0.90,
                details: "Detected delete keywords"
            )
        }

        // Step 4: Use Siri-inspired pattern matching for task vs event
        let taskScore = calculateTaskScore(lowercased)
        let eventScore = calculateEventScore(lowercased)

        print("📊 Task score: \(taskScore), Event score: \(eventScore)")

        if taskScore > eventScore && taskScore > 0.5 {
            print("✅ Classified as TASK (score: \(taskScore))")
            return IntentClassification(
                type: .task,
                confidence: taskScore,
                details: "Task-related patterns detected"
            )
        } else if eventScore > taskScore && eventScore > 0.5 {
            print("✅ Classified as EVENT (score: \(eventScore))")
            return IntentClassification(
                type: .event,
                confidence: eventScore,
                details: "Event-related patterns detected"
            )
        } else {
            print("⚠️ Could not confidently classify - defaulting to TASK")
            // Default to task if uncertain (safer default)
            return IntentClassification(
                type: .task,
                confidence: 0.6,
                details: "Low confidence, defaulted to task"
            )
        }
    }

    // MARK: - Query Detection

    private func isQuery(_ text: String) -> Bool {
        let queryPatterns = [
            // Question words
            "what", "when", "where", "who", "how many",
            // Explicit query commands
            "show", "list", "tell me", "what's", "what is",
            "do i have", "am i free", "check", "find",
            "see my", "view", "display",
            // Schedule checks
            "what's on my", "what do i have",
            "my schedule", "my calendar"
        ]

        return queryPatterns.contains { text.contains($0) }
    }

    // MARK: - Update Detection

    private func isUpdate(_ text: String) -> Bool {
        let updatePatterns = [
            "change", "update", "modify", "edit", "fix", "correct",
            "adjust", "revise", "alter", "move", "reschedule",
            "shift", "push", "bump", "postpone", "delay"
        ]

        return updatePatterns.contains { text.hasPrefix($0) || text.contains(" \($0) ") }
    }

    // MARK: - Delete Detection

    private func isDelete(_ text: String) -> Bool {
        let deletePatterns = [
            "delete", "remove", "cancel", "drop", "clear",
            "erase", "get rid of", "scratch", "kill", "nix"
        ]

        return deletePatterns.contains { text.hasPrefix($0) || text.contains(" \($0) ") }
    }

    // MARK: - Task vs Event Scoring (Inspired by Siri Intents)

    /// Calculate likelihood this is a task (INCreateTaskIntent-like)
    private func calculateTaskScore(_ text: String) -> Double {
        var score = 0.0

        // Strong task indicators (similar to INCreateTaskIntent patterns)
        let strongTaskPatterns = [
            "remind me to": 0.9,
            "i need to": 0.8,
            "i have to": 0.8,
            "i should": 0.7,
            "i want to": 0.6,
            "i wanna": 0.6,
            "todo": 0.9,
            "to-do": 0.9,
            "task": 0.8,
            "add task": 0.9,
            "create task": 0.9,
            "new task": 0.9,
            "reminder": 0.8,
            "add reminder": 0.9
        ]

        // Check strong patterns
        for (pattern, weight) in strongTaskPatterns {
            if text.contains(pattern) {
                score = max(score, weight)
                print("  ✓ Task pattern '\(pattern)' matched (weight: \(weight))")
            }
        }

        // Task verbs (actions without specific time/person context)
        let taskVerbs = [
            "buy", "get", "pick up", "grab", "purchase",
            "call", "email", "text", "message",
            "finish", "complete", "submit", "send",
            "read", "review", "check", "look at",
            "write", "draft", "prepare", "create",
            "clean", "organize", "fix", "repair"
        ]

        for verb in taskVerbs {
            // Look for verb at start or after "to"
            if text.hasPrefix(verb) || text.contains(" to \(verb)") {
                score = max(score, 0.6)
                print("  ✓ Task verb '\(verb)' found")
                break
            }
        }

        // Multiple tasks indicator (", and" or "then")
        if (text.contains(", and ") || text.contains(" then ")) && !text.contains("meeting") && !text.contains("schedule") {
            score = max(score, 0.7)
            print("  ✓ Multiple tasks indicated")
        }

        // No specific time = more likely a task
        if !hasSpecificTime(text) && !hasSpecificDate(text) {
            score += 0.2
            print("  ✓ No specific time/date = +0.2 task score")
        }

        // No attendees mentioned = more likely a task
        if !hasAttendees(text) {
            score += 0.1
            print("  ✓ No attendees = +0.1 task score")
        }

        return min(score, 1.0)
    }

    /// Calculate likelihood this is an event (INAddCalendarEventIntent-like)
    private func calculateEventScore(_ text: String) -> Double {
        var score = 0.0

        // Strong event indicators (similar to INAddCalendarEventIntent patterns)
        let strongEventPatterns = [
            "schedule": 0.9,
            "book": 0.8,
            "reserve": 0.8,
            "set up": 0.7,
            "arrange": 0.7,
            "plan": 0.6,
            "add to calendar": 0.9,
            "put on calendar": 0.9,
            "calendar event": 0.9,
            "appointment": 0.8,
            "meeting": 0.9
        ]

        // Check strong patterns
        for (pattern, weight) in strongEventPatterns {
            if text.contains(pattern) {
                score = max(score, weight)
                print("  ✓ Event pattern '\(pattern)' matched (weight: \(weight))")
            }
        }

        // Event types (social/professional gatherings)
        let eventTypes = [
            "meeting", "lunch", "dinner", "breakfast", "coffee",
            "call", "conference", "standup", "review", "interview",
            "demo", "presentation", "workshop", "training",
            "appointment", "session", "class", "party", "hangout"
        ]

        for eventType in eventTypes {
            if text.contains(eventType) {
                score = max(score, 0.8)
                print("  ✓ Event type '\(eventType)' found")
                break
            }
        }

        // Has specific time = more likely an event
        if hasSpecificTime(text) {
            score += 0.2
            print("  ✓ Specific time = +0.2 event score")
        }

        // Has specific date = more likely an event
        if hasSpecificDate(text) {
            score += 0.1
            print("  ✓ Specific date = +0.1 event score")
        }

        // Has attendees mentioned = strongly suggests event
        if hasAttendees(text) {
            score += 0.3
            print("  ✓ Attendees mentioned = +0.3 event score")
        }

        // Has location = more likely an event
        if hasLocation(text) {
            score += 0.2
            print("  ✓ Location mentioned = +0.2 event score")
        }

        return min(score, 1.0)
    }

    // MARK: - Helper Pattern Detectors

    private func hasSpecificTime(_ text: String) -> Bool {
        let timePatterns = [
            "at \\d{1,2}",           // "at 2", "at 14"
            "\\d{1,2}:\\d{2}",       // "2:30", "14:00"
            "\\d{1,2}\\s*[ap]m",     // "2pm", "2 pm"
            "noon", "midnight"
        ]

        return timePatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private func hasSpecificDate(_ text: String) -> Bool {
        let dateKeywords = [
            "today", "tomorrow", "tonight",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "next week", "this week", "next month"
        ]

        return dateKeywords.contains { text.contains($0) }
    }

    private func hasAttendees(_ text: String) -> Bool {
        // Look for attendee patterns followed by a capitalized name
        let pattern = "(with|meet|and|invite|inviting)\\s+[A-Z][a-z]+"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func hasLocation(_ text: String) -> Bool {
        let locationIndicators = [
            " at ", " in ", " @ ",
            "location", "room", "building", "office"
        ]

        return locationIndicators.contains { text.contains($0) }
    }
}
