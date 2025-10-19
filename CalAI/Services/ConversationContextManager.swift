import Foundation

/// Manages conversation context for multi-turn dialogues
class ConversationContextManager {

    // MARK: - Types

    struct Message: Codable {
        let role: String  // "user" or "assistant"
        let content: String
        let timestamp: Date

        init(role: String, content: String, timestamp: Date = Date()) {
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }
    }

    struct TrackedEntity {
        let key: String
        let value: Any
        let timestamp: Date
        let expiresAfter: TimeInterval  // Auto-expire after this duration

        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > expiresAfter
        }
    }

    // MARK: - Properties

    private var messageHistory: [Message] = []
    private var entities: [String: TrackedEntity] = [:]
    private var lastDiscussedEvent: UnifiedEvent?
    private var lastDiscussedEvents: [UnifiedEvent] = []  // For "the second one", "the last one"
    private var lastQueryTimeRange: (start: Date, end: Date)?
    private var pendingAction: String?  // Awaiting confirmation

    private let maxHistoryCount = 10  // Keep last 10 messages
    private let defaultEntityExpiration: TimeInterval = 300  // 5 minutes

    // MARK: - Message Management

    func addUserMessage(_ content: String) {
        let message = Message(role: "user", content: content)
        messageHistory.append(message)
        cleanupOldMessages()

        print("📝 Context: Added user message: \(content)")
    }

    func addAssistantMessage(_ content: String) {
        let message = Message(role: "assistant", content: content)
        messageHistory.append(message)
        cleanupOldMessages()

        print("📝 Context: Added assistant message: \(content.prefix(50))...")
    }

    private func cleanupOldMessages() {
        if messageHistory.count > maxHistoryCount {
            messageHistory.removeFirst(messageHistory.count - maxHistoryCount)
        }
    }

    func clearHistory() {
        messageHistory.removeAll()
        entities.removeAll()
        lastDiscussedEvent = nil
        lastDiscussedEvents.removeAll()
        lastQueryTimeRange = nil
        pendingAction = nil

        print("🧹 Context: Cleared conversation history")
    }

    // MARK: - Entity Tracking

    func trackEntity(key: String, value: Any, expiresAfter: TimeInterval? = nil) {
        let expiration = expiresAfter ?? defaultEntityExpiration
        let entity = TrackedEntity(
            key: key,
            value: value,
            timestamp: Date(),
            expiresAfter: expiration
        )
        entities[key] = entity

        print("🏷️ Context: Tracked entity '\(key)'")
    }

    func getEntity(key: String) -> Any? {
        guard let entity = entities[key], !entity.isExpired else {
            entities.removeValue(forKey: key)
            return nil
        }
        return entity.value
    }

    func trackEvent(_ event: UnifiedEvent) {
        lastDiscussedEvent = event
        trackEntity(key: "lastEvent", value: event, expiresAfter: 600)  // 10 minutes

        print("📅 Context: Tracked event '\(event.title)'")
    }

    func trackEvents(_ events: [UnifiedEvent]) {
        lastDiscussedEvents = events
        if let first = events.first {
            lastDiscussedEvent = first
        }
        trackEntity(key: "lastEvents", value: events, expiresAfter: 600)

        print("📅 Context: Tracked \(events.count) events")
    }

    func trackQueryTimeRange(start: Date, end: Date) {
        lastQueryTimeRange = (start, end)
        trackEntity(key: "lastQueryTimeRange", value: (start, end), expiresAfter: 600)

        print("🕐 Context: Tracked time range: \(start) to \(end)")
    }

    func setPendingAction(_ action: String) {
        pendingAction = action
        trackEntity(key: "pendingAction", value: action, expiresAfter: 180)  // 3 minutes

        print("⏳ Context: Set pending action: \(action)")
    }

    // MARK: - Pronoun Resolution

    func resolveEventReference(_ reference: String, in events: [UnifiedEvent]) -> UnifiedEvent? {
        let lowercased = reference.lowercased()

        // Direct pronouns
        if lowercased.contains("it") || lowercased.contains("that") || lowercased.contains("this") {
            return lastDiscussedEvent
        }

        // Ordinal references
        if lowercased.contains("first") || lowercased.contains("1st") {
            return lastDiscussedEvents.first
        }

        if lowercased.contains("second") || lowercased.contains("2nd") {
            return lastDiscussedEvents.count >= 2 ? lastDiscussedEvents[1] : nil
        }

        if lowercased.contains("third") || lowercased.contains("3rd") {
            return lastDiscussedEvents.count >= 3 ? lastDiscussedEvents[2] : nil
        }

        if lowercased.contains("last") || lowercased.contains("final") {
            return lastDiscussedEvents.last
        }

        // Time-based references
        if lowercased.contains("next") || lowercased.contains("upcoming") {
            let now = Date()
            return events
                .filter { $0.startDate > now }
                .sorted { $0.startDate < $1.startDate }
                .first
        }

        return nil
    }

    // MARK: - Context Prompt Building

    func buildContextPrompt() -> String {
        var parts: [String] = []

        // Conversation history
        if !messageHistory.isEmpty {
            parts.append("Recent conversation:")
            for message in messageHistory.suffix(6) {  // Last 6 messages
                let prefix = message.role == "user" ? "User" : "Assistant"
                parts.append("\(prefix): \(message.content)")
            }
        }

        // Last discussed event
        if let event = lastDiscussedEvent {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            parts.append("\nLast discussed event: '\(event.title)' on \(formatter.string(from: event.startDate))")
        }

        // Last discussed events (for ordinal references)
        if !lastDiscussedEvents.isEmpty {
            parts.append("\nRecent events list:")
            for (index, event) in lastDiscussedEvents.prefix(5).enumerated() {
                parts.append("  \(index + 1). \(event.title) at \(event.startDate.formatted(.dateTime.hour().minute()))")
            }
        }

        // Pending action
        if let action = pendingAction {
            parts.append("\nPending action awaiting confirmation: \(action)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Context Summary (for LLM)

    func getSummary() -> String {
        var items: [String] = []

        if messageHistory.count > 0 {
            items.append("\(messageHistory.count) messages")
        }

        if lastDiscussedEvent != nil {
            items.append("tracking event")
        }

        if !lastDiscussedEvents.isEmpty {
            items.append("\(lastDiscussedEvents.count) events in context")
        }

        if pendingAction != nil {
            items.append("pending action")
        }

        return items.isEmpty ? "No context" : items.joined(separator: ", ")
    }

    // MARK: - Cleanup

    func cleanupExpiredEntities() {
        let expiredKeys = entities.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            entities.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            print("🧹 Context: Removed \(expiredKeys.count) expired entities")
        }
    }
}
