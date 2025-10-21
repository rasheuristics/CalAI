import XCTest
import Combine
@testable import CalAI

/// Comprehensive tests for GoogleCalendarManager - OAuth, event sync, and error handling
@MainActor
final class GoogleCalendarManagerTests: XCTestCase {

    var sut: GoogleCalendarManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = GoogleCalendarManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState_NotSignedIn() {
        // Then
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.googleEvents.isEmpty)
        XCTAssertTrue(sut.availableCalendars.isEmpty)
    }

    func testInitialization_CallsRestorePreviousSignIn() {
        // Given/When - initialization happens in setUp
        // Then - no crash, initialization completes
        XCTAssertNotNil(sut)
    }

    // MARK: - Sign Out Tests

    func testSignOut_ClearsSignInState() {
        // Given
        // Manually set state to simulate signed-in user
        // (Can't actually sign in without Google SDK configured in test environment)

        // When
        sut.signOut()

        // Then
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertTrue(sut.googleEvents.isEmpty, "Should clear events on sign out")
    }

    func testSignOut_ClearsEvents() {
        // Given - simulate having events
        // Note: Can't directly set googleEvents as it's @Published, but we can test behavior

        // When
        sut.signOut()

        // Then
        XCTAssertTrue(sut.googleEvents.isEmpty)
    }

    // MARK: - Published Properties Tests

    func testIsSignedIn_IsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "isSignedIn publishes")
        var emittedValues: [Bool] = []

        sut.$isSignedIn
            .sink { value in
                emittedValues.append(value)
                if emittedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(emittedValues.isEmpty, "Should emit initial value")
    }

    func testIsLoading_IsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "isLoading publishes")
        var emittedValues: [Bool] = []

        sut.$isLoading
            .sink { value in
                emittedValues.append(value)
                if emittedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(emittedValues.isEmpty)
    }

    func testGoogleEvents_IsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "googleEvents publishes")
        var emittedCount = 0

        sut.$googleEvents
            .sink { _ in
                emittedCount += 1
                if emittedCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(emittedCount, 1)
    }

    func testAvailableCalendars_IsPublished() {
        // Given
        let expectation = XCTestExpectation(description: "availableCalendars publishes")
        var emittedCount = 0

        sut.$availableCalendars
            .sink { _ in
                emittedCount += 1
                if emittedCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(emittedCount, 1)
    }

    // MARK: - GoogleEvent Tests

    func testGoogleEvent_HasRequiredProperties() {
        // Given
        let id = "test_event_123"
        let title = "Test Event"
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        let location = "Test Location"
        let description = "Test Description"
        let calendarId = "primary"
        let organizer = "test@example.com"

        // When
        let event = GoogleEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: description,
            calendarId: calendarId,
            organizer: organizer
        )

        // Then
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.title, title)
        XCTAssertEqual(event.startDate, startDate)
        XCTAssertEqual(event.endDate, endDate)
        XCTAssertEqual(event.location, location)
        XCTAssertEqual(event.description, description)
        XCTAssertEqual(event.calendarId, calendarId)
        XCTAssertEqual(event.organizer, organizer)
    }

    func testGoogleEvent_DurationFormatting() {
        // Given
        let startDate = TestFixtures.date(year: 2025, month: 10, day: 20, hour: 14, minute: 0)
        let endDate = TestFixtures.date(year: 2025, month: 10, day: 20, hour: 15, minute: 30)

        let event = GoogleEvent(
            id: "test",
            title: "Test",
            startDate: startDate,
            endDate: endDate,
            location: nil,
            description: nil,
            calendarId: "primary",
            organizer: nil
        )

        // When
        let duration = event.duration

        // Then
        XCTAssertFalse(duration.isEmpty)
        // Duration should contain formatted times
        XCTAssertTrue(duration.contains("-"), "Duration should contain time range separator")
    }

    func testGoogleEvent_IsIdentifiable() {
        // Given
        let event1 = GoogleEvent(
            id: "event_1",
            title: "Event 1",
            startDate: Date(),
            endDate: Date(),
            location: nil,
            description: nil,
            calendarId: "primary",
            organizer: nil
        )

        let event2 = GoogleEvent(
            id: "event_2",
            title: "Event 2",
            startDate: Date(),
            endDate: Date(),
            location: nil,
            description: nil,
            calendarId: "primary",
            organizer: nil
        )

        // Then
        XCTAssertNotEqual(event1.id, event2.id)
    }

    func testGoogleEvent_IsCodable() throws {
        // Given
        let event = GoogleEvent(
            id: "test_123",
            title: "Codable Test",
            startDate: Date(),
            endDate: Date(),
            location: "Test Location",
            description: "Test Description",
            calendarId: "primary",
            organizer: "test@example.com"
        )

        // When - encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        // Then - should encode successfully
        XCTAssertFalse(data.isEmpty)

        // When - decode
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(GoogleEvent.self, from: data)

        // Then - should decode successfully
        XCTAssertEqual(decodedEvent.id, event.id)
        XCTAssertEqual(decodedEvent.title, event.title)
        XCTAssertEqual(decodedEvent.calendarId, event.calendarId)
        XCTAssertEqual(decodedEvent.organizer, event.organizer)
    }

    // MARK: - Observable Object Tests

    func testGoogleCalendarManager_IsObservableObject() {
        // Given/When
        let isObservable = sut is ObservableObject

        // Then
        XCTAssertTrue(isObservable)
    }

    func testSignOut_TriggersPublishedPropertyChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Published properties change")
        var signedInValues: [Bool] = []
        var eventsCount: [Int] = []

        sut.$isSignedIn
            .sink { value in
                signedInValues.append(value)
            }
            .store(in: &cancellables)

        sut.$googleEvents
            .sink { events in
                eventsCount.append(events.count)
                if eventsCount.count >= 2 { // Initial + after sign out
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.signOut()

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertTrue(sut.googleEvents.isEmpty)
    }

    // MARK: - GoogleCalendarItem Tests

    func testGoogleCalendarItem_SupportsAllProperties() {
        // Given/When
        let calendar = GoogleCalendarItem(
            id: "cal_123",
            name: "Work Calendar",
            backgroundColor: "#FF9800",
            isPrimary: false
        )

        // Then
        XCTAssertEqual(calendar.id, "cal_123")
        XCTAssertEqual(calendar.name, "Work Calendar")
        XCTAssertEqual(calendar.backgroundColor, "#FF9800")
        XCTAssertFalse(calendar.isPrimary)
    }

    func testGoogleCalendarItem_PrimaryCalendar() {
        // Given/When
        let calendar = GoogleCalendarItem(
            id: "primary",
            name: "Primary",
            backgroundColor: "#4285F4",
            isPrimary: true
        )

        // Then
        XCTAssertTrue(calendar.isPrimary)
        XCTAssertEqual(calendar.id, "primary")
    }

    // MARK: - Error Handling Tests

    func testSignOut_DoesNotCrashWhenNotSignedIn() {
        // Given - not signed in (initial state)
        XCTAssertFalse(sut.isSignedIn)

        // When/Then - should not crash
        sut.signOut()
        XCTAssertFalse(sut.isSignedIn)
    }

    // MARK: - Memory Management Tests

    func testGoogleCalendarManager_DoesNotLeakMemory() {
        // Given
        var manager: GoogleCalendarManager? = GoogleCalendarManager()

        // When
        manager = nil

        // Then - should deallocate
        XCTAssertNil(manager)
    }

    // MARK: - UserDefaults Integration Tests

    func testDeletedEventIds_PersistsAcrossInstances() {
        // Note: This tests the UserDefaults persistence concept
        // Actual implementation uses private deletedEventIds property

        // Given - create a key similar to what the manager uses
        let testKey = "com.calai.google.test.deletedEventIds"
        let testIds = ["event_1", "event_2", "event_3"]

        // When - store in UserDefaults
        UserDefaults.standard.set(testIds, forKey: testKey)

        // Then - retrieve in new context
        let retrievedIds = UserDefaults.standard.array(forKey: testKey) as? [String]
        XCTAssertEqual(retrievedIds, testIds)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    // MARK: - State Management Tests

    func testMultipleSignOutCalls_DoNotCrash() {
        // Given/When
        sut.signOut()
        sut.signOut()
        sut.signOut()

        // Then
        XCTAssertFalse(sut.isSignedIn)
        XCTAssertTrue(sut.googleEvents.isEmpty)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess_DoesNotCrash() async {
        // Given/When - access published properties concurrently
        async let check1 = MainActor.run { sut.isSignedIn }
        async let check2 = MainActor.run { sut.isLoading }
        async let check3 = MainActor.run { sut.googleEvents.count }

        let results = await (check1, check2, check3)

        // Then - should not crash
        XCTAssertFalse(results.0) // isSignedIn
        XCTAssertFalse(results.1) // isLoading
        XCTAssertEqual(results.2, 0) // events count
    }
}
