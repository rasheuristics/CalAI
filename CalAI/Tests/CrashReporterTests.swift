import XCTest
@testable import CalAI

final class CrashReporterTests: XCTestCase {

    var crashReporter: CrashReporter!

    override func setUp() {
        super.setUp()
        crashReporter = CrashReporter.shared
        crashReporter.setEnabled(true)
    }

    override func tearDown() {
        crashReporter = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSharedInstance() {
        let instance1 = CrashReporter.shared
        let instance2 = CrashReporter.shared

        XCTAssertTrue(instance1 === instance2, "Should be singleton")
    }

    // MARK: - Enable/Disable Tests

    func testEnableDisableCrashReporting() {
        crashReporter.setEnabled(false)
        // Note: Can't directly test enabled state, but method should not crash
        XCTAssertNoThrow(crashReporter.setEnabled(false))

        crashReporter.setEnabled(true)
        XCTAssertNoThrow(crashReporter.setEnabled(true))
    }

    // MARK: - Error Logging Tests

    func testLogError() {
        let testError = NSError(
            domain: "TestDomain",
            code: 123,
            userInfo: [NSLocalizedDescriptionKey: "Test error description"]
        )

        XCTAssertNoThrow(crashReporter.logError(testError, context: "Test context"))
    }

    func testLogErrorWithoutContext() {
        let testError = NSError(domain: "TestDomain", code: 456)

        XCTAssertNoThrow(crashReporter.logError(testError))
    }

    // MARK: - Warning Logging Tests

    func testLogWarning() {
        XCTAssertNoThrow(crashReporter.logWarning("Test warning message"))
    }

    func testLogWarningWithEmptyMessage() {
        XCTAssertNoThrow(crashReporter.logWarning(""))
    }

    // MARK: - Fatal Error Tests (Note: Can't actually test fatal errors without crashing)

    func testLogFatalDoesNotCrashInTests() {
        // In test environment, logFatal should only log, not crash
        XCTAssertNoThrow(crashReporter.logFatal("Test fatal error"))
    }

    // MARK: - Breadcrumb Tests

    func testLeaveBreadcrumb() {
        XCTAssertNoThrow(crashReporter.leaveBreadcrumb("User opened settings"))
        XCTAssertNoThrow(crashReporter.leaveBreadcrumb("User connected Google Calendar"))
        XCTAssertNoThrow(crashReporter.leaveBreadcrumb("User created event"))
    }

    func testLeaveBreadcrumbWithEmptyMessage() {
        XCTAssertNoThrow(crashReporter.leaveBreadcrumb(""))
    }

    // MARK: - User Context Tests

    func testSetUserIdentifier() {
        XCTAssertNoThrow(crashReporter.setUserIdentifier("user123"))
        XCTAssertNoThrow(crashReporter.setUserIdentifier(""))
    }

    func testSetCustomValue() {
        XCTAssertNoThrow(crashReporter.setCustomValue("1.0.0", forKey: "app_version"))
        XCTAssertNoThrow(crashReporter.setCustomValue("dark", forKey: "theme"))
    }

    func testSetCustomValueWithEmptyKey() {
        XCTAssertNoThrow(crashReporter.setCustomValue("value", forKey: ""))
    }

    // MARK: - Convenience Method Tests

    func testLogAPIError() {
        let testError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        XCTAssertNoThrow(crashReporter.logAPIError(testError, endpoint: "/api/events"))
    }

    func testLogDatabaseError() {
        let testError = NSError(domain: "CoreDataDomain", code: 999)

        XCTAssertNoThrow(crashReporter.logDatabaseError(testError, operation: "fetch"))
    }

    func testLogSyncError() {
        let testError = NSError(domain: "SyncDomain", code: 500)

        XCTAssertNoThrow(crashReporter.logSyncError(testError, source: "Google"))
    }

    func testLogAIError() {
        let testError = NSError(domain: "AIDomain", code: 404)

        XCTAssertNoThrow(crashReporter.logAIError(testError, operation: "generateSuggestions"))
    }

    // MARK: - Global Function Tests

    func testGlobalLogError() {
        let testError = NSError(domain: "GlobalTest", code: 1)

        XCTAssertNoThrow(logError(testError))
        XCTAssertNoThrow(logError(testError, context: "Test context"))
    }

    func testGlobalLogWarning() {
        XCTAssertNoThrow(logWarning("Global warning test"))
    }

    func testGlobalLogFatal() {
        XCTAssertNoThrow(logFatal("Global fatal test"))
    }

    // MARK: - CrashSeverity Tests

    func testCrashSeverityEmojis() {
        XCTAssertEqual(CrashSeverity.critical.emoji, "🔴")
        XCTAssertEqual(CrashSeverity.error.emoji, "❌")
        XCTAssertEqual(CrashSeverity.warning.emoji, "⚠️")
        XCTAssertEqual(CrashSeverity.info.emoji, "ℹ️")
    }

    // MARK: - DeviceInfo Tests

    func testDeviceInfoCurrent() {
        let deviceInfo = DeviceInfo.current

        XCTAssertFalse(deviceInfo.model.isEmpty)
        XCTAssertFalse(deviceInfo.osVersion.isEmpty)
        XCTAssertFalse(deviceInfo.systemName.isEmpty)
    }

    // MARK: - Bundle Extension Tests

    func testBundleAppVersion() {
        let version = Bundle.main.appVersion

        XCTAssertNotEqual(version, "Unknown")
        XCTAssertFalse(version.isEmpty)
    }

    func testBundleBuildNumber() {
        let buildNumber = Bundle.main.buildNumber

        XCTAssertNotEqual(buildNumber, "Unknown")
        XCTAssertFalse(buildNumber.isEmpty)
    }

    // MARK: - AnalyticsEvent Tests

    func testAnalyticsEventCreation() {
        let event = AnalyticsEvent(
            name: "screen_view",
            parameters: ["screen_name": "settings", "user_type": "premium"]
        )

        XCTAssertEqual(event.name, "screen_view")
        XCTAssertEqual(event.parameters.count, 2)
        XCTAssertEqual(event.parameters["screen_name"] as? String, "settings")
    }

    func testRecordEvent() {
        let event = AnalyticsEvent(
            name: "button_tap",
            parameters: ["button_id": "sync_now"]
        )

        XCTAssertNoThrow(crashReporter.recordEvent(event))
    }

    // MARK: - CrashReport Structure Tests

    func testCrashReportCreation() {
        let report = CrashReport(
            message: "Test crash",
            severity: .error,
            timestamp: Date(),
            error: nil,
            deviceInfo: DeviceInfo.current,
            appVersion: "1.0.0",
            buildNumber: "1"
        )

        XCTAssertEqual(report.message, "Test crash")
        XCTAssertEqual(report.severity, .error)
        XCTAssertNil(report.error)
        XCTAssertEqual(report.appVersion, "1.0.0")
        XCTAssertEqual(report.buildNumber, "1")
    }

    // MARK: - Integration Tests

    func testFullErrorReportingFlow() {
        // 1. Set user context
        crashReporter.setUserIdentifier("test_user_123")
        crashReporter.setCustomValue("dark", forKey: "theme")
        crashReporter.setCustomValue("1.0.0", forKey: "version")

        // 2. Leave breadcrumbs
        crashReporter.leaveBreadcrumb("App launched")
        crashReporter.leaveBreadcrumb("User navigated to settings")
        crashReporter.leaveBreadcrumb("Error occurred")

        // 3. Log error
        let error = NSError(
            domain: "TestDomain",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Integration test error"]
        )
        crashReporter.logError(error, context: "Integration test")

        // Should not crash
        XCTAssertTrue(true, "Full flow completed without crash")
    }

    func testMultipleErrorsInSequence() {
        for i in 1...10 {
            let error = NSError(domain: "TestDomain", code: i)
            crashReporter.logError(error, context: "Error \(i)")
        }

        XCTAssertTrue(true, "Multiple errors logged without crash")
    }

    // MARK: - Thread Safety Tests (Basic)

    func testConcurrentLogging() {
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10

        for i in 1...10 {
            DispatchQueue.global().async {
                let error = NSError(domain: "ConcurrentTest", code: i)
                self.crashReporter.logError(error, context: "Thread \(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
