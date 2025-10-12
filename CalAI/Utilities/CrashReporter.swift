import Foundation
import UIKit
import os.log

/// Crash reporting and error tracking service
/// Currently uses local logging - ready for Firebase Crashlytics integration
class CrashReporter {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.calai", category: "CrashReporter")
    private var isEnabled = true

    private init() {
        setupCrashReporting()
    }

    // MARK: - Setup

    private func setupCrashReporting() {
        // Setup NSSetUncaughtExceptionHandler for catching exceptions
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.logException(exception)
        }

        logger.info("✅ Crash reporting initialized")
    }

    // MARK: - Crash Logging

    /// Log a fatal error (will crash the app in debug, log in production)
    func logFatal(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "🔴 FATAL: \(message) at \(fileName):\(line) in \(function)"

        logger.critical("\(logMessage)")

        // In production, you would send to Firebase here
        #if DEBUG
        assertionFailure(logMessage)
        #else
        // Log to crash reporting service
        logCrash(message: logMessage, severity: .critical)
        #endif
    }

    /// Log a non-fatal error
    func logError(_ error: Error, context: String? = nil, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let contextInfo = context.map { " | Context: \($0)" } ?? ""
        let logMessage = "❌ ERROR: \(error.localizedDescription)\(contextInfo) at \(fileName):\(line)"

        logger.error("\(logMessage)")

        // Send to crash reporting service
        logCrash(message: logMessage, severity: .error, error: error)
    }

    /// Log an exception
    func logException(_ exception: NSException) {
        let logMessage = """
        ⚠️ EXCEPTION: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        Stack trace: \(exception.callStackSymbols.joined(separator: "\n"))
        """

        logger.fault("\(logMessage)")
        logCrash(message: logMessage, severity: .critical)
    }

    /// Log a warning
    func logWarning(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "⚠️ WARNING: \(message) at \(fileName):\(line)"

        logger.warning("\(logMessage)")
        logCrash(message: logMessage, severity: .warning)
    }

    // MARK: - User Context

    /// Set user identifier for crash reports
    func setUserIdentifier(_ userId: String) {
        logger.info("👤 User identifier set: \(userId)")
        // Firebase: Crashlytics.crashlytics().setUserID(userId)
    }

    /// Set custom key-value for debugging
    func setCustomValue(_ value: String, forKey key: String) {
        logger.debug("🔧 Custom value set: \(key) = \(value)")
        // Firebase: Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Log breadcrumb for debugging crash context
    func leaveBreadcrumb(_ message: String) {
        logger.debug("🍞 Breadcrumb: \(message)")
        // Firebase: Crashlytics.crashlytics().log(message)
    }

    // MARK: - Analytics Events

    /// Record a custom event for analytics
    func recordEvent(_ event: CrashAnalyticsEvent) {
        logger.info("📊 Event: \(event.name) | Parameters: \(event.parameters)")
        // Firebase: Analytics.logEvent(event.name, parameters: event.parameters)
    }

    // MARK: - Crash Reporting Backend

    private func logCrash(message: String, severity: CrashSeverity, error: Error? = nil) {
        let crashReport = CrashReport(
            message: message,
            severity: severity,
            timestamp: Date(),
            error: error,
            deviceInfo: DeviceInfo.current,
            appVersion: Bundle.main.appVersion,
            buildNumber: Bundle.main.buildNumber
        )

        // Save locally for debugging
        saveCrashReport(crashReport)

        // TODO: Send to Firebase Crashlytics
        // Crashlytics.crashlytics().record(error: NSError(...))
    }

    private func saveCrashReport(_ report: CrashReport) {
        // Save to local file for debugging
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashLogPath = documentsPath.appendingPathComponent("crash_logs.txt")

        let logEntry = """
        [\(report.timestamp.ISO8601Format())] \(report.severity.emoji) \(report.message)
        Device: \(report.deviceInfo.model) | iOS \(report.deviceInfo.osVersion)
        App: \(report.appVersion) (\(report.buildNumber))
        ---

        """

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: crashLogPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: crashLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: crashLogPath)
            }
        }
    }

    // MARK: - Enable/Disable

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logger.info("Crash reporting \(enabled ? "enabled" : "disabled")")
        // Firebase: Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }

    // MARK: - Test Crash

    #if DEBUG
    func testCrash() {
        logger.warning("⚠️ Test crash triggered")
        fatalError("Test crash - this is intentional for testing crash reporting")
    }

    func testNonFatalError() {
        logger.warning("⚠️ Test non-fatal error triggered")
        let error = NSError(domain: "TestError", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "This is a test non-fatal error"
        ])
        logError(error, context: "Testing crash reporting")
    }
    #endif
}

// MARK: - Supporting Types

enum CrashSeverity {
    case critical
    case error
    case warning
    case info

    var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .error: return "❌"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        }
    }
}

struct CrashReport {
    let message: String
    let severity: CrashSeverity
    let timestamp: Date
    let error: Error?
    let deviceInfo: DeviceInfo
    let appVersion: String
    let buildNumber: String
}

struct DeviceInfo {
    let model: String
    let osVersion: String
    let systemName: String

    static var current: DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            model: device.model,
            osVersion: device.systemVersion,
            systemName: device.systemName
        )
    }
}

struct CrashAnalyticsEvent {
    let name: String
    let parameters: [String: Any]
}

// MARK: - Convenience Methods

extension CrashReporter {
    /// Log API error
    func logAPIError(_ error: Error, endpoint: String) {
        logError(error, context: "API: \(endpoint)")
    }

    /// Log database error
    func logDatabaseError(_ error: Error, operation: String) {
        logError(error, context: "Database: \(operation)")
    }

    /// Log sync error
    func logSyncError(_ error: Error, source: String) {
        logError(error, context: "Sync: \(source)")
    }

    /// Log AI error
    func logAIError(_ error: Error, operation: String) {
        logError(error, context: "AI: \(operation)")
    }
}

// MARK: - Bundle Extension

public extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Global Error Handler

/// Convenience function for quick error logging
func logError(_ error: Error, context: String? = nil, file: String = #file, line: Int = #line) {
    CrashReporter.shared.logError(error, context: context, file: file, line: line)
}

/// Convenience function for quick warning logging
func logWarning(_ message: String, file: String = #file, line: Int = #line) {
    CrashReporter.shared.logWarning(message, file: file, line: line)
}

/// Convenience function for fatal errors
func logFatal(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    CrashReporter.shared.logFatal(message, file: file, line: line, function: function)
}
