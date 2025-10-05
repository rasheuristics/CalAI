import XCTest
@testable import CalAI

final class EventFilterServiceTests: XCTestCase {
    var service: EventFilterService!
    let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        service = EventFilterService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - UnifiedEvent Filtering Tests

    func testFilterTimedEventOnSameDay() {
        // Given: A timed event on Jan 1, 2024 at 10 AM
        let eventDate = createDate(year: 2024, month: 1, day: 1, hour: 10)
        let event = createUnifiedEvent(startDate: eventDate, isAllDay: false)

        // When: Filtering for Jan 1, 2024
        let filterDate = createDate(year: 2024, month: 1, day: 1)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, event.id)
    }

    func testFilterTimedEventOnDifferentDay() {
        // Given: A timed event on Jan 1, 2024
        let eventDate = createDate(year: 2024, month: 1, day: 1, hour: 10)
        let event = createUnifiedEvent(startDate: eventDate, isAllDay: false)

        // When: Filtering for Jan 2, 2024
        let filterDate = createDate(year: 2024, month: 1, day: 2)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should NOT be included
        XCTAssertEqual(filtered.count, 0)
    }

    func testFilterAllDayEventOnStartDay() {
        // Given: An all-day event from Jan 1-3, 2024
        let startDate = createDate(year: 2024, month: 1, day: 1)
        let endDate = createDate(year: 2024, month: 1, day: 3)
        let event = createUnifiedEvent(startDate: startDate, endDate: endDate, isAllDay: true)

        // When: Filtering for Jan 1 (start day)
        let filterDate = createDate(year: 2024, month: 1, day: 1)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterAllDayEventOnMiddleDay() {
        // Given: An all-day event from Jan 1-3, 2024
        let startDate = createDate(year: 2024, month: 1, day: 1)
        let endDate = createDate(year: 2024, month: 1, day: 3)
        let event = createUnifiedEvent(startDate: startDate, endDate: endDate, isAllDay: true)

        // When: Filtering for Jan 2 (middle day)
        let filterDate = createDate(year: 2024, month: 1, day: 2)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterAllDayEventOnEndDay() {
        // Given: An all-day event from Jan 1-3, 2024
        let startDate = createDate(year: 2024, month: 1, day: 1)
        let endDate = createDate(year: 2024, month: 1, day: 3)
        let event = createUnifiedEvent(startDate: startDate, endDate: endDate, isAllDay: true)

        // When: Filtering for Jan 3 (end day)
        let filterDate = createDate(year: 2024, month: 1, day: 3)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterAllDayEventOutsideRange() {
        // Given: An all-day event from Jan 1-3, 2024
        let startDate = createDate(year: 2024, month: 1, day: 1)
        let endDate = createDate(year: 2024, month: 1, day: 3)
        let event = createUnifiedEvent(startDate: startDate, endDate: endDate, isAllDay: true)

        // When: Filtering for Jan 5 (outside range)
        let filterDate = createDate(year: 2024, month: 1, day: 5)
        let filtered = service.filterUnifiedEvents([event], for: filterDate)

        // Then: Event should NOT be included
        XCTAssertEqual(filtered.count, 0)
    }

    func testFilterMultipleEventsWithMixedTypes() {
        // Given: Mix of timed and all-day events
        let jan1_10am = createDate(year: 2024, month: 1, day: 1, hour: 10)
        let jan2_2pm = createDate(year: 2024, month: 1, day: 2, hour: 14)
        let allDayStart = createDate(year: 2024, month: 1, day: 1)
        let allDayEnd = createDate(year: 2024, month: 1, day: 3)

        let timedEvent1 = createUnifiedEvent(id: "1", startDate: jan1_10am, isAllDay: false)
        let timedEvent2 = createUnifiedEvent(id: "2", startDate: jan2_2pm, isAllDay: false)
        let allDayEvent = createUnifiedEvent(id: "3", startDate: allDayStart, endDate: allDayEnd, isAllDay: true)

        // When: Filtering for Jan 1
        let filterDate = createDate(year: 2024, month: 1, day: 1)
        let filtered = service.filterUnifiedEvents([timedEvent1, timedEvent2, allDayEvent], for: filterDate)

        // Then: Should include timedEvent1 and allDayEvent only
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.id == "1" })
        XCTAssertTrue(filtered.contains { $0.id == "3" })
        XCTAssertFalse(filtered.contains { $0.id == "2" })
    }

    // MARK: - CalendarEvent Filtering Tests

    func testFilterCalendarEventOnSameDay() {
        // Given: A calendar event on Jan 1, 2024 at 10 AM
        let eventDate = createDate(year: 2024, month: 1, day: 1, hour: 10)
        let event = createCalendarEvent(start: eventDate, isAllDay: false)
        let dayStart = calendar.startOfDay(for: eventDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        // When: Filtering for Jan 1
        let filtered = service.filterCalendarEvents([event], dayStart: dayStart, dayEnd: dayEnd)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterCalendarAllDayEvent() {
        // Given: An all-day calendar event from Jan 1-3
        let startDate = createDate(year: 2024, month: 1, day: 1)
        let endDate = createDate(year: 2024, month: 1, day: 3)
        let event = createCalendarEvent(start: startDate, end: endDate, isAllDay: true)

        // When: Filtering for Jan 2 (middle day)
        let filterDate = createDate(year: 2024, month: 1, day: 2)
        let dayStart = calendar.startOfDay(for: filterDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let filtered = service.filterCalendarEvents([event], dayStart: dayStart, dayEnd: dayEnd)

        // Then: Event should be included
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - Helper Methods

    private func createDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func createUnifiedEvent(
        id: String = UUID().uuidString,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool
    ) -> UnifiedEvent {
        return UnifiedEvent(
            id: id,
            title: "Test Event",
            startDate: startDate,
            endDate: endDate ?? startDate.addingTimeInterval(3600),
            isAllDay: isAllDay,
            location: nil,
            notes: nil,
            source: .ios,
            calendarIdentifier: "test",
            lastModified: Date()
        )
    }

    private func createCalendarEvent(
        start: Date,
        end: Date? = nil,
        isAllDay: Bool
    ) -> CalendarEvent {
        struct TestCalendarEvent: CalendarEvent {
            let id: String
            let title: String?
            let start: Date
            let end: Date
            let eventLocation: String?
            let isAllDay: Bool
            let source: CalendarSource
        }

        return TestCalendarEvent(
            id: UUID().uuidString,
            title: "Test Event",
            start: start,
            end: end ?? start.addingTimeInterval(3600),
            eventLocation: nil,
            isAllDay: isAllDay,
            source: .ios
        )
    }
}
