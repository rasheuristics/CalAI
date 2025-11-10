//
//  ContextualMemoryManager.swift
//  CalAI
//
//  Contextual memory system for intelligent context retention across sessions
//  Created by Claude Code on 11/9/25.
//

import Foundation
import EventKit
import Combine

// MARK: - Memory Types

enum MemoryType: String, Codable {
    case userPreference = "user_preference"
    case conversationContext = "conversation_context"
    case eventPattern = "event_pattern"
    case locationFrequency = "location_frequency"
    case attendeeRelationship = "attendee_relationship"
    case timePreference = "time_preference"
}

enum MemoryImportance: String, Codable {
    case low
    case medium
    case high
    case critical

    var retentionDays: Int {
        switch self {
        case .low: return 7
        case .medium: return 30
        case .high: return 90
        case .critical: return 365
        }
    }
}

// MARK: - Memory Models

struct ConversationMemory: Codable, Identifiable {
    let id: String
    let type: MemoryType
    let importance: MemoryImportance
    let content: String
    let metadata: [String: String]
    let createdAt: Date
    var lastAccessedAt: Date
    var accessCount: Int

    init(
        id: String = UUID().uuidString,
        type: MemoryType,
        importance: MemoryImportance,
        content: String,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.importance = importance
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastAccessedAt = createdAt
        self.accessCount = 0
    }
}

struct UserPreference: Codable, Identifiable {
    let id: String
    let category: String
    let key: String
    let value: String
    let confidence: Double // 0.0 - 1.0, increases with repeated observations
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        category: String,
        key: String,
        value: String,
        confidence: Double = 0.5
    ) {
        self.id = id
        self.category = category
        self.key = key
        self.value = value
        self.confidence = confidence
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct EventPattern: Codable, Identifiable {
    let id: String
    let patternType: String // "recurring_meeting", "typical_lunch_time", "preferred_meeting_duration"
    let description: String
    let frequency: Int // How many times observed
    let lastObserved: Date
    let metadata: [String: String]

    init(
        id: String = UUID().uuidString,
        patternType: String,
        description: String,
        frequency: Int = 1,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.frequency = frequency
        self.lastObserved = Date()
        self.metadata = metadata
    }
}

// MARK: - Contextual Memory Manager

class ContextualMemoryManager: ObservableObject {
    static let shared = ContextualMemoryManager()

    @Published var conversationMemories: [ConversationMemory] = []
    @Published var userPreferences: [UserPreference] = []
    @Published var eventPatterns: [EventPattern] = []

    private let userDefaults = UserDefaults.standard
    private let memoriesKey = "contextual_memories"
    private let preferencesKey = "user_preferences"
    private let patternsKey = "event_patterns"

    // Memory limits to prevent unbounded growth
    private let maxMemories = 500
    private let maxPreferences = 100
    private let maxPatterns = 200

    init() {
        loadMemories()
        setupMemoryMaintenance()
    }

    // MARK: - Conversation Memory

    /// Store important context from conversations
    func storeConversationMemory(
        type: MemoryType,
        content: String,
        importance: MemoryImportance = .medium,
        metadata: [String: String] = [:]
    ) {
        let memory = ConversationMemory(
            type: type,
            importance: importance,
            content: content,
            metadata: metadata
        )

        conversationMemories.append(memory)
        pruneOldMemories()
        saveMemories()

        print("💾 Stored memory: \(content)")
    }

    /// Retrieve relevant memories based on query
    func retrieveRelevantMemories(for query: String, limit: Int = 5) -> [ConversationMemory] {
        let queryLower = query.lowercased()

        // Score memories by relevance
        var scoredMemories: [(ConversationMemory, Double)] = conversationMemories.map { memory in
            var score = 0.0

            // Content similarity (simple keyword matching)
            let contentLower = memory.content.lowercased()
            let queryWords = queryLower.split(separator: " ")
            for word in queryWords {
                if contentLower.contains(word) {
                    score += 1.0
                }
            }

            // Recency boost (more recent = higher score)
            let daysSinceAccess = Date().timeIntervalSince(memory.lastAccessedAt) / 86400
            score += max(0, 1.0 - (daysSinceAccess / 30))

            // Importance boost
            switch memory.importance {
            case .critical: score *= 2.0
            case .high: score *= 1.5
            case .medium: score *= 1.0
            case .low: score *= 0.5
            }

            // Access frequency boost
            score += Double(memory.accessCount) * 0.1

            return (memory, score)
        }

        // Sort by score and return top results
        scoredMemories.sort { $0.1 > $1.1 }
        let topMemories = scoredMemories.prefix(limit).map { $0.0 }

        // Update access tracking
        for memory in topMemories {
            if let index = conversationMemories.firstIndex(where: { $0.id == memory.id }) {
                conversationMemories[index].lastAccessedAt = Date()
                conversationMemories[index].accessCount += 1
            }
        }

        saveMemories()
        return topMemories
    }

    // MARK: - User Preferences Learning

    /// Learn user preferences from their behavior
    func learnPreference(category: String, key: String, value: String) {
        if let existingIndex = userPreferences.firstIndex(where: { $0.category == category && $0.key == key }) {
            // Update existing preference
            var preference = userPreferences[existingIndex]

            if preference.value == value {
                // Same preference observed again - increase confidence
                let newConfidence = min(1.0, preference.confidence + 0.1)
                userPreferences[existingIndex] = UserPreference(
                    id: preference.id,
                    category: preference.category,
                    key: preference.key,
                    value: preference.value,
                    confidence: newConfidence
                )
                print("📈 Reinforced preference: \(category).\(key) = \(value) (confidence: \(String(format: "%.1f", newConfidence * 100))%)")
            } else {
                // Different value - decrease confidence in old, create new if needed
                let newConfidence = max(0.0, preference.confidence - 0.15)
                if newConfidence > 0.2 {
                    userPreferences[existingIndex] = UserPreference(
                        id: preference.id,
                        category: preference.category,
                        key: preference.key,
                        value: preference.value,
                        confidence: newConfidence
                    )
                } else {
                    // Replace with new preference
                    userPreferences[existingIndex] = UserPreference(
                        category: category,
                        key: key,
                        value: value,
                        confidence: 0.6
                    )
                    print("🔄 Updated preference: \(category).\(key) = \(value)")
                }
            }
        } else {
            // New preference
            let preference = UserPreference(
                category: category,
                key: key,
                value: value,
                confidence: 0.5
            )
            userPreferences.append(preference)
            print("✨ Learned new preference: \(category).\(key) = \(value)")
        }

        prunePreferences()
        saveMemories()
    }

    /// Get learned preference
    func getPreference(category: String, key: String) -> String? {
        return userPreferences
            .filter { $0.category == category && $0.key == key }
            .sorted { $0.confidence > $1.confidence }
            .first?
            .value
    }

    /// Get all preferences in a category
    func getPreferences(category: String) -> [UserPreference] {
        return userPreferences
            .filter { $0.category == category }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Event Pattern Recognition

    /// Learn patterns from event creation
    func observeEventPattern(from event: UnifiedEvent) {
        // 1. Preferred meeting times
        let hour = Calendar.current.component(.hour, from: event.startDate)
        observePattern(
            type: "preferred_meeting_hour",
            description: "Meeting scheduled at \(hour):00",
            metadata: ["hour": String(hour)]
        )

        // 2. Typical meeting duration
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let durationMinutes = Int(duration / 60)
        observePattern(
            type: "typical_meeting_duration",
            description: "\(durationMinutes)-minute meeting",
            metadata: ["duration_minutes": String(durationMinutes)]
        )

        // 3. Frequent locations
        if let location = event.location, !location.isEmpty {
            observePattern(
                type: "frequent_location",
                description: "Meeting at \(location)",
                metadata: ["location": location]
            )
        }

        // 4. Regular attendees
        if let attendees = event.attendees {
            for attendee in attendees {
                if let email = attendee.emailAddress {
                    observePattern(
                        type: "frequent_attendee",
                        description: "Meeting with \(attendee.name ?? email)",
                        metadata: ["email": email, "name": attendee.name ?? ""]
                    )
                }
            }
        }

        // 5. Day of week preferences
        let weekday = Calendar.current.component(.weekday, from: event.startDate)
        let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
        observePattern(
            type: "preferred_weekday",
            description: "Meeting on \(weekdayName)",
            metadata: ["weekday": String(weekday), "weekday_name": weekdayName]
        )
    }

    private func observePattern(type: String, description: String, metadata: [String: String]) {
        if let existingIndex = eventPatterns.firstIndex(where: {
            $0.patternType == type &&
            $0.metadata == metadata
        }) {
            // Increment frequency
            var pattern = eventPatterns[existingIndex]
            eventPatterns[existingIndex] = EventPattern(
                id: pattern.id,
                patternType: pattern.patternType,
                description: pattern.description,
                frequency: pattern.frequency + 1,
                metadata: pattern.metadata
            )
        } else {
            // New pattern
            eventPatterns.append(EventPattern(
                patternType: type,
                description: description,
                metadata: metadata
            ))
        }

        prunePatterns()
        saveMemories()
    }

    /// Get most frequent patterns of a type
    func getFrequentPatterns(type: String, limit: Int = 5) -> [EventPattern] {
        return eventPatterns
            .filter { $0.patternType == type }
            .sorted { $0.frequency > $1.frequency }
            .prefix(limit)
            .map { $0 }
    }

    /// Get smart suggestions based on learned patterns
    func getSuggestionsForEventCreation() -> [String: Any] {
        var suggestions: [String: Any] = [:]

        // Suggest preferred meeting time
        let hourPatterns = getFrequentPatterns(type: "preferred_meeting_hour", limit: 3)
        if let topHour = hourPatterns.first?.metadata["hour"] {
            suggestions["preferred_hour"] = topHour
        }

        // Suggest typical duration
        let durationPatterns = getFrequentPatterns(type: "typical_meeting_duration", limit: 3)
        if let topDuration = durationPatterns.first?.metadata["duration_minutes"] {
            suggestions["typical_duration_minutes"] = topDuration
        }

        // Suggest frequent locations
        let locationPatterns = getFrequentPatterns(type: "frequent_location", limit: 5)
        suggestions["frequent_locations"] = locationPatterns.compactMap { $0.metadata["location"] }

        // Suggest frequent attendees
        let attendeePatterns = getFrequentPatterns(type: "frequent_attendee", limit: 10)
        suggestions["frequent_attendees"] = attendeePatterns.compactMap { pattern in
            ["email": pattern.metadata["email"] ?? "", "name": pattern.metadata["name"] ?? ""]
        }

        return suggestions
    }

    // MARK: - Context Generation for AI

    /// Generate contextual prompt augmentation for AI queries
    func generateContextForAI(query: String) -> String {
        var context = ""

        // 1. Retrieve relevant memories
        let relevantMemories = retrieveRelevantMemories(for: query, limit: 3)
        if !relevantMemories.isEmpty {
            context += "Context from past interactions:\n"
            for memory in relevantMemories {
                context += "- \(memory.content)\n"
            }
            context += "\n"
        }

        // 2. Include relevant preferences
        let queryLower = query.lowercased()
        var relevantPrefs: [UserPreference] = []

        if queryLower.contains("meeting") || queryLower.contains("schedule") {
            relevantPrefs.append(contentsOf: getPreferences(category: "meeting"))
        }
        if queryLower.contains("location") || queryLower.contains("where") {
            relevantPrefs.append(contentsOf: getPreferences(category: "location"))
        }
        if queryLower.contains("time") || queryLower.contains("when") {
            relevantPrefs.append(contentsOf: getPreferences(category: "time"))
        }

        if !relevantPrefs.isEmpty {
            context += "User preferences:\n"
            for pref in relevantPrefs.prefix(5) {
                let confidence = Int(pref.confidence * 100)
                context += "- \(pref.key): \(pref.value) (confidence: \(confidence)%)\n"
            }
            context += "\n"
        }

        // 3. Include learned patterns if query is about creating events
        if queryLower.contains("create") || queryLower.contains("schedule") || queryLower.contains("add") {
            let suggestions = getSuggestionsForEventCreation()

            if let hour = suggestions["preferred_hour"] as? String {
                context += "User typically schedules meetings around \(hour):00\n"
            }
            if let duration = suggestions["typical_duration_minutes"] as? String {
                context += "User's typical meeting duration: \(duration) minutes\n"
            }
            if let locations = suggestions["frequent_locations"] as? [String], !locations.isEmpty {
                context += "Frequent meeting locations: \(locations.prefix(3).joined(separator: ", "))\n"
            }
        }

        return context
    }

    // MARK: - Memory Maintenance

    private func setupMemoryMaintenance() {
        // Run maintenance daily
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.performMemoryMaintenance()
        }
    }

    private func performMemoryMaintenance() {
        print("🧹 Performing memory maintenance...")

        let now = Date()

        // Remove old low-importance memories
        conversationMemories.removeAll { memory in
            let age = now.timeIntervalSince(memory.createdAt) / 86400 // days
            return age > Double(memory.importance.retentionDays)
        }

        // Remove low-confidence preferences
        userPreferences.removeAll { $0.confidence < 0.2 }

        // Remove very old patterns that haven't been reinforced
        eventPatterns.removeAll { pattern in
            let age = now.timeIntervalSince(pattern.lastObserved) / 86400
            return age > 180 && pattern.frequency < 3
        }

        saveMemories()
        print("✅ Memory maintenance complete")
    }

    private func pruneOldMemories() {
        if conversationMemories.count > maxMemories {
            // Sort by importance and recency, keep top N
            conversationMemories.sort { mem1, mem2 in
                if mem1.importance != mem2.importance {
                    return mem1.importance.retentionDays > mem2.importance.retentionDays
                }
                return mem1.lastAccessedAt > mem2.lastAccessedAt
            }
            conversationMemories = Array(conversationMemories.prefix(maxMemories))
        }
    }

    private func prunePreferences() {
        if userPreferences.count > maxPreferences {
            userPreferences.sort { $0.confidence > $1.confidence }
            userPreferences = Array(userPreferences.prefix(maxPreferences))
        }
    }

    private func prunePatterns() {
        if eventPatterns.count > maxPatterns {
            eventPatterns.sort { $0.frequency > $1.frequency }
            eventPatterns = Array(eventPatterns.prefix(maxPatterns))
        }
    }

    // MARK: - Persistence

    private func loadMemories() {
        // Load conversation memories
        if let data = userDefaults.data(forKey: memoriesKey),
           let decoded = try? JSONDecoder().decode([ConversationMemory].self, from: data) {
            conversationMemories = decoded
        }

        // Load preferences
        if let data = userDefaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode([UserPreference].self, from: data) {
            userPreferences = decoded
        }

        // Load patterns
        if let data = userDefaults.data(forKey: patternsKey),
           let decoded = try? JSONDecoder().decode([EventPattern].self, from: data) {
            eventPatterns = decoded
        }

        print("📚 Loaded \(conversationMemories.count) memories, \(userPreferences.count) preferences, \(eventPatterns.count) patterns")
    }

    private func saveMemories() {
        // Save conversation memories
        if let encoded = try? JSONEncoder().encode(conversationMemories) {
            userDefaults.set(encoded, forKey: memoriesKey)
        }

        // Save preferences
        if let encoded = try? JSONEncoder().encode(userPreferences) {
            userDefaults.set(encoded, forKey: preferencesKey)
        }

        // Save patterns
        if let encoded = try? JSONEncoder().encode(eventPatterns) {
            userDefaults.set(encoded, forKey: patternsKey)
        }
    }

    // MARK: - Analytics

    func getMemoryStats() -> [String: Any] {
        return [
            "total_memories": conversationMemories.count,
            "total_preferences": userPreferences.count,
            "total_patterns": eventPatterns.count,
            "high_confidence_preferences": userPreferences.filter { $0.confidence > 0.7 }.count,
            "frequent_patterns": eventPatterns.filter { $0.frequency > 5 }.count
        ]
    }
}
