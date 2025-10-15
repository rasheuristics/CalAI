import Foundation
import Contacts

// MARK: - Event Action Types

enum EventAction: String, Equatable {
    case create
    case update
    case delete
    case move
    case query
}

// MARK: - Extracted Entities

struct ExtractedEntities: Equatable {
    var action: EventAction
    var title: String?
    var attendees: [String] = []
    var attendeeNames: [String] = [] // For display/matching
    var time: Date?
    var duration: TimeInterval?
    var location: String?
    var calendar: String? // Calendar name/identifier
    var recurrence: RecurrencePattern?
    var confidence: Double = 0.0
    var missingFields: [String] = []

    // Context hints
    var eventType: String? // "lunch", "meeting", "call", etc.
    var isUrgent: Bool = false
    var isAllDay: Bool = false
}

// MARK: - Parse Result

enum ParseResult {
    case success(ExtractedEntities, confirmation: String)
    case needsClarification(ExtractedEntities, question: String)
    case failure(String)
}

// MARK: - Smart Event Parser

class SmartEventParser {

    // MARK: - Action Verb Patterns

    private static let actionPatterns: [EventAction: [String]] = [
        .create: [
            "create", "make", "schedule", "book", "set up", "arrange",
            "organize", "plan", "add", "put in", "jot down", "pencil in",
            "block off", "reserve", "set", "remind me", "new"
        ],
        .update: [
            "change", "update", "modify", "edit", "fix", "correct",
            "adjust", "revise", "alter"
        ],
        .move: [
            "shift", "push", "bump", "swap", "slide", "reschedule",
            "move", "postpone", "delay", "bring forward"
        ],
        .delete: [
            "drop", "nix", "delete", "kill", "scratch", "remove",
            "cancel", "clear", "erase", "get rid of"
        ],
        .query: [
            "what", "when", "where", "who", "show", "find", "list",
            "what's", "do i have", "am i free", "check", "tell me"
        ]
    ]

    // MARK: - Entity Patterns

    private static let attendeeIndicators = [
        "with", "meet", "see", "call", "lunch", "dinner", "hangout",
        "chat", "and", "invite", "inviting"
    ]

    private static let locationIndicators = [
        "at", "in", "@", "place", "location", "room", "building"
    ]

    private static let timeKeywords = [
        "tomorrow", "today", "tonight", "morning", "afternoon", "evening",
        "noon", "midnight", "next", "this", "later", "soon", "asap"
    ]

    private static let eventTypeKeywords = [
        "lunch", "dinner", "breakfast", "coffee", "meeting", "call",
        "standup", "review", "1-on-1", "one on one", "sync", "catch up",
        "interview", "demo", "presentation"
    ]

    // MARK: - Main Parse Function

    func parse(_ command: String) -> ParseResult {
        print("🔍 Parsing command: \"\(command)\"")

        let lowercased = command.lowercased()

        // 1. Detect action
        guard let action = detectAction(lowercased) else {
            return .failure("I didn't understand that command. Try 'schedule lunch with John tomorrow at noon'")
        }

        print("✅ Detected action: \(action.rawValue)")

        // 2. Extract all entities
        var entities = ExtractedEntities(action: action)

        entities.eventType = extractEventType(from: lowercased)
        entities.attendeeNames = extractAttendeeNames(from: command)
        entities.time = extractTime(from: lowercased)
        entities.duration = extractDuration(from: lowercased) ?? defaultDuration(for: entities.eventType)
        entities.location = extractLocation(from: command)
        entities.calendar = extractCalendar(from: lowercased)
        entities.recurrence = extractRecurrence(from: lowercased)
        entities.isAllDay = checkIfAllDay(from: lowercased)
        entities.isUrgent = checkIfUrgent(from: lowercased)

        // 3. Generate title
        entities.title = generateTitle(from: command, eventType: detectEventType(from: lowercased))

        // 4. Calculate confidence and missing fields
        entities.confidence = calculateConfidence(entities)
        entities.missingFields = findMissingFields(entities)

        print("📊 Confidence: \(String(format: "%.0f", entities.confidence * 100))%")
        print("📋 Extracted: title=\(entities.title ?? "nil"), attendees=\(entities.attendeeNames), time=\(entities.time?.description ?? "nil"), location=\(entities.location ?? "nil")")

        // 5. Determine result
        if entities.confidence >= 0.8 && entities.missingFields.isEmpty {
            let confirmation = generateConfirmation(entities)
            return .success(entities, confirmation: confirmation)
        } else if !entities.missingFields.isEmpty {
            let question = generateQuestion(for: entities.missingFields.first!)
            return .needsClarification(entities, question: question)
        } else {
            let confirmation = generateConfirmation(entities)
            return .success(entities, confirmation: confirmation)
        }
    }

    // MARK: - Action Detection

    private func detectAction(_ text: String) -> EventAction? {
        // Check each action pattern
        for (action, verbs) in Self.actionPatterns {
            for verb in verbs {
                // Match whole words only
                let pattern = "\\b\(verb)\\b"
                if text.range(of: pattern, options: .regularExpression) != nil {
                    return action
                }
            }
        }

        // Default to create if contains event-related words
        if containsEventKeywords(text) {
            return .create
        }

        return nil
    }

    private func containsEventKeywords(_ text: String) -> Bool {
        let keywords = Self.eventTypeKeywords + Self.timeKeywords
        return keywords.contains { text.contains($0) }
    }

    // MARK: - Event Type Detection

    private func extractEventType(from text: String) -> String? {
        for keyword in Self.eventTypeKeywords {
            if text.contains(keyword) {
                return keyword
            }
        }
        return nil
    }

    // MARK: - Attendee Extraction

    func extractAttendeeNames(from text: String) -> [String] {
        var names: [String] = []

        // Pattern 1: "with [Name]"
        let withPattern = #"(?:with|meet|see)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"#
        if let regex = try? NSRegularExpression(pattern: withPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    names.append(String(text[range]))
                }
            }
        }

        // Pattern 2: "and [Name]"
        let andPattern = #"and\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"#
        if let regex = try? NSRegularExpression(pattern: andPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let name = String(text[range])
                    if !names.contains(name) {
                        names.append(name)
                    }
                }
            }
        }

        // Pattern 3: Special groups
        let lowercased = text.lowercased()
        if lowercased.contains("team") && !lowercased.contains("with team") {
            names.append("@team")
        }
        if lowercased.contains("everyone") {
            names.append("@everyone")
        }

        return names
    }

    // MARK: - Time Extraction

    func extractTime(from text: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        let lowercased = text.lowercased()

        // Pattern 1: "tomorrow" with optional time
        if lowercased.contains("tomorrow") {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                let time = extractSpecificTime(from: text) ?? defaultTime(for: text)
                return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: tomorrow)
            }
        }

        // Pattern 2: "today" with optional time
        if lowercased.contains("today") || lowercased.contains("tonight") {
            let time = extractSpecificTime(from: text) ?? defaultTime(for: text)
            return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now)
        }

        // Pattern 3: "next [day of week]" or just "[day of week]"
        if let weekday = extractWeekday(from: lowercased) {
            if let targetDate = nextDate(for: weekday, from: now) {
                // Apply specific time if provided, otherwise use default time for the context
                let time = extractSpecificTime(from: text) ?? defaultTime(for: text)
                return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate)
            }
        }

        // Pattern 4: "next week" without specific day
        if lowercased.contains("next week") {
            // Default to next Monday at default time
            if let targetDate = nextDate(for: 2, from: now) { // Monday = 2
                let time = extractSpecificTime(from: text) ?? defaultTime(for: text)
                return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate)
            }
        }

        // Pattern 5: Specific time today (without "today" keyword)
        if let time = extractSpecificTime(from: text) {
            return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now)
        }

        // Pattern 6: Relative times ("in 2 hours", "in 30 minutes")
        if lowercased.contains("in ") {
            return extractRelativeTime(from: text)
        }

        return nil
    }

    private func extractSpecificTime(from text: String) -> (hour: Int, minute: Int)? {
        // Pattern: "at 2pm", "at 14:30", "2 pm", "noon"

        // Special cases
        if text.contains("noon") {
            return (12, 0)
        }
        if text.contains("midnight") {
            return (0, 0)
        }

        // Pattern: "at XX:XX am/pm" or "at XX am/pm"
        let patterns = [
            #"at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            #"at\s+(\d{1,2})"# // 24-hour format
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    var hour = 0
                    var minute = 0

                    if let hourRange = Range(match.range(at: 1), in: text) {
                        hour = Int(text[hourRange]) ?? 0
                    }

                    if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: text) {
                        minute = Int(text[minuteRange]) ?? 0
                    }

                    if match.numberOfRanges > 3, let ampmRange = Range(match.range(at: 3), in: text) {
                        let ampm = String(text[ampmRange]).lowercased()
                        if ampm == "pm" && hour < 12 {
                            hour += 12
                        } else if ampm == "am" && hour == 12 {
                            hour = 0
                        }
                    }

                    return (hour, minute)
                }
            }
        }

        return nil
    }

    private func extractWeekday(from text: String) -> Int? {
        let weekdays = [
            ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5),
            ("friday", 6), ("saturday", 7), ("sunday", 1)
        ]

        for (day, number) in weekdays {
            if text.contains(day) {
                return number
            }
        }

        return nil
    }

    private func nextDate(for weekday: Int, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)

        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }

    private func extractRelativeTime(from text: String) -> Date? {
        // "in 2 hours", "in 30 minutes"
        let pattern = #"in\s+(\d+)\s+(hour|hours|minute|minutes|day|days)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let valueRange = Range(match.range(at: 1), in: text),
                   let unitRange = Range(match.range(at: 2), in: text) {
                    let value = Int(text[valueRange]) ?? 0
                    let unit = String(text[unitRange])

                    let calendar = Calendar.current
                    if unit.hasPrefix("hour") {
                        return calendar.date(byAdding: .hour, value: value, to: Date())
                    } else if unit.hasPrefix("minute") {
                        return calendar.date(byAdding: .minute, value: value, to: Date())
                    } else if unit.hasPrefix("day") {
                        return calendar.date(byAdding: .day, value: value, to: Date())
                    }
                }
            }
        }

        return nil
    }

    private func defaultTime(for text: String) -> (hour: Int, minute: Int) {
        if text.contains("morning") { return (9, 0) }
        if text.contains("afternoon") { return (14, 0) }
        if text.contains("evening") || text.contains("tonight") { return (18, 0) }
        if text.contains("lunch") { return (12, 0) }
        if text.contains("breakfast") { return (8, 0) }
        if text.contains("dinner") { return (18, 0) }
        return (9, 0) // Default to 9am
    }

    // MARK: - Duration Extraction

    private func extractDuration(from text: String) -> TimeInterval? {
        // Pattern: "for X hours/minutes"
        let patterns = [
            (#"for\s+(\d+)\s+hour"#, 3600.0),
            (#"for\s+(\d+)\s+minute"#, 60.0),
            (#"(\d+)\s+hour"#, 3600.0),
            (#"half\s+hour|30\s+min"#, 1800.0)
        ]

        for (pattern, multiplier) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: text) {
                        if let value = Double(text[valueRange]) {
                            return value * multiplier
                        }
                    } else {
                        return multiplier // For patterns like "half hour"
                    }
                }
            }
        }

        return nil
    }

    private func defaultDuration(for eventType: String?) -> TimeInterval {
        guard let type = eventType else { return 3600 } // 1 hour default

        switch type {
        case "lunch", "dinner": return 3600 // 1 hour
        case "coffee", "standup": return 1800 // 30 min
        case "call": return 1800 // 30 min
        case "meeting": return 3600 // 1 hour
        case "review", "demo": return 3600 // 1 hour
        case "1-on-1", "one on one": return 1800 // 30 min
        default: return 3600 // 1 hour
        }
    }

    // MARK: - Location Extraction

    func extractLocation(from text: String) -> String? {
        // Pattern: "at [Location]"
        let pattern = #"(?:at|in|@)\s+(?:the\s+)?([A-Z][A-Za-z\s]+(?:Street|St|Ave|Avenue|Road|Rd|Cafe|Coffee|Shop|Office|Room|Building|Center)?)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }

    // MARK: - Calendar Extraction

    private func extractCalendar(from text: String) -> String? {
        if text.contains("google") || text.contains("work") { return "google" }
        if text.contains("personal") { return "personal" }
        if text.contains("icloud") || text.contains("ios") { return "ios" }
        if text.contains("outlook") || text.contains("office") { return "outlook" }
        return nil // Will use default
    }

    // MARK: - Recurrence Extraction

    private func extractRecurrence(from text: String) -> RecurrencePattern? {
        if text.contains("every day") || text.contains("daily") { return .daily }
        if text.contains("every week") || text.contains("weekly") { return .weekly }
        if text.contains("every month") || text.contains("monthly") { return .monthly }
        if text.contains("every year") || text.contains("yearly") { return .yearly }
        return .none
    }

    // MARK: - Helper Checks

    private func checkIfAllDay(from text: String) -> Bool {
        return text.contains("all day") || text.contains("full day")
    }

    private func checkIfUrgent(from text: String) -> Bool {
        return text.contains("asap") || text.contains("urgent") || text.contains("soon")
    }

    private func detectEventType(from text: String) -> String? {
        for keyword in Self.eventTypeKeywords {
            if text.contains(keyword) {
                return keyword
            }
        }
        return nil
    }

    // MARK: - Title Generation

    func generateTitle(from text: String, eventType: String?) -> String {
        // If we have a detected event type, use it as base
        if let type = eventType {
            return type.capitalized
        }

        // Remove action verbs
        var cleanText = text
        for (_, verbs) in Self.actionPatterns {
            for verb in verbs {
                cleanText = cleanText.replacingOccurrences(of: "\\b\(verb)\\b", with: "", options: [.regularExpression, .caseInsensitive])
            }
        }

        // Remove common noise words
        let noiseWords = ["with", "tomorrow", "today", "tonight", "at", "on", "next", "this", "am", "pm", "a", "an", "the"]
        for word in noiseWords {
            cleanText = cleanText.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Clean up whitespace
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanText = cleanText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // If we have something reasonable, use it
        if cleanText.count > 2 {
            return cleanText.capitalized
        }

        // Default fallback
        return "Meeting"
    }

    private func generateSmartTitle(entities: ExtractedEntities, originalText: String) -> String {
        let text = originalText.lowercased()

        // With attendees
        if !entities.attendeeNames.isEmpty {
            let firstAttendee = entities.attendeeNames[0]
            if let eventType = entities.eventType {
                return "\(eventType.capitalized) with \(firstAttendee)"
            }
            return "Meeting with \(firstAttendee)"
        }

        // By event type
        if let eventType = entities.eventType {
            return eventType.capitalized
        }

        // Generic
        return "Event"
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(_ entities: ExtractedEntities) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // Required fields (higher weight)
        if entities.title != nil { score += 2.0 }
        maxScore += 2.0

        if entities.time != nil { score += 2.0 }
        maxScore += 2.0

        // Optional but helpful fields
        if !entities.attendeeNames.isEmpty { score += 1.0 }
        maxScore += 1.0

        if entities.location != nil { score += 0.5 }
        maxScore += 0.5

        if entities.duration != nil { score += 0.5 }
        maxScore += 0.5

        return maxScore > 0 ? score / maxScore : 0.0
    }

    // MARK: - Missing Fields

    private func findMissingFields(_ entities: ExtractedEntities) -> [String] {
        var missing: [String] = []

        if entities.time == nil {
            missing.append("time")
        }

        // Only ask for attendees if event type suggests it
        if entities.attendeeNames.isEmpty && needsAttendees(entities.eventType) {
            missing.append("attendees")
        }

        return missing
    }

    private func needsAttendees(_ eventType: String?) -> Bool {
        guard let type = eventType else { return false }
        let meetingTypes = ["meeting", "lunch", "dinner", "coffee", "call", "1-on-1", "sync"]
        return meetingTypes.contains(type)
    }

    // MARK: - Confirmation Generation

    private func generateConfirmation(_ entities: ExtractedEntities) -> String {
        var parts: [String] = []

        parts.append("Got it")

        if let title = entities.title {
            parts.append(title)
        }

        if !entities.attendeeNames.isEmpty {
            let names = entities.attendeeNames.prefix(2).joined(separator: " and ")
            let extra = entities.attendeeNames.count > 2 ? " +\(entities.attendeeNames.count - 2)" : ""
            parts.append("with \(names)\(extra)")
        }

        if let time = entities.time {
            parts.append(formatNaturalTime(time))
        }

        if let location = entities.location {
            parts.append("at \(location)")
        }

        return parts.joined(separator: ", ") + "-cool?"
    }

    private func formatNaturalTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if calendar.isDateInToday(date) {
            return "today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Question Generation

    private func generateQuestion(for field: String) -> String {
        switch field {
        case "time":
            return "What time works for you?"
        case "attendees":
            return "Who should I invite?"
        case "location":
            return "Where's this happening?"
        default:
            return "Can you provide more details?"
        }
    }
}
