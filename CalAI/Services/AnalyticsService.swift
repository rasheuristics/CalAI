import Foundation
import UIKit
import os.log

/// Privacy-first analytics service with user opt-in
/// Tracks feature usage and app performance to improve user experience
/// All data is anonymized and user can opt-out at any time
class AnalyticsService {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.calai", category: "Analytics")
    private let userDefaults = UserDefaults.standard
    private let analyticsEnabledKey = "analyticsEnabled"

    // Anonymous user ID (generated once, persisted)
    private var anonymousUserID: String {
        let key = "anonymousUserID"
        if let existing = userDefaults.string(forKey: key) {
            return existing
        }
        let newID = UUID().uuidString
        userDefaults.set(newID, forKey: key)
        return newID
    }

    private init() {
        setupAnalytics()
    }

    // MARK: - Setup

    private func setupAnalytics() {
        logger.info("Analytics service initialized (enabled: \(self.isEnabled))")
    }

    // MARK: - Enable/Disable

    var isEnabled: Bool {
        get {
            // Default to false (opt-in, not opt-out)
            userDefaults.object(forKey: analyticsEnabledKey) as? Bool ?? false
        }
        set {
            userDefaults.set(newValue, forKey: analyticsEnabledKey)
            logger.info("Analytics \(newValue ? "enabled" : "disabled")")

            if newValue {
                trackEvent(.analyticsEnabled)
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Event Tracking

    func trackEvent(_ event: AnalyticsEvent) {
        guard isEnabled else {
            logger.debug("Analytics disabled, skipping event: \(event.name)")
            return
        }

        let enrichedEvent = enrichEvent(event)
        logEvent(enrichedEvent)

        // TODO: Send to analytics platform (Firebase, Mixpanel, etc.)
        // For now, just log locally
    }

    func trackScreen(_ screenName: String, parameters: [String: Any] = [:]) {
        var params = parameters
        params["screen_name"] = screenName
        trackEvent(.screenView(screenName: screenName, parameters: params))
    }

    func trackFeatureUsage(_ feature: String, parameters: [String: Any] = [:]) {
        var params = parameters
        params["feature"] = feature
        trackEvent(.featureUsed(feature: feature, parameters: params))
    }

    func trackError(_ error: Error, context: String? = nil) {
        var params: [String: Any] = [
            "error_description": error.localizedDescription
        ]
        if let context = context {
            params["context"] = context
        }
        trackEvent(.errorOccurred(error: error, context: context, parameters: params))
    }

    // MARK: - Event Enrichment

    private func enrichEvent(_ event: AnalyticsEvent) -> EnrichedAnalyticsEvent {
        return EnrichedAnalyticsEvent(
            name: event.name,
            parameters: event.parameters,
            timestamp: Date(),
            anonymousUserID: anonymousUserID,
            appVersion: Bundle.main.appVersion,
            buildNumber: Bundle.main.buildNumber,
            platform: "iOS",
            osVersion: UIDevice.current.systemVersion
        )
    }

    // MARK: - Local Logging

    private func logEvent(_ event: EnrichedAnalyticsEvent) {
        logger.info("📊 Analytics Event: \(event.name)")
        logger.debug("  User ID: \(event.anonymousUserID)")
        logger.debug("  Parameters: \(event.parameters)")
        logger.debug("  App Version: \(event.appVersion)")
        logger.debug("  Timestamp: \(event.timestamp.ISO8601Format())")

        // Save to local storage for debugging
        saveEventLocally(event)
    }

    private func saveEventLocally(_ event: EnrichedAnalyticsEvent) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsLogPath = documentsPath.appendingPathComponent("analytics_log.txt")

        let logEntry = """
        [\(event.timestamp.ISO8601Format())] \(event.name)
        User: \(event.anonymousUserID)
        Parameters: \(event.parameters)
        ---

        """

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: analyticsLogPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: analyticsLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: analyticsLogPath)
            }
        }
    }

    // MARK: - Data Export

    func exportAnalyticsData() -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsLogPath = documentsPath.appendingPathComponent("analytics_log.txt")

        return try? String(contentsOf: analyticsLogPath, encoding: .utf8)
    }

    func clearAnalyticsData() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsLogPath = documentsPath.appendingPathComponent("analytics_log.txt")

        try? FileManager.default.removeItem(at: analyticsLogPath)
        logger.info("Analytics data cleared")
    }
}

// MARK: - Analytics Event Types

enum AnalyticsEvent {
    // App Lifecycle
    case appLaunched
    case appBackgrounded
    case appTerminated

    // User Actions
    case screenView(screenName: String, parameters: [String: Any])
    case featureUsed(feature: String, parameters: [String: Any])
    case buttonTapped(buttonName: String, screenName: String)

    // Calendar Operations
    case calendarConnected(source: String)
    case calendarDisconnected(source: String)
    case eventCreated(source: String)
    case eventEdited(source: String)
    case eventDeleted(source: String)
    case eventViewed(source: String)

    // Notifications
    case notificationScheduled(type: String)
    case notificationDelivered(type: String)
    case notificationTapped(type: String)
    case notificationSettingsChanged

    // Voice Commands
    case voiceCommandUsed
    case voiceCommandSucceeded
    case voiceCommandFailed(reason: String)

    // Settings
    case settingChanged(setting: String, value: String)
    case themeChanged(theme: String)

    // Analytics
    case analyticsEnabled
    case analyticsDisabled

    // Errors
    case errorOccurred(error: Error, context: String?, parameters: [String: Any])

    // Performance
    case performanceMetric(metric: String, value: Double)

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .appBackgrounded: return "app_backgrounded"
        case .appTerminated: return "app_terminated"
        case .screenView: return "screen_view"
        case .featureUsed: return "feature_used"
        case .buttonTapped: return "button_tapped"
        case .calendarConnected: return "calendar_connected"
        case .calendarDisconnected: return "calendar_disconnected"
        case .eventCreated: return "event_created"
        case .eventEdited: return "event_edited"
        case .eventDeleted: return "event_deleted"
        case .eventViewed: return "event_viewed"
        case .notificationScheduled: return "notification_scheduled"
        case .notificationDelivered: return "notification_delivered"
        case .notificationTapped: return "notification_tapped"
        case .notificationSettingsChanged: return "notification_settings_changed"
        case .voiceCommandUsed: return "voice_command_used"
        case .voiceCommandSucceeded: return "voice_command_succeeded"
        case .voiceCommandFailed: return "voice_command_failed"
        case .settingChanged: return "setting_changed"
        case .themeChanged: return "theme_changed"
        case .analyticsEnabled: return "analytics_enabled"
        case .analyticsDisabled: return "analytics_disabled"
        case .errorOccurred: return "error_occurred"
        case .performanceMetric: return "performance_metric"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .screenView(let screenName, let parameters):
            var params = parameters
            params["screen_name"] = screenName
            return params

        case .featureUsed(let feature, let parameters):
            var params = parameters
            params["feature"] = feature
            return params

        case .buttonTapped(let buttonName, let screenName):
            return ["button_name": buttonName, "screen_name": screenName]

        case .calendarConnected(let source):
            return ["source": source]

        case .calendarDisconnected(let source):
            return ["source": source]

        case .eventCreated(let source):
            return ["source": source]

        case .eventEdited(let source):
            return ["source": source]

        case .eventDeleted(let source):
            return ["source": source]

        case .eventViewed(let source):
            return ["source": source]

        case .notificationScheduled(let type):
            return ["notification_type": type]

        case .notificationDelivered(let type):
            return ["notification_type": type]

        case .notificationTapped(let type):
            return ["notification_type": type]

        case .voiceCommandFailed(let reason):
            return ["failure_reason": reason]

        case .settingChanged(let setting, let value):
            return ["setting": setting, "value": value]

        case .themeChanged(let theme):
            return ["theme": theme]

        case .errorOccurred(let error, let context, let parameters):
            var params = parameters
            params["error_description"] = error.localizedDescription
            if let context = context {
                params["context"] = context
            }
            return params

        case .performanceMetric(let metric, let value):
            return ["metric": metric, "value": value]

        default:
            return [:]
        }
    }
}

// MARK: - Enriched Event

struct EnrichedAnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    let anonymousUserID: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
}

// MARK: - Global Convenience Functions

func trackEvent(_ event: AnalyticsEvent) {
    AnalyticsService.shared.trackEvent(event)
}

func trackScreen(_ screenName: String, parameters: [String: Any] = [:]) {
    AnalyticsService.shared.trackScreen(screenName, parameters: parameters)
}

func trackFeature(_ feature: String, parameters: [String: Any] = [:]) {
    AnalyticsService.shared.trackFeatureUsage(feature, parameters: parameters)
}
