import Foundation
import EventKit

// MARK: - Meeting Preparation Models

/// Complete meeting preparation package
struct MeetingPreparation: Identifiable {
    let id: String
    let eventId: String
    let title: String
    let startDate: Date
    let endDate: Date

    // Core information
    let briefing: MeetingBriefing
    let attendees: [AttendeeContext]
    let relatedItems: [RelatedItem]
    let suggestedActions: [SuggestedAction]

    var timeUntilMeeting: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    var isUpcoming: Bool {
        timeUntilMeeting > 0 && timeUntilMeeting < 24 * 60 * 60 // Within 24 hours
    }
}

/// AI-generated meeting briefing
struct MeetingBriefing {
    let summary: String              // One-sentence summary
    let objective: String?           // Meeting purpose/goal
    let agenda: [String]             // Agenda items extracted from notes
    let preparation: [String]        // What to prepare beforehand
    let keyTopics: [String]          // Main discussion points
    let meetingType: MeetingCategory
}

enum MeetingCategory: String, Codable {
    case oneOnOne = "1:1"
    case teamMeeting = "Team Meeting"
    case clientMeeting = "Client Meeting"
    case interview = "Interview"
    case presentation = "Presentation"
    case workshop = "Workshop"
    case review = "Review"
    case standup = "Standup"
    case allHands = "All-Hands"
    case other = "Meeting"

    var icon: String {
        switch self {
        case .oneOnOne: return "person.2"
        case .teamMeeting: return "person.3"
        case .clientMeeting: return "briefcase"
        case .interview: return "person.crop.circle.badge.questionmark"
        case .presentation: return "person.wave.2"
        case .workshop: return "wrench.and.screwdriver"
        case .review: return "checkmark.circle"
        case .standup: return "figure.stand"
        case .allHands: return "person.3.sequence"
        case .other: return "calendar"
        }
    }
}

/// Context about meeting attendees
struct AttendeeContext: Identifiable {
    let id = UUID()
    let name: String
    let email: String?
    let role: String?                // Title/role if available
    let lastMeeting: Date?           // Last time you met
    let meetingFrequency: String?    // "Weekly", "Monthly", etc.
    let notes: String?               // Any relevant context
}

/// Related documents, links, or resources
struct RelatedItem: Identifiable {
    let id = UUID()
    let title: String
    let type: RelatedItemType
    let url: URL?
    let snippet: String?             // Preview text
}

enum RelatedItemType: String {
    case document = "Document"
    case link = "Link"
    case email = "Email"
    case note = "Note"
    case previousMeeting = "Previous Meeting"

    var icon: String {
        switch self {
        case .document: return "doc.text"
        case .link: return "link"
        case .email: return "envelope"
        case .note: return "note.text"
        case .previousMeeting: return "clock.arrow.circlepath"
        }
    }
}

/// Suggested pre-meeting actions
struct SuggestedAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: ActionPriority
    let estimatedTime: Int?          // Minutes
    let completed: Bool
}

enum ActionPriority: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        }
    }
}

// MARK: - Meeting Preparation Generator

class MeetingPreparationGenerator {

    /// Generate meeting preparation from event
    static func generate(for event: UnifiedEvent, allEvents: [UnifiedEvent] = []) -> MeetingPreparation {
        let briefing = generateBriefing(for: event)
        let attendees = extractAttendees(from: event, allEvents: allEvents)
        let relatedItems = findRelatedItems(for: event, allEvents: allEvents)
        let actions = generateSuggestedActions(for: event, briefing: briefing)

        return MeetingPreparation(
            id: event.id,
            eventId: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            briefing: briefing,
            attendees: attendees,
            relatedItems: relatedItems,
            suggestedActions: actions
        )
    }

    // MARK: - Private Helpers

    private static func generateBriefing(for event: UnifiedEvent) -> MeetingBriefing {
        let category = categorizeMeeting(title: event.title, notes: event.description)
        let agenda = extractAgenda(from: event.description)
        let keyTopics = extractKeyTopics(from: event.title, notes: event.description)

        let summary = generateSummary(
            title: event.title,
            category: category,
            location: event.location
        )

        let objective = extractObjective(from: event.description)
        let preparation = generatePreparationItems(category: category, agenda: agenda)

        return MeetingBriefing(
            summary: summary,
            objective: objective,
            agenda: agenda,
            preparation: preparation,
            keyTopics: keyTopics,
            meetingType: category
        )
    }

    private static func categorizeMeeting(title: String, notes: String?) -> MeetingCategory {
        let combined = (title + " " + (notes ?? "")).lowercased()

        if combined.contains("1:1") || combined.contains("one-on-one") || combined.contains("1-1") {
            return .oneOnOne
        } else if combined.contains("standup") || combined.contains("stand-up") || combined.contains("daily") {
            return .standup
        } else if combined.contains("client") || combined.contains("customer") {
            return .clientMeeting
        } else if combined.contains("interview") {
            return .interview
        } else if combined.contains("presentation") || combined.contains("demo") {
            return .presentation
        } else if combined.contains("workshop") || combined.contains("training") {
            return .workshop
        } else if combined.contains("review") || combined.contains("retrospective") || combined.contains("retro") {
            return .review
        } else if combined.contains("all-hands") || combined.contains("town hall") || combined.contains("townhall") {
            return .allHands
        } else if combined.contains("team") {
            return .teamMeeting
        }

        return .other
    }

    private static func generateSummary(title: String, category: MeetingCategory, location: String?) -> String {
        var summary = "\(category.rawValue): \(title)"
        if let location = location, !location.isEmpty {
            summary += " at \(location)"
        }
        return summary
    }

    private static func extractObjective(from notes: String?) -> String? {
        guard let notes = notes else { return nil }

        let objectiveKeywords = ["objective:", "goal:", "purpose:", "aim:"]
        for keyword in objectiveKeywords {
            if let range = notes.range(of: keyword, options: .caseInsensitive) {
                let startIndex = range.upperBound
                if let lineEnd = notes[startIndex...].firstIndex(of: "\n") {
                    return String(notes[startIndex..<lineEnd]).trimmingCharacters(in: .whitespaces)
                } else {
                    return String(notes[startIndex...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }

    private static func extractAgenda(from notes: String?) -> [String] {
        guard let notes = notes else { return [] }

        var agendaItems: [String] = []
        let lines = notes.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match numbered items, bullet points, or dashes
            if trimmed.range(of: "^[0-9]+\\.", options: .regularExpression) != nil ||
               trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[0-9]+\\.\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                if !cleaned.isEmpty {
                    agendaItems.append(cleaned)
                }
            }
        }

        return agendaItems
    }

    private static func extractKeyTopics(from title: String, notes: String?) -> [String] {
        var topics: [String] = []

        // Extract from title (e.g., "Q4 Planning Meeting" -> "Q4 Planning")
        let titleWords = title.components(separatedBy: " ")
        if titleWords.count > 1 {
            let meaningfulWords = titleWords.filter { word in
                !["meeting", "call", "sync", "with", "and", "the"].contains(word.lowercased())
            }
            if !meaningfulWords.isEmpty {
                topics.append(meaningfulWords.joined(separator: " "))
            }
        }

        // Look for topic indicators in notes
        if let notes = notes {
            let topicKeywords = ["topic:", "topics:", "discuss:", "discussion:"]
            for keyword in topicKeywords {
                if let range = notes.range(of: keyword, options: .caseInsensitive) {
                    let startIndex = range.upperBound
                    if let lineEnd = notes[startIndex...].firstIndex(of: "\n") {
                        let topicLine = String(notes[startIndex..<lineEnd]).trimmingCharacters(in: .whitespaces)
                        let items = topicLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        topics.append(contentsOf: items.filter { !$0.isEmpty })
                    }
                }
            }
        }

        return Array(Set(topics)).prefix(5).map { String($0) }
    }

    private static func generatePreparationItems(category: MeetingCategory, agenda: [String]) -> [String] {
        var items: [String] = []

        switch category {
        case .oneOnOne:
            items.append("Review previous 1:1 notes")
            items.append("Prepare discussion topics or updates")
        case .standup:
            items.append("What you did yesterday")
            items.append("What you're doing today")
            items.append("Any blockers")
        case .clientMeeting:
            items.append("Review client account history")
            items.append("Prepare status update or demo")
        case .interview:
            items.append("Review candidate resume")
            items.append("Prepare interview questions")
        case .presentation:
            items.append("Review presentation slides")
            items.append("Test demo environment")
        case .review:
            items.append("Review materials to be discussed")
            items.append("Note key feedback points")
        default:
            if !agenda.isEmpty {
                items.append("Review agenda items")
            }
            items.append("Prepare any necessary materials")
        }

        return items
    }

    private static func extractAttendees(from event: UnifiedEvent, allEvents: [UnifiedEvent]) -> [AttendeeContext] {
        var attendees: [AttendeeContext] = []

        // Extract from organizer
        if let organizer = event.organizer, !organizer.isEmpty {
            let lastMeeting = findLastMeetingWith(person: organizer, events: allEvents, excluding: event.id)
            attendees.append(AttendeeContext(
                name: organizer,
                email: nil,
                role: nil,
                lastMeeting: lastMeeting,
                meetingFrequency: calculateMeetingFrequency(person: organizer, events: allEvents),
                notes: nil
            ))
        }

        // Try to extract from title (e.g., "Meeting with John Doe")
        let titleAttendees = extractAttendeesFromTitle(event.title)
        for name in titleAttendees {
            if !attendees.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                let lastMeeting = findLastMeetingWith(person: name, events: allEvents, excluding: event.id)
                attendees.append(AttendeeContext(
                    name: name,
                    email: nil,
                    role: nil,
                    lastMeeting: lastMeeting,
                    meetingFrequency: calculateMeetingFrequency(person: name, events: allEvents),
                    notes: nil
                ))
            }
        }

        return attendees
    }

    private static func extractAttendeesFromTitle(_ title: String) -> [String] {
        var names: [String] = []

        let patterns = [
            "(?:meeting|call|sync|1:1|catch up) with ([A-Z][a-z]+ [A-Z][a-z]+)",
            "([A-Z][a-z]+ [A-Z][a-z]+) (?:meeting|call|sync|1:1)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               let nameRange = Range(match.range(at: 1), in: title) {
                names.append(String(title[nameRange]))
            }
        }

        return names
    }

    private static func findLastMeetingWith(person: String, events: [UnifiedEvent], excluding: String) -> Date? {
        let personLower = person.lowercased()
        let pastMeetings = events.filter { event in
            event.id != excluding &&
            event.endDate < Date() &&
            (event.title.lowercased().contains(personLower) ||
             event.organizer?.lowercased().contains(personLower) == true)
        }

        return pastMeetings.max(by: { $0.endDate < $1.endDate })?.endDate
    }

    private static func calculateMeetingFrequency(person: String, events: [UnifiedEvent]) -> String? {
        let personLower = person.lowercased()
        let meetings = events.filter { event in
            event.title.lowercased().contains(personLower) ||
            event.organizer?.lowercased().contains(personLower) == true
        }.sorted(by: { $0.startDate < $1.startDate })

        guard meetings.count >= 2 else { return nil }

        let intervals = zip(meetings.dropLast(), meetings.dropFirst()).map {
            $1.startDate.timeIntervalSince($0.startDate)
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let days = avgInterval / (24 * 60 * 60)

        if days < 2 {
            return "Daily"
        } else if days < 9 {
            return "Weekly"
        } else if days < 20 {
            return "Bi-weekly"
        } else if days < 35 {
            return "Monthly"
        } else {
            return "Occasionally"
        }
    }

    private static func findRelatedItems(for event: UnifiedEvent, allEvents: [UnifiedEvent]) -> [RelatedItem] {
        var items: [RelatedItem] = []

        // Find previous meetings with same attendees
        if let organizer = event.organizer {
            let previousMeetings = allEvents.filter { prev in
                prev.id != event.id &&
                prev.endDate < Date() &&
                prev.organizer == organizer &&
                prev.endDate > Date().addingTimeInterval(-30 * 24 * 60 * 60) // Last 30 days
            }.sorted(by: { $0.endDate > $1.endDate }).prefix(3)

            for meeting in previousMeetings {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                items.append(RelatedItem(
                    title: meeting.title,
                    type: .previousMeeting,
                    url: nil,
                    snippet: "Last met on \(formatter.string(from: meeting.endDate))"
                ))
            }
        }

        // Extract links from description
        if let notes = event.description {
            let links = extractURLs(from: notes)
            for link in links {
                items.append(RelatedItem(
                    title: link.host ?? "Link",
                    type: .link,
                    url: link,
                    snippet: link.absoluteString
                ))
            }
        }

        return items
    }

    private static func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text),
                  let url = URL(string: String(text[range])) else {
                return nil
            }
            return url
        }
    }

    private static func generateSuggestedActions(for event: UnifiedEvent, briefing: MeetingBriefing) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        // Add preparation-based actions
        for (index, item) in briefing.preparation.enumerated() {
            actions.append(SuggestedAction(
                title: item,
                description: "Prepare before the meeting",
                priority: index == 0 ? .high : .medium,
                estimatedTime: 10,
                completed: false
            ))
        }

        // Add location-based action for physical meetings
        if let location = event.location, !location.isEmpty,
           !location.lowercased().contains("zoom") &&
           !location.lowercased().contains("meet") &&
           !location.lowercased().contains("teams") {
            actions.append(SuggestedAction(
                title: "Check travel time to \(location)",
                description: "Ensure you have enough time to arrive",
                priority: .high,
                estimatedTime: 2,
                completed: false
            ))
        }

        return actions
    }
}
