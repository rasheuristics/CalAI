import XCTest
@testable import CalAI

/// Manual tests for Smart Scheduling Service (C)
class SmartSchedulingTests: XCTestCase {

    var schedulingService: SmartSchedulingService!
    var testEvents: [UnifiedEvent]!

    override func setUp() {
        super.setUp()
        schedulingService = SmartSchedulingService()

        // Create test events with patterns
        testEvents = createTestEvents()
    }

    func testPatternAnalysis() {
        print("\n🧪 Testing Pattern Analysis...")

        let patterns = schedulingService.analyzeCalendarPatterns(events: testEvents)

        print("✅ Preferred meeting hours: \(patterns.preferredMeetingHours)")
        print("✅ Average meeting duration: \(Int(patterns.typicalMeetingDuration / 60)) minutes")
        print("✅ Has lunch pattern: \(patterns.hasLunchPattern)")

        XCTAssertFalse(patterns.preferredMeetingHours.isEmpty, "Should detect preferred hours")
        XCTAssertGreaterThan(patterns.typicalMeetingDuration, 0, "Should calculate duration")
    }

    func testOptimalTimeSuggestion() {
        print("\n🧪 Testing Optimal Time Suggestion...")

        let suggestion = schedulingService.suggestOptimalTime(
            for: 1800, // 30 minutes
            events: testEvents
        )

        print("✅ Suggested time: \(suggestion.suggestedTime)")
        print("✅ Confidence: \(suggestion.confidence)")
        print("✅ Reasons:")
        for reason in suggestion.reasons {
            print("   - \(reason)")
        }
        print("✅ Alternatives: \(suggestion.alternatives.count)")

        XCTAssertGreaterThan(suggestion.confidence, 0, "Should have confidence score")
        XCTAssertFalse(suggestion.reasons.isEmpty, "Should provide reasons")
    }

    func testConflictDetection() {
        print("\n🧪 Testing Conflict Detection...")

        // Try to schedule during an existing event
        let conflictTime = testEvents.first!.startDate.addingTimeInterval(300) // 5 min after start

        let issues = schedulingService.detectSchedulingIssues(
            proposedTime: conflictTime,
            duration: 1800,
            events: testEvents
        )

        print("✅ Issues detected: \(issues.count)")
        for issue in issues {
            print("   ⚠️ \(issue)")
        }

        XCTAssertFalse(issues.isEmpty, "Should detect conflict")
        XCTAssertTrue(issues.contains { $0.contains("Conflicts") }, "Should warn about conflict")
    }

    // MARK: - Helper Methods

    private func createTestEvents() -> [UnifiedEvent] {
        var events: [UnifiedEvent] = []
        let calendar = Calendar.current
        let now = Date()

        // Create events with patterns over the past 30 days
        for dayOffset in -30...0 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            // Morning meeting at 10 AM (typical pattern)
            if let morningStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) {
                let morningEnd = morningStart.addingTimeInterval(1800) // 30 min
                events.append(createTestEvent(
                    title: "Morning Standup",
                    start: morningStart,
                    end: morningEnd
                ))
            }

            // Afternoon meeting at 2 PM (typical pattern)
            if dayOffset % 2 == 0, // Every other day
               let afternoonStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) {
                let afternoonEnd = afternoonStart.addingTimeInterval(1800) // 30 min
                events.append(createTestEvent(
                    title: "Team Sync",
                    start: afternoonStart,
                    end: afternoonEnd
                ))
            }

            // Lunch block (pattern detection)
            if dayOffset % 3 == 0, // Every third day
               let lunchStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) {
                let lunchEnd = lunchStart.addingTimeInterval(3600) // 1 hour
                events.append(createTestEvent(
                    title: "Lunch",
                    start: lunchStart,
                    end: lunchEnd
                ))
            }
        }

        print("📅 Created \(events.count) test events")
        return events
    }

    private func createTestEvent(title: String, start: Date, end: Date) -> UnifiedEvent {
        return UnifiedEvent(
            id: UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            location: nil,
            notes: nil,
            isAllDay: false,
            calendar: nil,
            sourceType: .local,
            priority: .normal,
            recurrenceRule: nil
        )
    }
}
