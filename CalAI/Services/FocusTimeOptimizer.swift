import Foundation
import EventKit

// MARK: - Focus Time Models

struct FocusBlock: Identifiable, Codable {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date
    let focusType: FocusType
    let isProtected: Bool // Can't be interrupted
    let autoScheduled: Bool

    init(id: UUID = UUID(), title: String, startTime: Date, endTime: Date, focusType: FocusType, isProtected: Bool = true, autoScheduled: Bool = false) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.focusType = focusType
        self.isProtected = isProtected
        self.autoScheduled = autoScheduled
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

enum FocusType: String, Codable, CaseIterable {
    case deepWork = "Deep Work"
    case learning = "Learning"
    case creative = "Creative Work"
    case admin = "Admin Tasks"
    case planning = "Planning"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .learning: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .admin: return "folder.fill"
        case .planning: return "calendar.badge.clock"
        case .custom: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .deepWork: return "purple"
        case .learning: return "blue"
        case .creative: return "orange"
        case .admin: return "gray"
        case .planning: return "green"
        case .custom: return "pink"
        }
    }

    var recommendedDuration: TimeInterval {
        switch self {
        case .deepWork: return 7200 // 2 hours
        case .learning: return 5400 // 1.5 hours
        case .creative: return 5400 // 1.5 hours
        case .admin: return 3600 // 1 hour
        case .planning: return 3600 // 1 hour
        case .custom: return 3600 // 1 hour
        }
    }
}

struct MeetingPattern {
    let dayOfWeek: Int // 1 = Sunday, 7 = Saturday
    let hour: Int
    let meetingCount: Int
    let averageDuration: TimeInterval
}

struct FocusTimeWindow {
    let startTime: Date
    let endTime: Date
    let score: Double // 0-1, higher is better
    let reason: String

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct FocusTimePreferences: Codable {
    var isEnabled: Bool = true
    var autoScheduleFocusBlocks: Bool = false
    var protectFocusTime: Bool = true
    var enableDoNotDisturb: Bool = true

    // Scheduling preferences
    var preferredFocusHoursStart: Int = 9 // 9 AM
    var preferredFocusHoursEnd: Int = 17 // 5 PM
    var minimumFocusBlockDuration: TimeInterval = 3600 // 1 hour
    var maximumFocusBlockDuration: TimeInterval = 10800 // 3 hours
    var focusBlocksPerWeek: Int = 5

    // Focus time types
    var preferredFocusTypes: [FocusType] = [.deepWork, .learning]

    // Do Not Disturb
    var dndDuringFocusBlocks: Bool = true
    var dndAllowCalls: Bool = false
    var dndBreakthrough: [String] = [] // Contact IDs that can breakthrough

    static let userDefaultsKey = "FocusTimePreferences"

    static func load() -> FocusTimePreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let prefs = try? JSONDecoder().decode(FocusTimePreferences.self, from: data) else {
            return FocusTimePreferences()
        }
        return prefs
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

struct FocusTimeAnalytics {
    let totalFocusTimeThisWeek: TimeInterval
    let totalFocusTimeLastWeek: TimeInterval
    let averageFocusBlockDuration: TimeInterval
    let focusBlocksCompleted: Int
    let focusBlocksInterrupted: Int
    let mostProductiveHours: [Int] // Hours of day
    let leastProductiveHours: [Int]
    let meetingFreeHours: [Int] // Best hours for focus

    var weekOverWeekChange: Double {
        guard totalFocusTimeLastWeek > 0 else { return 0 }
        return (totalFocusTimeThisWeek - totalFocusTimeLastWeek) / totalFocusTimeLastWeek
    }

    var completionRate: Double {
        let total = focusBlocksCompleted + focusBlocksInterrupted
        guard total > 0 else { return 0 }
        return Double(focusBlocksCompleted) / Double(total)
    }
}

// MARK: - Focus Time Optimizer

class FocusTimeOptimizer: ObservableObject {
    static let shared = FocusTimeOptimizer()

    @Published var preferences = FocusTimePreferences.load()
    @Published var scheduledFocusBlocks: [FocusBlock] = []

    private let calendar = Calendar.current

    private init() {
        loadScheduledFocusBlocks()
    }

    // MARK: - Meeting Pattern Analysis

    /// Analyze meeting patterns to find optimal focus time windows
    func analyzeMeetingPatterns(events: [UnifiedEvent]) -> [MeetingPattern] {
        var patterns: [Int: [Int: [UnifiedEvent]]] = [:] // [dayOfWeek: [hour: [events]]]

        // Only analyze meetings (not all-day events, not focus blocks)
        let meetings = events.filter { event in
            !event.isAllDay &&
            event.startDate > Date().addingTimeInterval(-30 * 24 * 3600) && // Last 30 days
            !event.title.lowercased().contains("focus")
        }

        // Group by day of week and hour
        for event in meetings {
            let dayOfWeek = calendar.component(.weekday, from: event.startDate)
            let hour = calendar.component(.hour, from: event.startDate)

            if patterns[dayOfWeek] == nil {
                patterns[dayOfWeek] = [:]
            }
            if patterns[dayOfWeek]?[hour] == nil {
                patterns[dayOfWeek]?[hour] = []
            }
            patterns[dayOfWeek]?[hour]?.append(event)
        }

        // Convert to MeetingPattern objects
        var meetingPatterns: [MeetingPattern] = []
        for (dayOfWeek, hourData) in patterns {
            for (hour, events) in hourData {
                let avgDuration = events.map { $0.endDate.timeIntervalSince($0.startDate) }.reduce(0, +) / Double(events.count)

                meetingPatterns.append(MeetingPattern(
                    dayOfWeek: dayOfWeek,
                    hour: hour,
                    meetingCount: events.count,
                    averageDuration: avgDuration
                ))
            }
        }

        return meetingPatterns.sorted { $0.meetingCount > $1.meetingCount }
    }

    /// Find optimal focus time windows based on calendar and patterns
    func findOptimalFocusWindows(
        events: [UnifiedEvent],
        targetDate: Date,
        preferredDuration: TimeInterval
    ) -> [FocusTimeWindow] {
        var windows: [FocusTimeWindow] = []

        let dayStart = calendar.startOfDay(for: targetDate)
        let workDayStart = calendar.date(byAdding: .hour, value: preferences.preferredFocusHoursStart, to: dayStart)!
        let workDayEnd = calendar.date(byAdding: .hour, value: preferences.preferredFocusHoursEnd, to: dayStart)!

        // Get events for this day
        let dayEvents = events.filter { event in
            !event.isAllDay &&
            calendar.isDate(event.startDate, inSameDayAs: targetDate)
        }.sorted { $0.startDate < $1.startDate }

        // Find gaps between meetings
        var currentTime = workDayStart

        for event in dayEvents {
            // Check if there's a gap before this event
            let gapDuration = event.startDate.timeIntervalSince(currentTime)

            if gapDuration >= preferences.minimumFocusBlockDuration {
                let score = calculateFocusWindowScore(
                    startTime: currentTime,
                    endTime: event.startDate,
                    events: events
                )

                windows.append(FocusTimeWindow(
                    startTime: currentTime,
                    endTime: event.startDate,
                    score: score,
                    reason: generateFocusWindowReason(score: score, duration: gapDuration)
                ))
            }

            currentTime = max(currentTime, event.endDate)
        }

        // Check if there's time at the end of the day
        if currentTime < workDayEnd {
            let gapDuration = workDayEnd.timeIntervalSince(currentTime)
            if gapDuration >= preferences.minimumFocusBlockDuration {
                let score = calculateFocusWindowScore(
                    startTime: currentTime,
                    endTime: workDayEnd,
                    events: events
                )

                windows.append(FocusTimeWindow(
                    startTime: currentTime,
                    endTime: workDayEnd,
                    score: score,
                    reason: generateFocusWindowReason(score: score, duration: gapDuration)
                ))
            }
        }

        return windows.sorted { $0.score > $1.score }
    }

    private func calculateFocusWindowScore(startTime: Date, endTime: Date, events: [UnifiedEvent]) -> Double {
        var score = 1.0

        let duration = endTime.timeIntervalSince(startTime)
        let hour = calendar.component(.hour, from: startTime)

        // Prefer morning hours (9-12) - research shows better focus
        if hour >= 9 && hour < 12 {
            score += 0.3
        } else if hour >= 14 && hour < 16 {
            score += 0.1 // Post-lunch is okay but not ideal
        } else if hour >= 16 {
            score -= 0.2 // Late afternoon is harder for focus
        }

        // Prefer longer blocks
        if duration >= 7200 { // 2 hours
            score += 0.3
        } else if duration >= 5400 { // 1.5 hours
            score += 0.2
        } else if duration >= 3600 { // 1 hour
            score += 0.1
        }

        // Penalize if close to many meetings (context switching is bad)
        let nearbyMeetings = events.filter { event in
            abs(event.startDate.timeIntervalSince(startTime)) < 1800 || // 30 min before
            abs(event.endDate.timeIntervalSince(endTime)) < 1800 // 30 min after
        }
        score -= Double(nearbyMeetings.count) * 0.15

        return max(0, min(1, score))
    }

    private func generateFocusWindowReason(score: Double, duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        let durationStr = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"

        if score > 0.8 {
            return "Excellent \(durationStr) window - morning slot with no nearby meetings"
        } else if score > 0.6 {
            return "Good \(durationStr) window - sufficient time for deep work"
        } else if score > 0.4 {
            return "Fair \(durationStr) window - some context switching possible"
        } else {
            return "\(durationStr) available - not ideal but workable"
        }
    }

    // MARK: - Auto-Schedule Focus Blocks

    /// Automatically schedule focus blocks for the week
    func autoScheduleFocusBlocks(events: [UnifiedEvent], completion: @escaping ([FocusBlock]) -> Void) {
        guard preferences.autoScheduleFocusBlocks else {
            completion([])
            return
        }

        var scheduledBlocks: [FocusBlock] = []
        let today = Date()

        // Schedule for next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            // Find best window for this day
            let windows = findOptimalFocusWindows(
                events: events,
                targetDate: targetDate,
                preferredDuration: preferences.minimumFocusBlockDuration
            )

            // Take the best window if score is good enough
            if let bestWindow = windows.first, bestWindow.score > 0.5 {
                let focusType = preferences.preferredFocusTypes.first ?? .deepWork
                let duration = min(bestWindow.duration, focusType.recommendedDuration)

                let block = FocusBlock(
                    title: "Focus Time - \(focusType.rawValue)",
                    startTime: bestWindow.startTime,
                    endTime: bestWindow.startTime.addingTimeInterval(duration),
                    focusType: focusType,
                    isProtected: true,
                    autoScheduled: true
                )

                scheduledBlocks.append(block)
            }
        }

        // Limit to preferences.focusBlocksPerWeek
        let limitedBlocks = Array(scheduledBlocks.prefix(preferences.focusBlocksPerWeek))
        self.scheduledFocusBlocks.append(contentsOf: limitedBlocks)
        saveFocusBlocks()

        completion(limitedBlocks)
    }

    /// Manually schedule a focus block
    func scheduleFocusBlock(_ block: FocusBlock) {
        scheduledFocusBlocks.append(block)
        saveFocusBlocks()

        if preferences.dndDuringFocusBlocks {
            scheduleDoNotDisturb(for: block)
        }
    }

    /// Remove a focus block
    func removeFocusBlock(_ blockId: UUID) {
        scheduledFocusBlocks.removeAll { $0.id == blockId }
        saveFocusBlocks()
    }

    // MARK: - Do Not Disturb Automation

    private func scheduleDoNotDisturb(for block: FocusBlock) {
        // Note: iOS doesn't provide programmatic DND control
        // This would integrate with Focus Modes in iOS 15+ via Shortcuts
        // or provide reminders to the user
        print("📵 DND scheduled for \(block.title) from \(block.startTime) to \(block.endTime)")

        // In a real implementation, you might:
        // 1. Use Shortcuts app integration
        // 2. Send local notification reminders
        // 3. Use Screen Time API (if available)
    }

    // MARK: - Analytics

    func generateAnalytics(events: [UnifiedEvent]) -> FocusTimeAnalytics {
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        // Focus blocks this week
        let thisWeekBlocks = scheduledFocusBlocks.filter { block in
            block.startTime >= oneWeekAgo && block.startTime < now
        }

        // Focus blocks last week
        let lastWeekBlocks = scheduledFocusBlocks.filter { block in
            block.startTime >= twoWeeksAgo && block.startTime < oneWeekAgo
        }

        let totalThisWeek = thisWeekBlocks.reduce(0) { $0 + $1.duration }
        let totalLastWeek = lastWeekBlocks.reduce(0) { $0 + $1.duration }

        let avgDuration = thisWeekBlocks.isEmpty ? 0 : totalThisWeek / Double(thisWeekBlocks.count)

        // Analyze meeting patterns
        let patterns = analyzeMeetingPatterns(events: events)
        let busyHours = Set(patterns.filter { $0.meetingCount > 2 }.map { $0.hour })
        let freeHours = Set(9...17).subtracting(busyHours)

        return FocusTimeAnalytics(
            totalFocusTimeThisWeek: totalThisWeek,
            totalFocusTimeLastWeek: totalLastWeek,
            averageFocusBlockDuration: avgDuration,
            focusBlocksCompleted: thisWeekBlocks.count,
            focusBlocksInterrupted: 0, // Would track actual interruptions
            mostProductiveHours: [9, 10, 11], // Morning hours
            leastProductiveHours: [16, 17], // Late afternoon
            meetingFreeHours: Array(freeHours).sorted()
        )
    }

    // MARK: - Persistence

    private func loadScheduledFocusBlocks() {
        guard let data = UserDefaults.standard.data(forKey: "ScheduledFocusBlocks"),
              let blocks = try? JSONDecoder().decode([FocusBlock].self, from: data) else {
            return
        }

        // Only load future blocks
        scheduledFocusBlocks = blocks.filter { $0.endTime > Date() }
    }

    private func saveFocusBlocks() {
        if let data = try? JSONEncoder().encode(scheduledFocusBlocks) {
            UserDefaults.standard.set(data, forKey: "ScheduledFocusBlocks")
        }
    }

    func updatePreferences(_ newPreferences: FocusTimePreferences) {
        preferences = newPreferences
        preferences.save()
        print("✅ Focus time preferences updated")
    }
}
