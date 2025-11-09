import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Enhanced conversational AI wrapper that adds multi-turn memory and context tracking
/// Prioritizes on-device Apple Intelligence (iOS 26+), falls back to cloud AI
class EnhancedConversationalAI {

    // MARK: - Types

    struct EnhancedConversationTurn: Codable {
        let id: UUID
        let timestamp: Date
        let userMessage: String
        let assistantResponse: String
        let intent: String?
        let entities: [String: String]

        init(id: UUID = UUID(), timestamp: Date = Date(), userMessage: String, assistantResponse: String, intent: String? = nil, entities: [String: String] = [:]) {
            self.id = id
            self.timestamp = timestamp
            self.userMessage = userMessage
            self.assistantResponse = assistantResponse
            self.intent = intent
            self.entities = entities
        }
    }

    struct EnhancedResponse {
        let message: String
        let intent: String
        let confidence: Float
        let requiresClarification: Bool
        let clarificationQuestions: [String]?
        let contextToRemember: [String: String]?
        let suggestedFollowUps: [String]?
    }

    // MARK: - Properties

    private var conversationHistory: [EnhancedConversationTurn] = []
    private let maxHistoryLength = 10
    private var currentContext: [String: String] = [:]

    // Context-aware follow-up tracking
    private var referencedEventIds: [String] = []  // Track events mentioned in conversation
    private var lastEventId: String?  // Most recently discussed event
    private var lastActionType: String?  // Last intent performed

    // On-device Apple Intelligence (iOS 26+)
    #if canImport(FoundationModels)
    private var onDeviceSession: Any?  // Store as Any to avoid availability issues
    #endif
    private var useOnDevice: Bool = false

    // Cloud AI fallback
    private var aiService: ConversationalAIService

    // Smart scheduling
    private let schedulingService = SmartSchedulingService()

    // MARK: - Initialization

    init(aiService: ConversationalAIService) {
        self.aiService = aiService

        // Try to initialize on-device Apple Intelligence
        if #available(iOS 26.0, *) {
            Task {
                await initializeOnDeviceAI()
            }
        } else {
            print("✅ Enhanced AI initialized with cloud fallback (iOS 26+ required for on-device)")
        }
    }

    @available(iOS 26.0, *)
    private func initializeOnDeviceAI() async {
        #if canImport(FoundationModels)
        do {
            let session = try await LanguageModelSession(
                instructions: """
                You are an intelligent calendar assistant with conversation memory.
                Remember context from previous messages in the conversation.
                Provide helpful, natural responses while maintaining JSON structure when needed.
                """
            )
            self.onDeviceSession = session
            self.useOnDevice = true
            print("✅ Enhanced AI initialized with Apple Intelligence (on-device)")
        } catch {
            print("⚠️ Failed to initialize Apple Intelligence: \(error)")
            print("✅ Falling back to cloud AI")
            self.useOnDevice = false
        }
        #else
        print("⚠️ FoundationModels not available - using cloud AI")
        self.useOnDevice = false
        #endif
    }

    // MARK: - Main Interface

    func processWithMemory(
        message: String,
        calendarEvents: [UnifiedEvent]
    ) async throws -> ConversationalAIService.AIAction {

        print("💬 Enhanced AI processing: \(message)")
        print("📚 Conversation history: \(conversationHistory.count) turns")

        // Build enhanced prompt with conversation context
        let enhancedMessage = buildEnhancedPrompt(message: message, events: calendarEvents)

        // Use on-device Apple Intelligence if available, otherwise cloud AI
        let action: ConversationalAIService.AIAction

        do {
            // Prioritize on-device AI with ultra-minimal context for speed
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), useOnDevice, let sessionObj = onDeviceSession {
                print("🍎 Using on-device Apple Intelligence (PRIMARY)")
                action = try await processWithOnDeviceAI(message: enhancedMessage, events: calendarEvents, session: sessionObj)
            } else {
                print("☁️ Using cloud AI fallback")
                action = try await aiService.processCommand(enhancedMessage, calendarEvents: calendarEvents)
            }
            #else
            print("☁️ Using cloud AI (FoundationModels not available)")
            action = try await aiService.processCommand(enhancedMessage, calendarEvents: calendarEvents)
            #endif
        } catch {
            print("❌ AI processing failed: \(error)")

            // Provide helpful error message based on error type
            let errorMessage: String
            let nsError = error as NSError

            if nsError.domain.contains("Network") || nsError.code == NSURLErrorNotConnectedToInternet {
                errorMessage = "Unable to connect to AI service. Please check your internet connection and try again."
            } else if nsError.domain == "OnDeviceAI" {
                errorMessage = "Apple Intelligence is not available. Please enable it in Settings > Apple Intelligence & Siri, or ensure you're on a supported device."
            } else if nsError.code == 401 || nsError.code == 403 {
                errorMessage = "AI service authentication failed. Please check your API configuration in Settings."
            } else if nsError.code == 429 {
                errorMessage = "AI service rate limit exceeded. Please wait a moment and try again."
            } else {
                errorMessage = "AI service is temporarily unavailable: \(error.localizedDescription)"
            }

            // Return a helpful error action instead of crashing
            return ConversationalAIService.AIAction(
                intent: "error",
                parameters: [:],
                message: errorMessage,
                needsClarification: false,
                clarificationQuestion: nil,
                shouldContinueListening: false,
                referencedEventIds: nil
            )
        }

        // Store conversation turn
        let turn = EnhancedConversationTurn(
            userMessage: message,
            assistantResponse: action.message,
            intent: action.intent,
            entities: extractEntities(from: action.parameters)
        )
        conversationHistory.append(turn)

        // Update context if needed
        updateContext(from: action)

        // Update referenced events tracking
        updateReferencedEvents(from: action)

        // Trim history if needed
        trimConversationHistory()

        print("✅ Enhanced AI completed: \(action.intent)")

        return action
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func processWithOnDeviceAI(
        message: String,
        events: [UnifiedEvent],
        session: Any
    ) async throws -> ConversationalAIService.AIAction {
        let languageSession = session as! LanguageModelSession

        // Use OnDeviceAIService's AIAction structure
        let result = try await languageSession.respond(to: message, generating: OnDeviceAIService.AIAction.self)
        let onDeviceAction = result.content

        // Convert to ConversationalAIService.AIAction
        var parameters: [String: ConversationalAIService.AnyCodableValue] = [:]

        if let startDate = onDeviceAction.startDate {
            parameters["startDate"] = .string(startDate)
        }
        if let endDate = onDeviceAction.endDate {
            parameters["endDate"] = .string(endDate)
        }
        if let title = onDeviceAction.title {
            parameters["title"] = .string(title)
        }
        if let location = onDeviceAction.location {
            parameters["location"] = .string(location)
        }

        return ConversationalAIService.AIAction(
            intent: onDeviceAction.intent,
            parameters: parameters,
            message: onDeviceAction.message,
            needsClarification: onDeviceAction.needsClarification,
            clarificationQuestion: onDeviceAction.clarificationQuestion,
            shouldContinueListening: onDeviceAction.shouldContinueListening,
            referencedEventIds: onDeviceAction.referencedEventIds
        )
    }
    #endif

    // MARK: - Context Building

    private func buildEnhancedPrompt(message: String, events: [UnifiedEvent]) -> String {
        // For on-device AI: Use ULTRA-MINIMAL context for simple queries
        let isSimpleQuery = message.lowercased().contains("schedule") ||
                           message.lowercased().contains("next") ||
                           message.lowercased().contains("today") ||
                           message.lowercased().contains("tomorrow")

        if isSimpleQuery {
            // Ultra-minimal context for simple schedule queries
            return buildMinimalScheduleContext(message: message, events: events)
        } else {
            // Standard minimal context for other queries
            return buildStandardContext(message: message, events: events)
        }
    }

    private func buildMinimalScheduleContext(message: String, events: [UnifiedEvent]) -> String {
        // ULTRA-MINIMAL: Just the question and relevant events (no history, no patterns)
        let now = Date()
        let calendar = Calendar.current

        // Determine timeframe from message
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: todayEnd)!

        let relevantEvents: [UnifiedEvent]
        if message.lowercased().contains("tomorrow") {
            relevantEvents = events.filter { $0.startDate >= todayEnd && $0.startDate < tomorrowEnd }
        } else if message.lowercased().contains("next") {
            relevantEvents = events.filter { $0.startDate > now }.prefix(5).map { $0 }
        } else {
            // Today
            relevantEvents = events.filter { $0.startDate >= todayStart && $0.startDate < todayEnd }
        }

        var lines: [String] = []
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        for event in relevantEvents.prefix(8) {  // Max 8 events
            lines.append("\(formatter.string(from: event.startDate)) \(event.title)")
        }

        if lines.isEmpty {
            lines.append("No events")
        }

        lines.append("")
        lines.append("Q: \(message)")

        let prompt = lines.joined(separator: "\n")
        print("📝 Ultra-minimal prompt: \(prompt.count) chars")
        return prompt
    }

    private func buildStandardContext(message: String, events: [UnifiedEvent]) -> String {
        var contextLines: [String] = []

        // Add only the most recent conversation turn (not all 3)
        if !conversationHistory.isEmpty {
            let lastTurn = conversationHistory.last!
            contextLines.append("Last: User '\(lastTurn.userMessage)' → '\(lastTurn.assistantResponse)'")
        }

        // Add referenced event context (shortened)
        if let eventId = lastEventId {
            if let event = events.first(where: { $0.id == eventId }) {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                contextLines.append("Last discussed: '\(event.title)' at \(formatter.string(from: event.startDate))")
            }
        }

        // Add only today's events (not all upcoming)
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let todaysEvents = events.filter {
            $0.startDate >= todayStart && $0.startDate < todayEnd
        }.sorted { $0.startDate < $1.startDate }

        if !todaysEvents.isEmpty {
            contextLines.append("Today:")
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            for event in todaysEvents.prefix(10) {  // Max 10 events
                contextLines.append("\(formatter.string(from: event.startDate)) \(event.title)")
            }
        }

        contextLines.append("")
        contextLines.append("Q: \(message)")

        let prompt = contextLines.joined(separator: "\n")
        print("📝 Standard prompt: \(prompt.count) chars")
        return prompt
    }

    private func extractEntities(from parameters: [String: ConversationalAIService.AnyCodableValue]) -> [String: String] {
        var entities: [String: String] = [:]

        for (key, value) in parameters {
            switch value {
            case .string(let str):
                entities[key] = str
            case .int(let int):
                entities[key] = "\(int)"
            case .double(let double):
                entities[key] = "\(double)"
            case .bool(let bool):
                entities[key] = "\(bool)"
            case .date(let date):
                entities[key] = ISO8601DateFormatter().string(from: date)
            default:
                break
            }
        }

        return entities
    }

    private func updateContext(from action: ConversationalAIService.AIAction) {
        // Extract important context from the action
        if let title = action.parameters["title"], case .string(let titleStr) = title {
            currentContext["lastMentionedEvent"] = titleStr
        }

        if let date = action.parameters["startDate"], case .string(let dateStr) = date {
            currentContext["lastMentionedDate"] = dateStr
        }

        // Store intent for context
        currentContext["lastIntent"] = action.intent
        lastActionType = action.intent
    }

    private func updateReferencedEvents(from action: ConversationalAIService.AIAction) {
        // Track referenced event IDs from the AI response
        if let eventIds = action.referencedEventIds, !eventIds.isEmpty {
            // Add new event IDs to tracking
            for eventId in eventIds {
                if !referencedEventIds.contains(eventId) {
                    referencedEventIds.append(eventId)
                }
            }

            // Update most recently referenced event
            if let mostRecent = eventIds.last {
                lastEventId = mostRecent
                print("📌 Tracking event reference: \(mostRecent)")
            }

            // Keep only last 5 referenced events to avoid clutter
            if referencedEventIds.count > 5 {
                referencedEventIds = Array(referencedEventIds.suffix(5))
            }
        }
    }

    // MARK: - History Management

    private func trimConversationHistory() {
        if conversationHistory.count > maxHistoryLength {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryLength))
            print("📚 Trimmed conversation history to \(maxHistoryLength) turns")
        }
    }

    func clearHistory() {
        conversationHistory.removeAll()
        currentContext.removeAll()
        referencedEventIds.removeAll()
        lastEventId = nil
        lastActionType = nil
        print("🗑️ Conversation history cleared")
    }

    func getConversationSummary() -> String {
        guard !conversationHistory.isEmpty else {
            return "No conversation history"
        }

        let recentIntents = conversationHistory
            .suffix(5)
            .compactMap { $0.intent }

        return """
        Conversation with \(conversationHistory.count) turns
        Recent topics: \(recentIntents.joined(separator: ", "))
        Active context: \(currentContext.keys.joined(separator: ", "))
        """
    }

    // MARK: - Context Helpers

    func addContext(key: String, value: String) {
        currentContext[key] = value
    }

    func removeContext(key: String) {
        currentContext.removeValue(forKey: key)
    }

    func getContext(key: String) -> String? {
        return currentContext[key]
    }

    // MARK: - Smart Scheduling Helpers

    /// Get smart scheduling suggestion for a proposed event
    func getSchedulingSuggestion(
        duration: TimeInterval,
        events: [UnifiedEvent],
        preferredDate: Date? = nil
    ) -> SmartSchedulingService.SchedulingSuggestion {
        return schedulingService.suggestOptimalTime(
            for: duration,
            events: events,
            preferredDate: preferredDate
        )
    }

    /// Check for scheduling conflicts and issues
    func checkSchedulingIssues(
        proposedTime: Date,
        duration: TimeInterval,
        events: [UnifiedEvent]
    ) -> [String] {
        return schedulingService.detectSchedulingIssues(
            proposedTime: proposedTime,
            duration: duration,
            events: events
        )
    }
}
import Foundation

/// Smart scheduling service that analyzes calendar patterns and suggests optimal meeting times
class SmartSchedulingService {

    // MARK: - Types

    struct SchedulingSuggestion {
        let suggestedTime: Date
        let confidence: Float  // 0.0 - 1.0
        let reasons: [String]  // Why this time is good
        let alternatives: [Date]  // Alternative times
        let warnings: [String]?  // Potential issues
    }

    struct CalendarPatterns {
        let preferredMeetingHours: [Int]  // Hours (0-23) with most meetings
        let averageGapBetweenMeetings: TimeInterval
        let typicalMeetingDuration: TimeInterval
        let busiestDays: [Int]  // Day of week (1=Sunday, 7=Saturday)
        let quietestDays: [Int]
        let hasLunchPattern: Bool
        let lunchHourRange: ClosedRange<Int>?
        let confidence: PatternConfidence  // How reliable are these patterns
        let eventCount: Int  // Number of events analyzed
    }

    enum PatternConfidence {
        case none       // 0-2 events: No patterns
        case low        // 3-9 events: Unreliable patterns
        case medium     // 10-29 events: Some patterns emerging
        case high       // 30+ events: Strong patterns

        var description: String {
            switch self {
            case .none: return "No pattern data yet"
            case .low: return "Limited pattern data"
            case .medium: return "Moderate pattern confidence"
            case .high: return "High pattern confidence"
            }
        }
    }

    // MARK: - Pattern Analysis

    /// Analyze user's calendar patterns to understand scheduling preferences
    func analyzeCalendarPatterns(events: [UnifiedEvent]) -> CalendarPatterns {
        let calendar = Calendar.current
        let now = Date()

        // Look at events from the past 30 days to understand patterns
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
        let recentEvents = events.filter { $0.startDate >= thirtyDaysAgo && $0.startDate <= now }

        let eventCount = recentEvents.count

        // Determine confidence level based on event count
        let confidence: PatternConfidence
        switch eventCount {
        case 0...2:
            confidence = .none
        case 3...9:
            confidence = .low
        case 10...29:
            confidence = .medium
        default:
            confidence = .high
        }

        // Use sensible defaults for sparse/empty calendars
        let defaultHours = [10, 14, 16]  // 10AM, 2PM, 4PM
        let defaultDuration: TimeInterval = 1800  // 30 minutes
        let defaultGap: TimeInterval = 900  // 15 minutes

        // Analyze preferred meeting hours (or use defaults)
        var hourCounts: [Int: Int] = [:]
        for event in recentEvents {
            let hour = calendar.component(.hour, from: event.startDate)
            hourCounts[hour, default: 0] += 1
        }
        let preferredHours: [Int]
        if eventCount >= 3 {
            preferredHours = hourCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        } else {
            preferredHours = defaultHours
        }

        // Calculate average gap between meetings (or use default)
        let sortedEvents = recentEvents.sorted { $0.startDate < $1.startDate }
        var gaps: [TimeInterval] = []
        if sortedEvents.count > 1 {
            for i in 0..<(sortedEvents.count - 1) {
                let gap = sortedEvents[i + 1].startDate.timeIntervalSince(sortedEvents[i].endDate)
                if gap > 0 && gap < 3600 * 4 {  // Only count gaps under 4 hours
                    gaps.append(gap)
                }
            }
        }
        let avgGap = gaps.isEmpty ? defaultGap : gaps.reduce(0, +) / Double(gaps.count)

        // Calculate typical meeting duration (or use default)
        let durations = recentEvents.map { $0.endDate.timeIntervalSince($0.startDate) }
        let avgDuration = durations.isEmpty ? defaultDuration : durations.reduce(0, +) / Double(durations.count)

        // Analyze busiest/quietest days (or use defaults)
        var dayCounts: [Int: Int] = [:]
        for event in recentEvents {
            let weekday = calendar.component(.weekday, from: event.startDate)
            dayCounts[weekday, default: 0] += 1
        }
        let busiestDays: [Int]
        let quietestDays: [Int]
        if eventCount >= 5 {
            busiestDays = dayCounts.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
            quietestDays = dayCounts.sorted { $0.value < $1.value }.prefix(2).map { $0.key }
        } else {
            // Default: Tuesday/Thursday busiest, Monday/Friday quietest
            busiestDays = [3, 5]
            quietestDays = [2, 6]
        }

        // Detect lunch pattern (12pm-2pm) - only if enough data
        let hasLunchPattern: Bool
        let lunchRange: ClosedRange<Int>?
        if eventCount >= 10 {
            let lunchEvents = recentEvents.filter {
                let hour = calendar.component(.hour, from: $0.startDate)
                return hour >= 11 && hour <= 14
            }
            hasLunchPattern = lunchEvents.count > recentEvents.count / 4
            lunchRange = hasLunchPattern ? 12...13 : nil
        } else {
            hasLunchPattern = false
            lunchRange = nil
        }

        print("📊 Pattern Analysis: \(eventCount) events, confidence: \(confidence.description)")

        return CalendarPatterns(
            preferredMeetingHours: preferredHours,
            averageGapBetweenMeetings: avgGap,
            typicalMeetingDuration: avgDuration,
            busiestDays: busiestDays,
            quietestDays: quietestDays,
            hasLunchPattern: hasLunchPattern,
            lunchHourRange: lunchRange,
            confidence: confidence,
            eventCount: eventCount
        )
    }

    // MARK: - Time Suggestions

    /// Suggest optimal time for a new meeting based on patterns and constraints
    func suggestOptimalTime(
        for duration: TimeInterval,
        events: [UnifiedEvent],
        preferredDate: Date? = nil,
        participantTimeZones: [TimeZone]? = nil
    ) -> SchedulingSuggestion {

        let calendar = Calendar.current
        let patterns = analyzeCalendarPatterns(events: events)
        let searchDate = preferredDate ?? Date()

        // Find available slots in the next 7 days
        var bestTime: Date?
        var bestScore: Float = 0
        var reasons: [String] = []
        var alternatives: [Date] = []
        var warnings: [String] = []

        // Search through next 7 days
        for dayOffset in 0..<7 {
            guard let searchDay = calendar.date(byAdding: .day, value: dayOffset, to: searchDate) else { continue }

            // Try each hour from 8am to 6pm
            for hour in 8...18 {
                guard let candidateTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: searchDay) else { continue }

                // Check if time is available
                let candidateEnd = candidateTime.addingTimeInterval(duration)
                let hasConflict = events.contains { event in
                    event.startDate < candidateEnd && event.endDate > candidateTime
                }

                if hasConflict { continue }

                // Score this time slot
                var score: Float = 0.0
                var timeReasons: [String] = []

                // Preferred hours bonus
                if patterns.preferredMeetingHours.contains(hour) {
                    score += 0.3
                    timeReasons.append("Matches your typical meeting time")
                }

                // Avoid lunch hours
                if let lunchRange = patterns.lunchHourRange, lunchRange.contains(hour) {
                    score -= 0.2
                    warnings.append("During typical lunch hours")
                } else {
                    score += 0.1
                }

                // Check buffer time before/after
                let bufferBefore = events.first { $0.endDate <= candidateTime && candidateTime.timeIntervalSince($0.endDate) < 1800 }
                let bufferAfter = events.first { $0.startDate >= candidateEnd && $0.startDate.timeIntervalSince(candidateEnd) < 1800 }

                if bufferBefore == nil && bufferAfter == nil {
                    score += 0.2
                    timeReasons.append("Good buffer time before/after")
                } else if bufferBefore != nil || bufferAfter != nil {
                    score -= 0.1
                    warnings.append("Back-to-back with other meetings")
                }

                // Prefer quieter days
                let weekday = calendar.component(.weekday, from: candidateTime)
                if patterns.quietestDays.contains(weekday) {
                    score += 0.15
                    timeReasons.append("On a typically lighter day")
                } else if patterns.busiestDays.contains(weekday) {
                    score -= 0.1
                }

                // Morning vs afternoon preference
                if hour < 12 {
                    score += 0.1
                    timeReasons.append("Morning time slot")
                }

                // Time zone consideration
                if let timezones = participantTimeZones, !timezones.isEmpty {
                    let allReasonable = timezones.allSatisfy { tz in
                        let offset = tz.secondsFromGMT() - TimeZone.current.secondsFromGMT()
                        let theirHour = hour + offset / 3600
                        return theirHour >= 8 && theirHour <= 18
                    }
                    if allReasonable {
                        score += 0.2
                        timeReasons.append("Works for all time zones")
                    } else {
                        score -= 0.3
                        warnings.append("May be outside business hours for some participants")
                    }
                }

                // Sooner is better (slight preference)
                score += Float(7 - dayOffset) * 0.02

                // Track best time
                if score > bestScore {
                    if bestTime != nil {
                        alternatives.insert(bestTime!, at: 0)
                    }
                    bestScore = score
                    bestTime = candidateTime
                    reasons = timeReasons
                }

                // Track alternatives
                if score > 0.5 && alternatives.count < 3 && candidateTime != bestTime {
                    alternatives.append(candidateTime)
                }
            }
        }

        // Default to tomorrow at 10am if no good time found
        let finalTime = bestTime ?? calendar.date(byAdding: .day, value: 1, to: searchDate)!

        return SchedulingSuggestion(
            suggestedTime: finalTime,
            confidence: max(0.3, bestScore),
            reasons: reasons.isEmpty ? ["Available time slot"] : reasons,
            alternatives: Array(alternatives.prefix(3)),
            warnings: warnings.isEmpty ? nil : warnings
        )
    }

    // MARK: - Conflict Detection

    /// Check for potential scheduling conflicts and provide warnings
    func detectSchedulingIssues(
        proposedTime: Date,
        duration: TimeInterval,
        events: [UnifiedEvent]
    ) -> [String] {
        var issues: [String] = []
        let calendar = Calendar.current
        let proposedEnd = proposedTime.addingTimeInterval(duration)

        // Check for direct conflicts
        let conflicts = events.filter { event in
            event.startDate < proposedEnd && event.endDate > proposedTime
        }
        if !conflicts.isEmpty {
            issues.append("Conflicts with \(conflicts.count) existing event(s)")
        }

        // Check for back-to-back meetings
        let backToBack = events.filter { event in
            abs(event.endDate.timeIntervalSince(proposedTime)) < 60 ||
            abs(proposedEnd.timeIntervalSince(event.startDate)) < 60
        }
        if !backToBack.isEmpty {
            issues.append("Back-to-back with other meetings - no break time")
        }

        // Check for too many meetings in one day
        let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: proposedTime) }
        if dayEvents.count >= 6 {
            issues.append("This would be meeting #\(dayEvents.count + 1) on this day")
        }

        // Check if outside business hours
        let hour = calendar.component(.hour, from: proposedTime)
        if hour < 8 || hour >= 18 {
            issues.append("Outside typical business hours (8am-6pm)")
        }

        // Check if on weekend
        let weekday = calendar.component(.weekday, from: proposedTime)
        if weekday == 1 || weekday == 7 {
            issues.append("Scheduled on weekend")
        }

        return issues
    }

    // MARK: - Helper Methods

    /// Format scheduling suggestion as natural language
    func formatSuggestion(_ suggestion: SchedulingSuggestion) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var message = "I suggest \(formatter.string(from: suggestion.suggestedTime))"

        if !suggestion.reasons.isEmpty {
            message += " because:\n"
            for reason in suggestion.reasons {
                message += "• \(reason)\n"
            }
        }

        if let warnings = suggestion.warnings, !warnings.isEmpty {
            message += "\nNote: \(warnings.joined(separator: ", "))"
        }

        if !suggestion.alternatives.isEmpty {
            message += "\n\nAlternatives: "
            let altTimes = suggestion.alternatives.map { formatter.string(from: $0) }
            message += altTimes.joined(separator: ", ")
        }

        return message
    }
}
