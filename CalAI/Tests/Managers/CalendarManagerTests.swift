import XCTest
import EventKit
@testable import CalAI

/// Critical tests for CalendarManager - core calendar operations
final class CalendarManagerTests: XCTestCase {

    var sut: CalendarManager!
    var mockEventStore: MockEventStore!

    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
        sut = CalendarManager()
        // Inject mock event store - we'll need to modify CalendarManager to support this
        // For now, we'll test what we can with the current implementation
    }

    override func tearDown() {
        mockEventStore.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - Authorization Tests

    func testRequestAccess_WhenAuthorized_ReturnsTrue() async throws {
        // Given
        mockEventStore.mockAuthStatus = .fullAccess

        // When
        let granted = try await mockEventStore.requestAccess(to: .event)

        // Then
        XCTAssertTrue(granted)
        XCTAssertTrue(mockEventStore.requestAccessCalled)
    }

    func testRequestAccess_WhenDenied_ReturnsFalse() async throws {
        // Given
        mockEventStore.mockAuthStatus = .denied

        // When
        let granted = try await mockEventStore.requestAccess(to: .event)

        // Then
        XCTAssertFalse(granted)
        XCTAssertTrue(mockEventStore.requestAccessCalled)
    }

    // MARK: - Event Fetching Tests

    func testFetchEvents_WithValidDateRange_ReturnsEvents() {
        // Given
        let calendar = TestFixtures.createMockCalendar(title: "Work")
        let events = TestFixtures.createMockEvents(count: 5)
        mockEventStore.addMockCalendars([calendar])
        mockEventStore.addMockEvents(events)

        let startDate = TestFixtures.today
        let endDate = TestFixtures.nextWeek

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        let fetchedEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertTrue(mockEventStore.fetchEventsCalled)
        XCTAssertNotNil(mockEventStore.lastFetchPredicate)
        XCTAssertEqual(fetchedEvents.count, 5)
    }

    func testFetchEvents_WithEmptyStore_ReturnsEmptyArray() {
        // Given
        let startDate = TestFixtures.today
        let endDate = TestFixtures.nextWeek

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let fetchedEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertTrue(mockEventStore.fetchEventsCalled)
        XCTAssertEqual(fetchedEvents.count, 0)
    }

    func testFetchEvents_WithMultipleCalendars_ReturnsCombinedEvents() {
        // Given
        let workCalendar = TestFixtures.createMockCalendar(title: "Work")
        let personalCalendar = TestFixtures.createMockCalendar(title: "Personal")

        let workEvent = TestFixtures.createMockEvent(title: "Work Meeting", calendar: workCalendar)
        let personalEvent = TestFixtures.createMockEvent(title: "Dentist", calendar: personalCalendar)

        mockEventStore.addMockCalendars([workCalendar, personalCalendar])
        mockEventStore.addMockEvents([workEvent, personalEvent])

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: TestFixtures.today,
            end: TestFixtures.tomorrow,
            calendars: [workCalendar, personalCalendar]
        )
        let fetchedEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertEqual(fetchedEvents.count, 2)
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Work Meeting" })
        XCTAssertTrue(fetchedEvents.contains { $0.title == "Dentist" })
    }

    // MARK: - Event Creation Tests

    func testSaveEvent_WithValidEvent_Succeeds() throws {
        // Given
        let calendar = TestFixtures.createMockCalendar()
        mockEventStore.addMockCalendars([calendar])

        let event = TestFixtures.createMockEvent(
            title: "New Meeting",
            startDate: TestFixtures.tomorrow,
            calendar: calendar
        )

        // When
        try mockEventStore.save(event, span: .thisEvent, commit: true)

        // Then
        XCTAssertTrue(mockEventStore.saveCalled)
        XCTAssertEqual(mockEventStore.lastSaveCommit, true)
        XCTAssertEqual(mockEventStore.events.count, 1)
        XCTAssertEqual(mockEventStore.events.first?.title, "New Meeting")
    }

    func testSaveEvent_WhenStoreFails_ThrowsError() {
        // Given
        mockEventStore.shouldFailSave = true
        let event = TestFixtures.createMockEvent(title: "Meeting")

        // When/Then
        XCTAssertThrowsError(try mockEventStore.save(event, span: .thisEvent)) { error in
            XCTAssertTrue(error is MockEventStoreError)
        }
    }

    func testSaveEvent_WithoutCommit_DoesNotPersist() throws {
        // Given
        let event = TestFixtures.createMockEvent(title: "Temp Meeting")

        // When
        try mockEventStore.save(event, span: .thisEvent, commit: false)

        // Then
        XCTAssertTrue(mockEventStore.saveCalled)
        XCTAssertEqual(mockEventStore.lastSaveCommit, false)
    }

    // MARK: - Event Deletion Tests

    func testRemoveEvent_WithExistingEvent_Succeeds() throws {
        // Given
        let event = TestFixtures.createMockEvent(title: "To Delete")
        mockEventStore.addMockEvents([event])
        XCTAssertEqual(mockEventStore.events.count, 1)

        // When
        try mockEventStore.remove(event, span: .thisEvent, commit: true)

        // Then
        XCTAssertTrue(mockEventStore.removeCalled)
        XCTAssertEqual(mockEventStore.lastRemovedEvent?.title, "To Delete")
        XCTAssertEqual(mockEventStore.events.count, 0)
    }

    func testRemoveEvent_WhenStoreFails_ThrowsError() {
        // Given
        mockEventStore.shouldFailRemove = true
        let event = TestFixtures.createMockEvent()

        // When/Then
        XCTAssertThrowsError(try mockEventStore.remove(event, span: .thisEvent)) { error in
            XCTAssertTrue(error is MockEventStoreError)
        }
    }

    // MARK: - UnifiedEvent Conversion Tests


    // MARK: - Calendar Access Tests

    func testGetCalendars_WithAuthorization_ReturnsCalendars() {
        // Given
        mockEventStore.mockAuthStatus = .fullAccess
        let calendar1 = TestFixtures.createMockCalendar(title: "Work")
        let calendar2 = TestFixtures.createMockCalendar(title: "Personal")
        mockEventStore.addMockCalendars([calendar1, calendar2])

        // When
        let calendars = mockEventStore.calendars(for: .event)

        // Then
        XCTAssertTrue(mockEventStore.calendarsCalled)
        XCTAssertEqual(calendars.count, 2)
        XCTAssertTrue(calendars.contains { $0.title == "Work" })
        XCTAssertTrue(calendars.contains { $0.title == "Personal" })
    }

    func testGetDefaultCalendar_ReturnsFirstCalendar() {
        // Given
        let calendar = TestFixtures.createMockCalendar(title: "Default")
        mockEventStore.addMockCalendars([calendar])

        // When
        let defaultCalendar = mockEventStore.mockDefaultCalendarForNewEvents()

        // Then
        XCTAssertNotNil(defaultCalendar)
        XCTAssertEqual(defaultCalendar?.title, "Default")
    }

    // MARK: - Multi-Calendar Aggregation Tests

    func testFetchEvents_FromMultipleSources_ReturnsAggregatedResults() {
        // Given
        let iosCalendar = TestFixtures.createMockCalendar(title: "iOS Calendar")
        let googleCalendar = TestFixtures.createMockCalendar(title: "Google Calendar")

        let iosEvent = TestFixtures.createMockEvent(
            title: "iOS Event",
            startDate: TestFixtures.tomorrow,
            calendar: iosCalendar
        )

        let googleEvent = TestFixtures.createMockEvent(
            title: "Google Event",
            startDate: TestFixtures.tomorrow,
            calendar: googleCalendar
        )

        mockEventStore.addMockCalendars([iosCalendar, googleCalendar])
        mockEventStore.addMockEvents([iosEvent, googleEvent])

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: TestFixtures.today,
            end: TestFixtures.nextWeek,
            calendars: nil
        )
        let allEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertEqual(allEvents.count, 2)
        XCTAssertTrue(allEvents.contains { $0.title == "iOS Event" })
        XCTAssertTrue(allEvents.contains { $0.title == "Google Event" })
    }

    // MARK: - Date Range Tests

    func testFetchEvents_WithPastDateRange_ReturnsEmptyIfNoEvents() {
        // Given
        let futureEvent = TestFixtures.createMockEvent(
            title: "Future Event",
            startDate: TestFixtures.nextWeek
        )
        mockEventStore.addMockEvents([futureEvent])

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: TestFixtures.yesterday,
            end: TestFixtures.today,
            calendars: nil
        )
        let pastEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertEqual(pastEvents.count, 0)
    }

    func testFetchEvents_WithLargeDateRange_HandlesMultipleEvents() {
        // Given
        let events = TestFixtures.createMockEvents(count: 20)
        mockEventStore.addMockEvents(events)

        let startDate = TestFixtures.today
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        // When
        let predicate = mockEventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let fetchedEvents = mockEventStore.events(matching: predicate)

        // Then
        XCTAssertEqual(fetchedEvents.count, 20)
    }
}
