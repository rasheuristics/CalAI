import Foundation
import EventKit

// MARK: - Meeting Follow-Up Models

/// Complete post-meeting follow-up package
struct MeetingFollowUp: Identifiable {
    let id: String
    let eventId: String
    let eventTitle: String
    let meetingDate: Date

    let summary: MeetingSummary
    let actionItems: [ActionItem]
    let decisions: [Decision]
    let followUpMeetings: [FollowUpMeeting]
    let participants: [String]

    var createdAt: Date
    var completedActionItems: Int {
        actionItems.filter { $0.isCompleted }.count
    }

    var totalActionItems: Int {
        actionItems.count
    }

    var completionPercentage: Double {
        guard totalActionItems > 0 else { return 0 }
        return Double(completedActionItems) / Double(totalActionItems) * 100
    }
}

/// AI-generated meeting summary
struct MeetingSummary {
    let highlights: String          // 2-3 sentence summary of what happened
    let outcomes: [String]           // Key outcomes and results
    let topics: [String]             // Topics discussed
    let duration: TimeInterval       // Actual meeting duration
    let attendance: String?          // Who attended
}

/// Action item extracted from meeting
struct ActionItem: Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let assignee: String?            // Who's responsible
    let dueDate: Date?               // When it's due
    let priority: ActionPriority
    let category: ActionCategory
    var isCompleted: Bool
    var completedDate: Date?
    let sourceText: String?          // Original text it was extracted from

    enum ActionPriority: String, Codable {
        case urgent = "Urgent"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: String {
            switch self {
            case .urgent: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "blue"
            }
        }

        var sortOrder: Int {
            switch self {
            case .urgent: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }

    enum ActionCategory: String, Codable {
        case task = "Task"
        case followUp = "Follow Up"
        case research = "Research"
        case decision = "Decision Needed"
        case communication = "Communication"
        case other = "Other"

        var icon: String {
            switch self {
            case .task: return "checkmark.circle"
            case .followUp: return "arrow.right.circle"
            case .research: return "magnifyingglass.circle"
            case .decision: return "questionmark.circle"
            case .communication: return "envelope.circle"
            case .other: return "circle"
            }
        }
    }
}

/// Decision made during meeting
struct Decision: Identifiable {
    let id: UUID
    let decision: String
    let context: String?
    let madeBy: String?
    let timestamp: Date?
}

/// Suggested follow-up meeting
struct FollowUpMeeting: Identifiable {
    let id: UUID
    let title: String
    let suggestedDate: Date?
    let purpose: String
    let attendees: [String]
    var isScheduled: Bool
}

// MARK: - Follow-Up Generator

class MeetingFollowUpGenerator {

    /// Generate follow-up from completed event
    static func generate(
        for event: UnifiedEvent,
        notes: String? = nil,
        allEvents: [UnifiedEvent] = []
    ) -> MeetingFollowUp {
        let summary = generateSummary(for: event, notes: notes)
        let actionItems = extractActionItems(from: notes ?? event.description)
        let decisions = extractDecisions(from: notes ?? event.description)
        let followUpMeetings = suggestFollowUpMeetings(for: event, actionItems: actionItems)
        let participants = extractParticipants(from: event)

        return MeetingFollowUp(
            id: UUID().uuidString,
            eventId: event.id,
            eventTitle: event.title,
            meetingDate: event.startDate,
            summary: summary,
            actionItems: actionItems,
            decisions: decisions,
            followUpMeetings: followUpMeetings,
            participants: participants,
            createdAt: Date()
        )
    }

    // MARK: - Private Helpers

    private static func generateSummary(for event: UnifiedEvent, notes: String?) -> MeetingSummary {
        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Extract topics from title and notes
        let topics = extractTopics(from: event.title, notes: notes)

        // Generate highlights
        let highlights = generateHighlights(title: event.title, topics: topics, duration: duration)

        // Extract outcomes
        let outcomes = extractOutcomes(from: notes)

        // Generate attendance string
        let attendance = event.organizer

        return MeetingSummary(
            highlights: highlights,
            outcomes: outcomes,
            topics: topics,
            duration: duration,
            attendance: attendance
        )
    }

    private static func generateHighlights(title: String, topics: [String], duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let topicsStr = topics.isEmpty ? "various topics" : topics.prefix(3).joined(separator: ", ")
        return "Completed \(minutes)-minute \(title) discussing \(topicsStr)."
    }

    private static func extractTopics(from title: String, notes: String?) -> [String] {
        var topics: [String] = []

        // Extract from notes if available
        if let notes = notes {
            let lines = notes.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("topics:") || trimmed.lowercased().hasPrefix("discussed:") {
                    let topicLine = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":")
                    let items = topicLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    topics.append(contentsOf: items.filter { !$0.isEmpty })
                }
            }
        }

        // Fallback to title parsing
        if topics.isEmpty {
            let titleWords = title.components(separatedBy: " ").filter { word in
                !["meeting", "call", "sync", "with", "and", "the", "a"].contains(word.lowercased())
            }
            if !titleWords.isEmpty {
                topics.append(titleWords.joined(separator: " "))
            }
        }

        return Array(Set(topics)).prefix(5).map { String($0) }
    }

    private static func extractOutcomes(from notes: String?) -> [String] {
        guard let notes = notes else { return [] }

        var outcomes: [String] = []
        let lines = notes.components(separatedBy: .newlines)

        let outcomeKeywords = ["outcome:", "result:", "conclusion:", "agreed:", "decided:"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for keyword in outcomeKeywords {
                if trimmed.lowercased().hasPrefix(keyword) {
                    let outcome = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    if !outcome.isEmpty {
                        outcomes.append(outcome)
                    }
                }
            }
        }

        return outcomes
    }

    private static func extractActionItems(from notes: String?) -> [ActionItem] {
        guard let notes = notes else { return [] }

        var actionItems: [ActionItem] = []
        let lines = notes.components(separatedBy: .newlines)

        // Keywords that indicate action items
        let actionKeywords = ["todo:", "action:", "task:", "[] ", "[ ]", "- [ ]"]
        let assigneePattern = "@([A-Za-z]+)"
        let dueDatePattern = "by ([A-Za-z]+ [0-9]+)|due ([A-Za-z]+ [0-9]+)"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var isActionItem = false
            var cleanedText = trimmed

            // Check for action keywords
            for keyword in actionKeywords {
                if trimmed.lowercased().hasPrefix(keyword) {
                    isActionItem = true
                    cleanedText = trimmed.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                    break
                }
            }

            // Check for checkbox markers
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("[ ]") {
                isActionItem = true
                cleanedText = trimmed
                    .replacingOccurrences(of: "- [ ]", with: "")
                    .replacingOccurrences(of: "[ ]", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            if isActionItem && !cleanedText.isEmpty {
                // Extract assignee
                var assignee: String?
                if let regex = try? NSRegularExpression(pattern: assigneePattern),
                   let match = regex.firstMatch(in: cleanedText, range: NSRange(cleanedText.startIndex..., in: cleanedText)),
                   let nameRange = Range(match.range(at: 1), in: cleanedText) {
                    assignee = String(cleanedText[nameRange])
                    cleanedText = cleanedText.replacingOccurrences(of: "@\(assignee!)", with: "").trimmingCharacters(in: .whitespaces)
                }

                // Determine priority
                let priority: ActionItem.ActionPriority
                if cleanedText.lowercased().contains("urgent") || cleanedText.lowercased().contains("asap") {
                    priority = .urgent
                } else if cleanedText.lowercased().contains("important") || cleanedText.lowercased().contains("high priority") {
                    priority = .high
                } else if cleanedText.lowercased().contains("low priority") {
                    priority = .low
                } else {
                    priority = .medium
                }

                // Determine category
                let category: ActionItem.ActionCategory
                if cleanedText.lowercased().contains("follow up") || cleanedText.lowercased().contains("follow-up") {
                    category = .followUp
                } else if cleanedText.lowercased().contains("research") || cleanedText.lowercased().contains("investigate") {
                    category = .research
                } else if cleanedText.lowercased().contains("decide") || cleanedText.lowercased().contains("decision") {
                    category = .decision
                } else if cleanedText.lowercased().contains("email") || cleanedText.lowercased().contains("contact") || cleanedText.lowercased().contains("reach out") {
                    category = .communication
                } else {
                    category = .task
                }

                actionItems.append(ActionItem(
                    id: UUID(),
                    title: cleanedText,
                    description: nil,
                    assignee: assignee,
                    dueDate: nil,
                    priority: priority,
                    category: category,
                    isCompleted: false,
                    completedDate: nil,
                    sourceText: trimmed
                ))
            }
        }

        return actionItems
    }

    private static func extractDecisions(from notes: String?) -> [Decision] {
        guard let notes = notes else { return [] }

        var decisions: [Decision] = []
        let lines = notes.components(separatedBy: .newlines)

        let decisionKeywords = ["decided:", "decision:", "agreed:", "resolved:"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for keyword in decisionKeywords {
                if trimmed.lowercased().hasPrefix(keyword) {
                    let decision = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    if !decision.isEmpty {
                        decisions.append(Decision(
                            id: UUID(),
                            decision: decision,
                            context: nil,
                            madeBy: nil,
                            timestamp: nil
                        ))
                    }
                }
            }
        }

        return decisions
    }

    private static func suggestFollowUpMeetings(for event: UnifiedEvent, actionItems: [ActionItem]) -> [FollowUpMeeting] {
        var followUps: [FollowUpMeeting] = []

        // Check if this is a recurring meeting type that needs follow-up
        let title = event.title.lowercased()
        if title.contains("1:1") || title.contains("one-on-one") {
            // Suggest next 1:1 in 1-2 weeks
            if let nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: event.startDate) {
                followUps.append(FollowUpMeeting(
                    id: UUID(),
                    title: event.title,
                    suggestedDate: nextDate,
                    purpose: "Continue discussion from previous 1:1",
                    attendees: event.organizer != nil ? [event.organizer!] : [],
                    isScheduled: false
                ))
            }
        } else if title.contains("standup") {
            // Daily standup - suggest next business day
            if let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) {
                followUps.append(FollowUpMeeting(
                    id: UUID(),
                    title: event.title,
                    suggestedDate: nextDate,
                    purpose: "Daily standup",
                    attendees: [],
                    isScheduled: false
                ))
            }
        }

        // Suggest follow-up if there are many open action items
        if actionItems.count >= 3 {
            if let followUpDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: event.startDate) {
                followUps.append(FollowUpMeeting(
                    id: UUID(),
                    title: "\(event.title) - Follow-up",
                    suggestedDate: followUpDate,
                    purpose: "Review action items and progress",
                    attendees: event.organizer != nil ? [event.organizer!] : [],
                    isScheduled: false
                ))
            }
        }

        return followUps
    }

    private static func extractParticipants(from event: UnifiedEvent) -> [String] {
        var participants: [String] = []

        if let organizer = event.organizer, !organizer.isEmpty {
            participants.append(organizer)
        }

        // Try to extract from title
        let titleParticipants = extractAttendeesFromTitle(event.title)
        participants.append(contentsOf: titleParticipants)

        return Array(Set(participants))
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
}

// MARK: - Codable Conformance

extension MeetingFollowUp: Codable {
    enum CodingKeys: String, CodingKey {
        case id, eventId, eventTitle, meetingDate, summary, actionItems, decisions, followUpMeetings, participants, createdAt
    }
}

extension MeetingSummary: Codable {}
extension ActionItem: Codable {}
extension Decision: Codable {}
extension FollowUpMeeting: Codable {}
