import XCTest
@testable import CalAI

final class AppErrorTests: XCTestCase {

    // MARK: - Error Identification Tests

    func testErrorIdentifiers() {
        // Each error should have a unique identifier
        let accessDenied = AppError.calendarAccessDenied
        let loadFailed = AppError.failedToLoadEvents(NSError(domain: "test", code: 1))
        let syncFailed = AppError.failedToSyncCalendar(source: "Google", NSError(domain: "test", code: 2))
        let networkError = AppError.networkError(NSError(domain: "test", code: 3))
        let unknownError = AppError.unknownError(NSError(domain: "test", code: 4))

        XCTAssertEqual(accessDenied.id, "calendarAccessDenied")
        XCTAssertEqual(loadFailed.id, "failedToLoadEvents")
        XCTAssertTrue(syncFailed.id.contains("failedToSyncCalendar"))
        XCTAssertEqual(networkError.id, "networkError")
        XCTAssertEqual(unknownError.id, "unknownError")
    }

    func testSyncErrorSourceInIdentifier() {
        // Sync error ID should include source name
        let googleSync = AppError.failedToSyncCalendar(source: "Google", NSError(domain: "test", code: 1))
        let outlookSync = AppError.failedToSyncCalendar(source: "Outlook", NSError(domain: "test", code: 1))

        XCTAssertEqual(googleSync.id, "failedToSyncCalendar_Google")
        XCTAssertEqual(outlookSync.id, "failedToSyncCalendar_Outlook")
    }

    // MARK: - Error Titles Tests

    func testErrorTitles() {
        let accessDenied = AppError.calendarAccessDenied
        XCTAssertEqual(accessDenied.title, "Calendar Access Denied")

        let loadFailed = AppError.failedToLoadEvents(NSError(domain: "test", code: 1))
        XCTAssertEqual(loadFailed.title, "Failed to Load Events")

        let googleSync = AppError.failedToSyncCalendar(source: "Google", NSError(domain: "test", code: 1))
        XCTAssertEqual(googleSync.title, "Google Sync Failed")

        let networkError = AppError.networkError(NSError(domain: "test", code: 1))
        XCTAssertEqual(networkError.title, "Network Error")

        let unknownError = AppError.unknownError(NSError(domain: "test", code: 1))
        XCTAssertEqual(unknownError.title, "Something Went Wrong")
    }

    // MARK: - Error Messages Tests

    func testAccessDeniedMessage() {
        let error = AppError.calendarAccessDenied
        let message = error.message

        XCTAssertTrue(message.contains("Grant calendar permissions"))
        XCTAssertTrue(message.contains("Settings"))
        XCTAssertTrue(message.contains("CalAI"))
    }

    func testLoadEventsMessageIncludesDetails() {
        let testError = NSError(
            domain: "TestDomain",
            code: 123,
            userInfo: [NSLocalizedDescriptionKey: "Network timeout"]
        )
        let error = AppError.failedToLoadEvents(testError)
        let message = error.message

        XCTAssertTrue(message.contains("Unable to load calendar events"))
        XCTAssertTrue(message.contains("Details:"))
        XCTAssertTrue(message.contains("Network timeout"))
    }

    func testSyncErrorIncludesSource() {
        let testError = NSError(
            domain: "TestDomain",
            code: 456,
            userInfo: [NSLocalizedDescriptionKey: "Auth failed"]
        )
        let error = AppError.failedToSyncCalendar(source: "Google", testError)
        let message = error.message

        XCTAssertTrue(message.contains("Google"))
        XCTAssertTrue(message.contains("Details:"))
        XCTAssertTrue(message.contains("Auth failed"))
    }

    func testNetworkErrorMessage() {
        let testError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )
        let error = AppError.networkError(testError)
        let message = error.message

        XCTAssertTrue(message.contains("No internet connection"))
        XCTAssertTrue(message.contains("Wi-Fi or cellular"))
    }

    // MARK: - Retryability Tests

    func testAccessDeniedIsNotRetryable() {
        let error = AppError.calendarAccessDenied
        XCTAssertFalse(error.isRetryable)
    }

    func testLoadEventsIsRetryable() {
        let error = AppError.failedToLoadEvents(NSError(domain: "test", code: 1))
        XCTAssertTrue(error.isRetryable)
    }

    func testSyncErrorIsRetryable() {
        let error = AppError.failedToSyncCalendar(source: "Google", NSError(domain: "test", code: 1))
        XCTAssertTrue(error.isRetryable)
    }

    func testNetworkErrorIsRetryable() {
        let error = AppError.networkError(NSError(domain: "test", code: 1))
        XCTAssertTrue(error.isRetryable)
    }

    func testUnknownErrorIsRetryable() {
        let error = AppError.unknownError(NSError(domain: "test", code: 1))
        XCTAssertTrue(error.isRetryable)
    }

    // MARK: - Equality Tests

    func testErrorEquality() {
        let error1 = AppError.calendarAccessDenied
        let error2 = AppError.calendarAccessDenied
        XCTAssertEqual(error1, error2)

        let error3 = AppError.failedToLoadEvents(NSError(domain: "test", code: 1))
        let error4 = AppError.failedToLoadEvents(NSError(domain: "test", code: 2))
        XCTAssertEqual(error3, error4) // Equality based on ID, not error details

        let error5 = AppError.failedToSyncCalendar(source: "Google", NSError(domain: "test", code: 1))
        let error6 = AppError.failedToSyncCalendar(source: "Outlook", NSError(domain: "test", code: 1))
        XCTAssertNotEqual(error5, error6) // Different sources = different IDs
    }

    // MARK: - Edge Cases

    func testEmptySourceInSyncError() {
        let error = AppError.failedToSyncCalendar(source: "", NSError(domain: "test", code: 1))
        XCTAssertEqual(error.id, "failedToSyncCalendar_")
        XCTAssertTrue(error.title.contains("Sync Failed"))
    }

    func testNilErrorDescriptions() {
        // Ensure errors with nil descriptions don't crash
        let error1 = AppError.failedToLoadEvents(NSError(domain: "test", code: 1))
        XCTAssertNotNil(error1.message)

        let error2 = AppError.networkError(NSError(domain: "test", code: 1))
        XCTAssertNotNil(error2.message)
    }
}
