import Foundation

/// Provides analytics and insights about calendar usage
class CalendarAnalyticsService {
    private let calendar = Calendar.current

    // MARK: - Time Distribution

    func analyzeTimeDistribution(events: [UnifiedEvent], period: AnalysisPeriod = .month) -> TimeDistribution {
        let startDate = period.startDate(from: Date())
        let relevantEvents = events.filter { $0.startDate >= startDate }

        var categoryMinutes: [EventCategory: Int] = [:]
        var sourceMinutes: [CalendarSource: Int] = [:]
        var hourDistribution: [Int: Int] = [:] // Hour -> minutes

        for event in relevantEvents {
            let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
            let category = categorizeEvent(event)
            let hour = calendar.component(.hour, from: event.startDate)

            categoryMinutes[category, default: 0] += duration
            sourceMinutes[event.source, default: 0] += duration
            hourDistribution[hour, default: 0] += duration
        }

        return TimeDistribution(
            totalMinutes: categoryMinutes.values.reduce(0, +),
            byCategory: categoryMinutes,
            bySource: sourceMinutes,
            byHour: hourDistribution
        )
    }

    // MARK: - Productivity Insights

    func generateProductivityInsights(events: [UnifiedEvent]) -> ProductivityInsights {
        let last7Days = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentEvents = events.filter { $0.startDate >= last7Days }

        // Calculate meeting load
        let meetings = recentEvents.filter { categorizeEvent($0) == .meeting }
        let totalMeetingMinutes = meetings.reduce(0) {
            $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60)
        }
        let avgMeetingsPerDay = Double(meetings.count) / 7.0

        // Find focus time blocks (gaps >= 2 hours)
        let focusBlocks = findFocusTimeBlocks(in: recentEvents)

        // Calculate work-life balance
        let workEvents = recentEvents.filter { categorizeEvent($0) == .work || categorizeEvent($0) == .meeting }
        let personalEvents = recentEvents.filter { categorizeEvent($0) == .personal }

        let workMinutes = workEvents.reduce(0) { $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60) }
        let personalMinutes = personalEvents.reduce(0) { $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60) }

        // Peak productivity hours
        let peakHours = findPeakProductivityHours(events: recentEvents)

        return ProductivityInsights(
            averageMeetingsPerDay: avgMeetingsPerDay,
            totalMeetingMinutes: totalMeetingMinutes,
            focusTimeBlocks: focusBlocks.count,
            totalFocusMinutes: focusBlocks.reduce(0) { $0 + $1.duration },
            workLifeBalance: WorkLifeBalance(
                workMinutes: workMinutes,
                personalMinutes: personalMinutes,
                ratio: personalMinutes > 0 ? Double(workMinutes) / Double(personalMinutes) : 0
            ),
            peakProductivityHours: peakHours,
            recommendations: generateRecommendations(
                meetingsPerDay: avgMeetingsPerDay,
                focusBlocks: focusBlocks.count,
                workLifeRatio: workMinutes > 0 ? Double(personalMinutes) / Double(workMinutes) : 0
            )
        )
    }

    // MARK: - Event Patterns

    func findRecurringPatterns(events: [UnifiedEvent]) -> [RecurringPattern] {
        var patterns: [RecurringPattern] = []

        // Group by title
        let grouped = Dictionary(grouping: events) { $0.title ?? "Untitled" }

        for (title, eventGroup) in grouped where eventGroup.count >= 3 {
            let sortedEvents = eventGroup.sorted { $0.startDate < $1.startDate }

            // Check for weekly pattern
            if let weeklyPattern = detectWeeklyPattern(in: sortedEvents) {
                patterns.append(weeklyPattern)
            }

            // Check for daily pattern
            if let dailyPattern = detectDailyPattern(in: sortedEvents) {
                patterns.append(dailyPattern)
            }
        }

        return patterns
    }

    // MARK: - Helper Methods

    private func categorizeEvent(_ event: UnifiedEvent) -> EventCategory {
        let title = event.title?.lowercased() ?? ""

        if title.contains("meeting") || title.contains("call") || title.contains("sync") {
            return .meeting
        } else if title.contains("lunch") || title.contains("dinner") || title.contains("breakfast") {
            return .meal
        } else if title.contains("workout") || title.contains("gym") || title.contains("exercise") {
            return .exercise
        } else if title.contains("work") || title.contains("project") || title.contains("task") {
            return .work
        } else {
            return .personal
        }
    }

    private func findFocusTimeBlocks(in events: [UnifiedEvent]) -> [FocusBlock] {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        var blocks: [FocusBlock] = []

        for i in 0..<sorted.count - 1 {
            let gap = sorted[i + 1].startDate.timeIntervalSince(sorted[i].endDate)
            if gap >= 7200 { // 2 hours minimum
                blocks.append(FocusBlock(
                    start: sorted[i].endDate,
                    end: sorted[i + 1].startDate,
                    duration: Int(gap / 60)
                ))
            }
        }

        return blocks
    }

    private func findPeakProductivityHours(events: [UnifiedEvent]) -> [Int] {
        var hourActivity: [Int: Int] = [:]

        for event in events {
            let hour = calendar.component(.hour, from: event.startDate)
            hourActivity[hour, default: 0] += 1
        }

        let sortedHours = hourActivity.sorted { $0.value > $1.value }
        return Array(sortedHours.prefix(3).map { $0.key })
    }

    private func detectWeeklyPattern(in events: [UnifiedEvent]) -> RecurringPattern? {
        guard events.count >= 3 else { return nil }

        let weekdays = events.map { calendar.component(.weekday, from: $0.startDate) }
        let mostCommonWeekday = Dictionary(grouping: weekdays) { $0 }
            .max { $0.value.count < $1.value.count }?.key

        guard let weekday = mostCommonWeekday else { return nil }

        return RecurringPattern(
            title: events.first?.title ?? "",
            frequency: .weekly,
            dayOfWeek: weekday,
            timeOfDay: calendar.component(.hour, from: events.first!.startDate),
            occurrences: events.count
        )
    }

    private func detectDailyPattern(in events: [UnifiedEvent]) -> RecurringPattern? {
        guard events.count >= 5 else { return nil }

        // Check if events occur roughly at the same time each day
        let hours = events.map { calendar.component(.hour, from: $0.startDate) }
        let avgHour = hours.reduce(0, +) / hours.count
        let variance = hours.map { abs($0 - avgHour) }.reduce(0, +) / hours.count

        if variance <= 1 { // Within 1 hour variance
            return RecurringPattern(
                title: events.first?.title ?? "",
                frequency: .daily,
                dayOfWeek: nil,
                timeOfDay: avgHour,
                occurrences: events.count
            )
        }

        return nil
    }

    private func generateRecommendations(
        meetingsPerDay: Double,
        focusBlocks: Int,
        workLifeRatio: Double
    ) -> [String] {
        var recommendations: [String] = []

        if meetingsPerDay > 4 {
            recommendations.append("You have \(Int(meetingsPerDay)) meetings per day on average. Consider blocking focus time.")
        }

        if focusBlocks < 3 {
            recommendations.append("Only \(focusBlocks) focus blocks found this week. Try scheduling 2-hour deep work sessions.")
        }

        if workLifeRatio < 0.3 {
            recommendations.append("Work-life balance could be improved. Consider scheduling more personal time.")
        } else if workLifeRatio > 1.5 {
            recommendations.append("Great work-life balance! You're prioritizing personal time well.")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

enum AnalysisPeriod {
    case week
    case month
    case quarter

    func startDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: date)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: date)!
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: date)!
        }
    }
}

enum EventCategory: String, CaseIterable {
    case meeting
    case work
    case personal
    case meal
    case exercise
}

struct TimeDistribution {
    let totalMinutes: Int
    let byCategory: [EventCategory: Int]
    let bySource: [CalendarSource: Int]
    let byHour: [Int: Int]

    var totalHours: Double {
        Double(totalMinutes) / 60.0
    }
}

struct ProductivityInsights {
    let averageMeetingsPerDay: Double
    let totalMeetingMinutes: Int
    let focusTimeBlocks: Int
    let totalFocusMinutes: Int
    let workLifeBalance: WorkLifeBalance
    let peakProductivityHours: [Int]
    let recommendations: [String]
}

struct WorkLifeBalance {
    let workMinutes: Int
    let personalMinutes: Int
    let ratio: Double

    var workHours: Double { Double(workMinutes) / 60.0 }
    var personalHours: Double { Double(personalMinutes) / 60.0 }
}

struct FocusBlock {
    let start: Date
    let end: Date
    let duration: Int // minutes
}

struct RecurringPattern {
    let title: String
    let frequency: Frequency
    let dayOfWeek: Int? // 1 = Sunday, 7 = Saturday
    let timeOfDay: Int // Hour (0-23)
    let occurrences: Int

    enum Frequency: String {
        case daily
        case weekly
        case monthly
    }
}
