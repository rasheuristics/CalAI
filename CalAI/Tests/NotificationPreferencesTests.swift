import XCTest
@testable import CalAI

final class NotificationPreferencesTests: XCTestCase {

    // MARK: - Default Values Tests

    func testDefaultPreferences() {
        let prefs = NotificationPreferences()

        XCTAssertTrue(prefs.enabled)
        XCTAssertTrue(prefs.universalReminderEnabled)
        XCTAssertTrue(prefs.travelTimeAlertEnabled)
        XCTAssertTrue(prefs.virtualJoinAlertEnabled)
        XCTAssertEqual(prefs.universalReminderLeadTime, 15)
        XCTAssertEqual(prefs.virtualJoinLeadTime, 5)
        XCTAssertEqual(prefs.travelBufferMinutes, 10)
        XCTAssertEqual(prefs.travelThresholdMinutes, 5)
        XCTAssertTrue(prefs.hapticFeedbackEnabled)
        XCTAssertTrue(prefs.timeSensitiveEnabled)
    }

    // MARK: - UserDefaults Persistence Tests

    func testSaveToUserDefaults() {
        let prefs = NotificationPreferences()
        prefs.enabled = false
        prefs.universalReminderLeadTime = 30
        prefs.travelBufferMinutes = 20

        prefs.save()

        // Create new instance to verify persistence
        let loaded = NotificationPreferences()

        XCTAssertEqual(loaded.enabled, false)
        XCTAssertEqual(loaded.universalReminderLeadTime, 30)
        XCTAssertEqual(loaded.travelBufferMinutes, 20)
    }

    func testLoadFromUserDefaults() {
        // Set up UserDefaults
        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
        UserDefaults.standard.set(45, forKey: "universalReminderLeadTime")
        UserDefaults.standard.set(false, forKey: "hapticFeedbackEnabled")

        let prefs = NotificationPreferences()

        XCTAssertEqual(prefs.enabled, false)
        XCTAssertEqual(prefs.universalReminderLeadTime, 45)
        XCTAssertEqual(prefs.hapticFeedbackEnabled, false)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "notificationsEnabled")
        UserDefaults.standard.removeObject(forKey: "universalReminderLeadTime")
        UserDefaults.standard.removeObject(forKey: "hapticFeedbackEnabled")
    }

    // MARK: - Validation Tests

    func testLeadTimeValidation() {
        let prefs = NotificationPreferences()

        // Test valid values
        prefs.universalReminderLeadTime = 5
        XCTAssertEqual(prefs.universalReminderLeadTime, 5)

        prefs.universalReminderLeadTime = 60
        XCTAssertEqual(prefs.universalReminderLeadTime, 60)

        prefs.virtualJoinLeadTime = 1
        XCTAssertEqual(prefs.virtualJoinLeadTime, 1)

        prefs.virtualJoinLeadTime = 15
        XCTAssertEqual(prefs.virtualJoinLeadTime, 15)
    }

    func testBufferTimeValidation() {
        let prefs = NotificationPreferences()

        // Test valid values
        prefs.travelBufferMinutes = 0
        XCTAssertEqual(prefs.travelBufferMinutes, 0)

        prefs.travelBufferMinutes = 30
        XCTAssertEqual(prefs.travelBufferMinutes, 30)

        prefs.travelThresholdMinutes = 1
        XCTAssertEqual(prefs.travelThresholdMinutes, 1)

        prefs.travelThresholdMinutes = 60
        XCTAssertEqual(prefs.travelThresholdMinutes, 60)
    }

    // MARK: - Toggle Tests

    func testTogglingEnabled() {
        let prefs = NotificationPreferences()

        prefs.enabled = false
        XCTAssertFalse(prefs.enabled)

        prefs.enabled = true
        XCTAssertTrue(prefs.enabled)
    }

    func testTogglingIndividualNotificationTypes() {
        let prefs = NotificationPreferences()

        prefs.universalReminderEnabled = false
        prefs.travelTimeAlertEnabled = false
        prefs.virtualJoinAlertEnabled = false

        XCTAssertFalse(prefs.universalReminderEnabled)
        XCTAssertFalse(prefs.travelTimeAlertEnabled)
        XCTAssertFalse(prefs.virtualJoinAlertEnabled)
    }

    // MARK: - Codable Tests

    func testEncodingAndDecoding() throws {
        let prefs = NotificationPreferences()
        prefs.enabled = false
        prefs.universalReminderLeadTime = 25
        prefs.travelBufferMinutes = 15

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NotificationPreferences.self, from: data)

        XCTAssertEqual(decoded.enabled, prefs.enabled)
        XCTAssertEqual(decoded.universalReminderLeadTime, prefs.universalReminderLeadTime)
        XCTAssertEqual(decoded.travelBufferMinutes, prefs.travelBufferMinutes)
    }

    // MARK: - Edge Cases

    func testPersistenceAfterMultipleSaves() {
        let prefs = NotificationPreferences()

        prefs.enabled = false
        prefs.save()

        prefs.enabled = true
        prefs.save()

        let loaded = NotificationPreferences()
        XCTAssertTrue(loaded.enabled)
    }

    func testDefaultsNotOverwrittenByLoad() {
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "notificationsEnabled")

        let prefs = NotificationPreferences()

        // Should use default value (true) not nil
        XCTAssertTrue(prefs.enabled)
    }

    // MARK: - Cleanup

    override func tearDown() {
        // Clean up UserDefaults after each test
        let keys = [
            "notificationsEnabled",
            "universalReminderEnabled",
            "travelTimeAlertEnabled",
            "virtualJoinAlertEnabled",
            "universalReminderLeadTime",
            "virtualJoinLeadTime",
            "travelBufferMinutes",
            "travelThresholdMinutes",
            "hapticFeedbackEnabled",
            "timeSensitiveEnabled"
        ]

        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        super.tearDown()
    }
}
