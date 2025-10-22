import XCTest
import EventKit
import SwiftUI
@testable import CalAI

// MARK: - Test Fixtures

enum TestFixtures {

    // MARK: - Mock Events

    static func createMockEvent(
        title: String = "Test Event",
        startDate: Date = Date(),
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        calendar: EKCalendar? = nil
    ) -> EKEvent {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.isAllDay = isAllDay
        event.location = location
        event.calendar = calendar ?? createMockCalendar()
        return event
    }

    static func createMockCalendar(
        title: String = "Test Calendar",
        type: EKCalendarType = .local
    ) -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.title = title
        calendar.cgColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        return calendar
    }

    // MARK: - Mock Dates

    static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: today)!
    }

    static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today)!
    }

    static var nextWeek: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today)!
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    // MARK: - Mock UnifiedEvent

    static func createMockUnifiedEvent(
        id: String = UUID().uuidString,
        title: String = "Test Event",
        startDate: Date = Date(),
        endDate: Date? = nil,
        location: String? = nil,
        description: String? = nil,
        isAllDay: Bool = false,
        source: CalendarSource = .ios,
        organizer: String? = nil,
        calendarId: String? = "test-calendar-id",
        calendarName: String? = "Test Calendar",
        calendarColor: Color? = .blue
    ) -> UnifiedEvent {
        let ekEvent = createMockEvent(title: title, startDate: startDate, endDate: endDate, location: location)
        return UnifiedEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!,
            location: location,
            description: description,
            isAllDay: isAllDay,
            source: source,
            organizer: organizer,
            originalEvent: ekEvent,
            calendarId: calendarId,
            calendarName: calendarName,
            calendarColor: calendarColor
        )
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {

    /// Wait for async expectation with default timeout
    func waitForExpectations(timeout: TimeInterval = 5.0) {
        wait(for: [], timeout: timeout)
    }

    /// Create expectation with description
    func expectation(_ description: String) -> XCTestExpectation {
        return expectation(description: description)
    }

    /// Assert async throws
    func assertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: ((Error) -> Void)? = nil
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler?(error)
        }
    }
}

// MARK: - Async Test Helpers

/// Helper for testing async operations
actor AsyncTestHelper {
    private var tasks: [Task<Void, Never>] = []

    func addTask(_ task: Task<Void, Never>) {
        tasks.append(task)
    }

    func cancelAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    func waitForAll() async {
        for task in tasks {
            await task.value
        }
    }
}

// MARK: - Mock Data

extension TestFixtures {

    /// Sample event titles for testing
    static let sampleEventTitles = [
        "Team Meeting",
        "1-on-1 with John",
        "Doctor Appointment",
        "Lunch with Sarah",
        "Sprint Planning",
        "Code Review",
        "Gym Workout",
        "Dentist",
        "Client Call",
        "Coffee with Mike"
    ]

    /// Sample locations for testing
    static let sampleLocations = [
        "Conference Room A",
        "Zoom",
        "123 Main St, San Francisco, CA",
        "Starbucks",
        "Home Office",
        "Google Meet",
        "Building 2, Room 301"
    ]

    /// Create batch of mock events
    static func createMockEvents(count: Int) -> [EKEvent] {
        var events: [EKEvent] = []
        let calendar = Calendar.current
        var currentDate = today

        for i in 0..<count {
            let title = sampleEventTitles[i % sampleEventTitles.count]
            let location = i % 3 == 0 ? sampleLocations[i % sampleLocations.count] : nil

            let startDate = calendar.date(byAdding: .hour, value: i, to: currentDate)!
            let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!

            let event = createMockEvent(
                title: "\(title) \(i + 1)",
                startDate: startDate,
                endDate: endDate,
                location: location
            )
            events.append(event)

            // Move to next day every 5 events
            if (i + 1) % 5 == 0 {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        }

        return events
    }
}
