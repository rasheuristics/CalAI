import Foundation
import SwiftUI
import Combine

@MainActor
class InsightsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var healthScore: Double = 0
    @Published var eventsToday = 0
    @Published var scheduledHours: Double = 0
    @Published var totalTravelTime: Double = 0
    @Published var freeTimeBlocks = 0

    @Published var conflicts: [InsightsScheduleConflict] = []
    @Published var duplicates: [InsightsDuplicateEvent] = []
    @Published var logisticsIssues: [InsightsLogisticsIssue] = []
    @Published var patterns: [InsightsSchedulePattern] = []
    @Published var recommendations: [InsightsAIRecommendation] = []

    // Health score components
    @Published var timeUtilizationScore: Double = 0
    @Published var conflictScore: Double = 0
    @Published var balanceScore: Double = 0
    @Published var bufferScore: Double = 0

    // MARK: - Private Properties
    private var calendarManager: CalendarManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration
    func configure(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager

        // Subscribe to calendar changes
        calendarManager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.analyzeSchedule()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Main Analysis
    func analyzeSchedule() {
        guard let calendarManager = calendarManager else { return }

        isLoading = true

        Task {
            // Get events for today
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let todayEvents = calendarManager.unifiedEvents.filter { event in
                event.startDate >= startOfDay && event.startDate < endOfDay
            }

            // Get events for next 7 days (for conflicts and duplicates)
            let sevenDaysOut = Calendar.current.date(byAdding: .day, value: 7, to: startOfDay)!
            let next7DaysEvents = calendarManager.unifiedEvents.filter { event in
                event.startDate >= startOfDay && event.startDate < sevenDaysOut
            }

            // Calculate basic metrics (still today only for health score)
            eventsToday = todayEvents.count
            scheduledHours = calculateScheduledHours(todayEvents)
            totalTravelTime = calculateTravelTime(todayEvents)
            freeTimeBlocks = calculateFreeTimeBlocks(todayEvents)

            // Detect conflicts (next 7 days)
            conflicts = detectConflicts(next7DaysEvents)

            // Detect duplicates (next 7 days)
            duplicates = detectDuplicates(next7DaysEvents)

            // Analyze logistics (today only)
            logisticsIssues = analyzeLogistics(todayEvents)

            // Detect patterns (use last 7 days)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            let weekEvents = calendarManager.unifiedEvents.filter { event in
                event.startDate >= weekAgo && event.startDate < endOfDay
            }
            patterns = detectPatterns(weekEvents)

            // Generate recommendations
            await generateRecommendations(todayEvents)

            // Calculate health scores
            calculateHealthScores()

            isLoading = false
        }
    }

    func refreshAnalysis() async {
        analyzeSchedule()
        // Add a small delay to show refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Conflict Detection
    private func detectConflicts(_ events: [UnifiedEvent]) -> [InsightsScheduleConflict] {
        var conflicts: [InsightsScheduleConflict] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        for i in 0..<sortedEvents.count {
            for j in (i + 1)..<sortedEvents.count {
                let event1 = sortedEvents[i]
                let event2 = sortedEvents[j]

                // Check for overlap
                if event1.endDate > event2.startDate && event1.startDate < event2.endDate {
                    let overlapStart = max(event1.startDate, event2.startDate)
                    let overlapEnd = min(event1.endDate, event2.endDate)
                    let overlapMinutes = Int(overlapEnd.timeIntervalSince(overlapStart) / 60)

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "h:mm a"

                    let conflict = InsightsScheduleConflict(
                        id: UUID().uuidString,
                        event1Title: event1.title,
                        event2Title: event2.title,
                        event1Time: "\(dateFormatter.string(from: event1.startDate)) - \(dateFormatter.string(from: event1.endDate))",
                        event2Time: "\(dateFormatter.string(from: event2.startDate)) - \(dateFormatter.string(from: event2.endDate))",
                        event1Source: event1.source,
                        event2Source: event2.source,
                        overlapMinutes: overlapMinutes,
                        timeDescription: "Both events occur on \(formatDate(event1.startDate))",
                        resolutionOptions: [
                            "Reschedule \(event1.title)",
                            "Reschedule \(event2.title)",
                            "Decline \(event1.title)",
                            "Decline \(event2.title)"
                        ]
                    )
                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    // MARK: - Duplicate Detection
    private func detectDuplicates(_ events: [UnifiedEvent]) -> [InsightsDuplicateEvent] {
        var duplicateList: [InsightsDuplicateEvent] = []

        // Use DuplicateEventDetector
        let duplicateDetector = DuplicateEventDetector()
        let duplicateGroups = duplicateDetector.detectDuplicates(in: events)

        // Convert to Insights model
        for group in duplicateGroups where group.confidence >= 0.7 {
            // Get all calendar sources for this duplicate group
            let sources = Array(Set(group.events.map { $0.source }))

            // Only show if it appears on multiple calendars
            if sources.count >= 2 {
                let primaryEvent = group.primaryEvent
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short

                let duplicate = InsightsDuplicateEvent(
                    id: UUID().uuidString,
                    eventTitle: primaryEvent.title,
                    eventTime: "\(dateFormatter.string(from: primaryEvent.startDate)) - \(dateFormatter.string(from: primaryEvent.endDate))",
                    sources: sources,
                    confidence: group.confidence,
                    matchType: matchTypeString(from: group.matchType)
                )
                duplicateList.append(duplicate)
            }
        }

        return duplicateList
    }

    private func matchTypeString(from matchType: DuplicateEventDetector.DuplicateGroup.MatchType) -> String {
        switch matchType {
        case .exact: return "exact"
        case .strong: return "strong"
        case .moderate: return "moderate"
        case .weak: return "weak"
        }
    }

    // MARK: - Logistics Analysis
    private func analyzeLogistics(_ events: [UnifiedEvent]) -> [InsightsLogisticsIssue] {
        var issues: [InsightsLogisticsIssue] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        // Guard against empty or single event arrays
        guard sortedEvents.count > 1 else {
            return []
        }

        for i in 0..<sortedEvents.count - 1 {
            let currentEvent = sortedEvents[i]
            let nextEvent = sortedEvents[i + 1]

            // Check for location changes requiring travel
            if let currentLocation = currentEvent.location,
               let nextLocation = nextEvent.location,
               currentLocation != nextLocation {

                let travelTime = nextEvent.startDate.timeIntervalSince(currentEvent.endDate) / 60

                if travelTime < 15 {
                    let issue = InsightsLogisticsIssue(
                        id: UUID().uuidString,
                        title: "Tight travel window",
                        description: "Only \(Int(travelTime)) minutes between \(currentEvent.title) at \(currentLocation) and \(nextEvent.title) at \(nextLocation)",
                        severity: .high,
                        icon: "exclamationmark.triangle.fill",
                        suggestion: "Consider adding 15-30 minutes buffer time"
                    )
                    issues.append(issue)
                } else if travelTime < 30 {
                    let issue = InsightsLogisticsIssue(
                        id: UUID().uuidString,
                        title: "Limited travel time",
                        description: "\(Int(travelTime)) minutes to travel from \(currentLocation) to \(nextLocation)",
                        severity: .medium,
                        icon: "car.fill",
                        suggestion: "Check traffic conditions before leaving"
                    )
                    issues.append(issue)
                }
            }

            // Check for back-to-back meetings without breaks
            if nextEvent.startDate == currentEvent.endDate {
                let issue = InsightsLogisticsIssue(
                    id: UUID().uuidString,
                    title: "No break between meetings",
                    description: "\(currentEvent.title) ends right when \(nextEvent.title) starts",
                    severity: .medium,
                    icon: "clock.badge.exclamationmark",
                    suggestion: "Consider adding a 5-10 minute buffer"
                )
                issues.append(issue)
            }
        }

        // Check for location clusters
        let locations = events.compactMap { $0.location }
        let locationCounts = Dictionary(grouping: locations, by: { $0 }).mapValues { $0.count }
        let clusteredLocations = locationCounts.filter { $0.value >= 3 }

        for (location, count) in clusteredLocations {
            let issue = InsightsLogisticsIssue(
                id: UUID().uuidString,
                title: "High activity location",
                description: "\(count) events at \(location) today",
                severity: .low,
                icon: "mappin.circle.fill",
                suggestion: "Consider batching meetings at this location"
            )
            issues.append(issue)
        }

        return issues
    }

    // MARK: - Pattern Detection
    private func detectPatterns(_ events: [UnifiedEvent]) -> [InsightsSchedulePattern] {
        var patterns: [InsightsSchedulePattern] = []

        // Meeting frequency pattern
        let meetingsByDay = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }

        let avgMeetingsPerDay = Double(events.count) / 7.0
        if avgMeetingsPerDay > 5 {
            let dataPoints = meetingsByDay.values.map { Double($0.count) / 10.0 }
            let pattern = InsightsSchedulePattern(
                id: UUID().uuidString,
                title: "High Meeting Volume",
                description: String(format: "Averaging %.1f meetings per day this week", avgMeetingsPerDay),
                icon: "chart.bar.fill",
                dataPoints: Array(dataPoints.prefix(7))
            )
            patterns.append(pattern)
        }

        // Time of day pattern
        let morningEvents = events.filter { event in
            let hour = Calendar.current.component(.hour, from: event.startDate)
            return hour >= 6 && hour < 12
        }
        let afternoonEvents = events.filter { event in
            let hour = Calendar.current.component(.hour, from: event.startDate)
            return hour >= 12 && hour < 17
        }
        let eveningEvents = events.filter { event in
            let hour = Calendar.current.component(.hour, from: event.startDate)
            return hour >= 17 && hour < 22
        }

        let maxCount = max(morningEvents.count, afternoonEvents.count, eveningEvents.count)
        if maxCount > 0 {
            let dataPoints = [
                Double(morningEvents.count) / Double(maxCount),
                Double(afternoonEvents.count) / Double(maxCount),
                Double(eveningEvents.count) / Double(maxCount)
            ]

            var timePreference = "morning"
            if afternoonEvents.count > morningEvents.count && afternoonEvents.count > eveningEvents.count {
                timePreference = "afternoon"
            } else if eveningEvents.count > morningEvents.count && eveningEvents.count > afternoonEvents.count {
                timePreference = "evening"
            }

            let pattern = InsightsSchedulePattern(
                id: UUID().uuidString,
                title: "Peak Activity Time",
                description: "Most events scheduled in the \(timePreference)",
                icon: "clock.fill",
                dataPoints: dataPoints
            )
            patterns.append(pattern)
        }

        // Duration pattern
        let shortEvents = events.filter { $0.endDate.timeIntervalSince($0.startDate) <= 1800 } // 30 min or less
        let mediumEvents = events.filter { event in
            let duration = event.endDate.timeIntervalSince(event.startDate)
            return duration > 1800 && duration <= 3600 // 30-60 min
        }
        let longEvents = events.filter { $0.endDate.timeIntervalSince($0.startDate) > 3600 } // > 60 min

        if events.count > 0 {
            let maxDurationCount = max(shortEvents.count, mediumEvents.count, longEvents.count)
            let dataPoints = [
                Double(shortEvents.count) / Double(maxDurationCount),
                Double(mediumEvents.count) / Double(maxDurationCount),
                Double(longEvents.count) / Double(maxDurationCount)
            ]

            let pattern = InsightsSchedulePattern(
                id: UUID().uuidString,
                title: "Meeting Duration",
                description: "\(shortEvents.count) short, \(mediumEvents.count) medium, \(longEvents.count) long events",
                icon: "timer",
                dataPoints: dataPoints
            )
            patterns.append(pattern)
        }

        return patterns
    }

    // MARK: - AI Recommendations
    private func generateRecommendations(_ events: [UnifiedEvent]) async {
        var recs: [InsightsAIRecommendation] = []

        // Recommend breaks if too many back-to-back meetings
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var backToBackCount = 0

        // Guard against empty or single event arrays
        guard sortedEvents.count > 1 else {
            return
        }

        for i in 0..<sortedEvents.count - 1 {
            if sortedEvents[i + 1].startDate == sortedEvents[i].endDate {
                backToBackCount += 1
            }
        }

        if backToBackCount >= 3 {
            let rec = InsightsAIRecommendation(
                id: UUID().uuidString,
                title: "Schedule Break Time",
                description: "You have \(backToBackCount) back-to-back meetings. Consider adding 10-minute breaks.",
                icon: "cup.and.saucer.fill",
                priority: .high,
                actionTitle: "Add Breaks",
                action: .addBreaks
            )
            recs.append(rec)
        }

        // Recommend focus time if schedule is too fragmented
        if events.count > 6 {
            let rec = InsightsAIRecommendation(
                id: UUID().uuidString,
                title: "Block Focus Time",
                description: "High meeting density today. Block time for deep work tomorrow.",
                icon: "brain.head.profile",
                priority: .medium,
                actionTitle: "Block Time",
                action: .blockFocusTime
            )
            recs.append(rec)
        }

        // Recommend decline if overbooked
        if scheduledHours > 10 {
            let rec = InsightsAIRecommendation(
                id: UUID().uuidString,
                title: "Consider Declining",
                description: String(format: "%.1f hours scheduled today. You may be overcommitted.", scheduledHours),
                icon: "hand.raised.fill",
                priority: .high,
                actionTitle: nil,
                action: .none
            )
            recs.append(rec)
        }

        // Recommend travel prep if high travel time
        if totalTravelTime > 60 {
            let rec = InsightsAIRecommendation(
                id: UUID().uuidString,
                title: "Prepare for Travel",
                description: String(format: "%.0f minutes of travel time today. Check routes and traffic.", totalTravelTime),
                icon: "map.fill",
                priority: .medium,
                actionTitle: "View Routes",
                action: .viewRoutes
            )
            recs.append(rec)
        }

        // Use AI to generate personalized recommendation if on-device AI available
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Config.aiProvider == .onDevice {
            do {
                let aiRec = try await OnDeviceAIService.shared.generateScheduleRecommendation(
                    events: events,
                    conflicts: conflicts,
                    logisticsIssues: logisticsIssues
                )
                recs.append(aiRec)
            } catch {
                print("Failed to generate AI recommendation: \(error)")
            }
        }
        #endif

        recommendations = recs
    }

    // MARK: - Health Score Calculation
    private func calculateHealthScores() {
        // Time utilization score (ideal: 6-8 hours)
        if scheduledHours >= 6 && scheduledHours <= 8 {
            timeUtilizationScore = 100
        } else if scheduledHours < 6 {
            timeUtilizationScore = (scheduledHours / 6) * 100
        } else {
            timeUtilizationScore = max(0, 100 - ((scheduledHours - 8) * 10))
        }

        // Conflict score (0 conflicts = 100)
        conflictScore = max(0, 100 - (Double(conflicts.count) * 20))

        // Balance score (based on free time blocks)
        if freeTimeBlocks >= 3 {
            balanceScore = 100
        } else if freeTimeBlocks == 2 {
            balanceScore = 70
        } else if freeTimeBlocks == 1 {
            balanceScore = 40
        } else {
            balanceScore = 10
        }

        // Buffer score (based on logistics issues)
        let highSeverityIssues = logisticsIssues.filter { $0.severity == .high }.count
        bufferScore = max(0, 100 - (Double(highSeverityIssues) * 25))

        // Overall health score (weighted average)
        healthScore = (timeUtilizationScore * 0.3 +
                      conflictScore * 0.3 +
                      balanceScore * 0.2 +
                      bufferScore * 0.2)
    }

    // MARK: - Helper Calculations
    private func calculateScheduledHours(_ events: [UnifiedEvent]) -> Double {
        var totalSeconds: TimeInterval = 0
        for event in events {
            totalSeconds += event.endDate.timeIntervalSince(event.startDate)
        }
        return totalSeconds / 3600
    }

    private func calculateTravelTime(_ events: [UnifiedEvent]) -> Double {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var totalTravelMinutes: Double = 0

        // Guard against empty or single event arrays
        guard sortedEvents.count > 1 else {
            return 0
        }

        for i in 0..<sortedEvents.count - 1 {
            let currentEvent = sortedEvents[i]
            let nextEvent = sortedEvents[i + 1]

            if let currentLocation = currentEvent.location,
               let nextLocation = nextEvent.location,
               currentLocation != nextLocation {
                // Estimate 15 minutes travel time for different locations
                totalTravelMinutes += 15
            }
        }

        return totalTravelMinutes
    }

    private func calculateFreeTimeBlocks(_ events: [UnifiedEvent]) -> Int {
        guard !events.isEmpty else { return 0 }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var freeBlocks = 0

        // Check morning before first event
        let firstEventHour = Calendar.current.component(.hour, from: sortedEvents[0].startDate)
        if firstEventHour > 9 {
            freeBlocks += 1
        }

        // Check gaps between events (only if we have multiple events)
        if sortedEvents.count > 1 {
            for i in 0..<sortedEvents.count - 1 {
                let gapMinutes = sortedEvents[i + 1].startDate.timeIntervalSince(sortedEvents[i].endDate) / 60
                if gapMinutes >= 60 {
                    freeBlocks += 1
                }
            }
        }

        // Check evening after last event
        let lastEventHour = Calendar.current.component(.hour, from: sortedEvents[sortedEvents.count - 1].endDate)
        if lastEventHour < 17 {
            freeBlocks += 1
        }

        return freeBlocks
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Actions
    func resolveConflict(_ conflict: InsightsScheduleConflict, with option: String) {
        // Implementation depends on calendar manager capabilities
        print("Resolving conflict with option: \(option)")
        // Remove conflict from list
        conflicts.removeAll { $0.id == conflict.id }
        calculateHealthScores()
    }

    func executeRecommendation(_ recommendation: InsightsAIRecommendation) {
        switch recommendation.action {
        case .addBreaks:
            print("Adding breaks to schedule")
            // Implementation: Add 10-min buffer events between meetings
        case .blockFocusTime:
            print("Blocking focus time")
            // Implementation: Create focus time block for tomorrow
        case .viewRoutes:
            print("Opening routes view")
            // Implementation: Open maps or route planning
        case .none:
            break
        }
    }
}

// MARK: - Supporting Extensions
#if canImport(FoundationModels)
@available(iOS 26.0, *)
extension OnDeviceAIService {
    func generateScheduleRecommendation(
        events: [UnifiedEvent],
        conflicts: [InsightsScheduleConflict],
        logisticsIssues: [InsightsLogisticsIssue]
    ) async throws -> InsightsAIRecommendation {
        // Simplified AI recommendation generation
        // In production, this would use the actual AI model
        return InsightsAIRecommendation(
            id: UUID().uuidString,
            title: "AI Insight",
            description: "Based on your schedule patterns, consider consolidating meetings on specific days.",
            icon: "sparkles",
            priority: .medium,
            actionTitle: nil,
            action: .none
        )
    }
}
#endif
