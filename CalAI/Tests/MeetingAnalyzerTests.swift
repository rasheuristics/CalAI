import XCTest
@testable import CalAI

final class MeetingAnalyzerTests: XCTestCase {
    var analyzer: MeetingAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = MeetingAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Virtual Meeting Detection Tests

    func testDetectsZoomMeeting() {
        let event = createEvent(title: "Team Standup", notes: "Join Zoom: https://zoom.us/j/123456789")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .virtual)
        XCTAssertTrue(result.hasVirtualLink)
        XCTAssertEqual(result.meetingPlatform, .zoom)
    }

    func testDetectsTeamsMeeting() {
        let event = createEvent(title: "Client Call", notes: "Join: https://teams.microsoft.com/l/meetup-join/...")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .virtual)
        XCTAssertTrue(result.hasVirtualLink)
        XCTAssertEqual(result.meetingPlatform, .teams)
    }

    func testDetectsGoogleMeetMeeting() {
        let event = createEvent(title: "Project Review", notes: "https://meet.google.com/abc-defg-hij")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .virtual)
        XCTAssertTrue(result.hasVirtualLink)
        XCTAssertEqual(result.meetingPlatform, .meet)
    }

    // MARK: - Physical Meeting Detection Tests

    func testDetectsPhysicalMeeting() {
        let event = createEvent(title: "Lunch Meeting", location: "Starbucks, 123 Main St")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .physical)
        XCTAssertFalse(result.hasVirtualLink)
        XCTAssertTrue(result.hasLocation)
    }

    func testDetectsPhysicalMeetingWithoutLocation() {
        let event = createEvent(title: "Coffee with Sarah")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .unknown)
        XCTAssertFalse(result.hasLocation)
    }

    // MARK: - Hybrid Meeting Detection Tests

    func testDetectsHybridMeeting() {
        let event = createEvent(
            title: "All Hands",
            location: "Conference Room A",
            notes: "Also available on Zoom: https://zoom.us/j/987654321"
        )

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .hybrid)
        XCTAssertTrue(result.hasLocation)
        XCTAssertTrue(result.hasVirtualLink)
    }

    // MARK: - Meeting Platform Detection Tests

    func testDetectsMultiplePlatforms() {
        let zoomEvent = createEvent(notes: "https://zoom.us/j/123")
        let teamsEvent = createEvent(notes: "https://teams.microsoft.com/...")
        let meetEvent = createEvent(notes: "https://meet.google.com/xyz")

        XCTAssertEqual(analyzer.analyzeMeeting(zoomEvent).meetingPlatform, .zoom)
        XCTAssertEqual(analyzer.analyzeMeeting(teamsEvent).meetingPlatform, .teams)
        XCTAssertEqual(analyzer.analyzeMeeting(meetEvent).meetingPlatform, .meet)
    }

    func testNoPlatformDetected() {
        let event = createEvent(title: "Meeting", notes: "See you there")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertNil(result.meetingPlatform)
    }

    // MARK: - Travel Time Requirement Tests

    func testPhysicalMeetingRequiresTravelTime() {
        let event = createEvent(location: "123 Main St")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertTrue(result.requiresTravelTime)
    }

    func testVirtualMeetingDoesNotRequireTravelTime() {
        let event = createEvent(notes: "https://zoom.us/j/123")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertFalse(result.requiresTravelTime)
    }

    // MARK: - Edge Cases

    func testEmptyEvent() {
        let event = createEvent()

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .unknown)
        XCTAssertFalse(result.hasLocation)
        XCTAssertFalse(result.hasVirtualLink)
    }

    func testEventWithOnlyTitle() {
        let event = createEvent(title: "Meeting")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.type, .unknown)
    }

    func testCaseInsensitivePlatformDetection() {
        let event = createEvent(notes: "Join ZOOM at https://ZOOM.us/j/123")

        let result = analyzer.analyzeMeeting(event)

        XCTAssertEqual(result.meetingPlatform, .zoom)
    }

    // MARK: - Helper Methods

    private func createEvent(
        title: String = "Test Event",
        location: String? = nil,
        notes: String? = nil
    ) -> UnifiedEvent {
        return UnifiedEvent(
            id: UUID().uuidString,
            title: title,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: location,
            notes: notes,
            source: .ios,
            calendarIdentifier: "test",
            lastModified: Date()
        )
    }
}
