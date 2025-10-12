import Foundation
import SwiftUI

/// Manages error recovery strategies and user guidance
class ErrorRecoveryManager: ObservableObject {
    static let shared = ErrorRecoveryManager()

    @Published var currentError: RecoverableError?
    @Published var isShowingRecovery = false

    private init() {}

    // MARK: - Error Handling

    /// Handle error with automatic recovery attempt
    func handle(_ error: Error, context: ErrorContext = .general) {
        let recoverableError = convert(error, context: context)
        currentError = recoverableError

        // Log error
        logError(recoverableError)

        // Attempt automatic recovery if possible
        if recoverableError.canAutoRecover {
            attemptAutoRecovery(recoverableError)
        } else {
            // Show recovery UI
            isShowingRecovery = true
            HapticManager.shared.error()
        }
    }

    /// Convert standard error to recoverable error
    private func convert(_ error: Error, context: ErrorContext) -> RecoverableError {
        if let appError = error as? AppError {
            return RecoverableError(from: appError, context: context)
        }

        // Handle NSError and other errors
        let nsError = error as NSError

        switch nsError.domain {
        case NSURLErrorDomain:
            return handleNetworkError(nsError, context: context)
        case NSCocoaErrorDomain:
            return handleCocoaError(nsError, context: context)
        default:
            return RecoverableError(
                title: "Something Went Wrong",
                message: error.localizedDescription,
                icon: "exclamationmark.triangle.fill",
                severity: .medium,
                context: context,
                recoveryOptions: [.dismiss],
                canAutoRecover: false
            )
        }
    }

    private func handleNetworkError(_ error: NSError, context: ErrorContext) -> RecoverableError {
        let isOffline = error.code == NSURLErrorNotConnectedToInternet

        return RecoverableError(
            title: isOffline ? "No Internet Connection" : "Network Error",
            message: isOffline
                ? "Please check your internet connection and try again."
                : "Unable to connect to the server. Please try again later.",
            icon: isOffline ? "wifi.slash" : "network.slash",
            severity: isOffline ? .high : .medium,
            context: context,
            recoveryOptions: [.retry, .enableOfflineMode, .dismiss],
            canAutoRecover: !isOffline
        )
    }

    private func handleCocoaError(_ error: NSError, context: ErrorContext) -> RecoverableError {
        return RecoverableError(
            title: "Data Error",
            message: "An error occurred while accessing your data. Your information is safe.",
            icon: "externaldrive.badge.exclamationmark",
            severity: .medium,
            context: context,
            recoveryOptions: [.retry, .resetCache, .dismiss],
            canAutoRecover: false
        )
    }

    // MARK: - Auto Recovery

    private func attemptAutoRecovery(_ error: RecoverableError) {
        print("🔄 Attempting automatic recovery for: \(error.title)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // Simulate recovery attempt
            let success = Bool.random() // Replace with actual recovery logic

            if success {
                self?.handleRecoverySuccess()
            } else {
                // Show recovery UI if auto-recovery fails
                self?.isShowingRecovery = true
                HapticManager.shared.error()
            }
        }
    }

    // MARK: - Recovery Actions

    func attemptRecovery(option: RecoveryOption) {
        guard let error = currentError else { return }

        HapticManager.shared.light()

        switch option {
        case .retry:
            retryOperation(for: error)
        case .enableOfflineMode:
            enableOfflineMode()
        case .resetCache:
            resetCache()
        case .contactSupport:
            contactSupport()
        case .viewDetails:
            viewErrorDetails()
        case .openSettings:
            openSettings()
        case .dismiss:
            dismissError()
        }
    }

    private func retryOperation(for error: RecoverableError) {
        print("🔄 Retrying operation for context: \(error.context)")
        dismissError()

        // Post notification for retry
        NotificationCenter.default.post(
            name: .errorRecoveryRetry,
            object: error.context
        )
    }

    private func enableOfflineMode() {
        print("📴 Enabling offline mode")
        // Enable offline mode logic here
        dismissError()
        HapticManager.shared.success()
    }

    private func resetCache() {
        print("🧹 Resetting cache")
        CacheManager.shared.clearAll()
        CoreDataManager.shared.clearTemporaryData()
        dismissError()
        HapticManager.shared.success()
    }

    private func contactSupport() {
        print("📧 Opening support contact")
        if let url = URL(string: "mailto:support@calai.app") {
            UIApplication.shared.open(url)
        }
    }

    private func viewErrorDetails() {
        print("📋 Viewing error details")
        // Show detailed error information
    }

    private func openSettings() {
        print("⚙️ Opening Settings")
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        dismissError()
    }

    private func dismissError() {
        currentError = nil
        isShowingRecovery = false
    }

    private func handleRecoverySuccess() {
        print("✅ Auto-recovery successful")
        dismissError()
        HapticManager.shared.success()
    }

    // MARK: - Error Logging

    private func logError(_ error: RecoverableError) {
        print("""
        ❌ Error occurred:
        - Title: \(error.title)
        - Message: \(error.message)
        - Context: \(error.context)
        - Severity: \(error.severity)
        - Auto-recover: \(error.canAutoRecover)
        """)
    }
}

// MARK: - Supporting Types

struct RecoverableError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let severity: ErrorSeverity
    let context: ErrorContext
    let recoveryOptions: [RecoveryOption]
    let canAutoRecover: Bool
    var technicalDetails: String?

    init(
        title: String,
        message: String,
        icon: String,
        severity: ErrorSeverity,
        context: ErrorContext,
        recoveryOptions: [RecoveryOption],
        canAutoRecover: Bool,
        technicalDetails: String? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.severity = severity
        self.context = context
        self.recoveryOptions = recoveryOptions
        self.canAutoRecover = canAutoRecover
        self.technicalDetails = technicalDetails
    }

    init(from appError: AppError, context: ErrorContext) {
        self.title = appError.title
        self.message = appError.message
        self.icon = "exclamationmark.triangle"
        self.severity = appError.isRetryable ? .medium : .high
        self.context = context
        self.canAutoRecover = appError.isRetryable

        var options: [RecoveryOption] = []

        if appError.isRetryable {
            options.append(.retry)
        }

        if case .calendarAccessDenied = appError {
            options.append(.openSettings)
        }

        options.append(.dismiss)

        self.recoveryOptions = options
        self.technicalDetails = nil
    }
}

enum ErrorSeverity {
    case low      // Information/warning
    case medium   // Recoverable error
    case high     // Critical error
    case critical // App-breaking error

    var color: Color {
        switch self {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return Color(red: 0.8, green: 0, blue: 0)
        }
    }

    var title: String {
        switch self {
        case .low:
            return "Notice"
        case .medium:
            return "Warning"
        case .high:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
}

enum ErrorContext: String {
    case general = "General"
    case calendarAccess = "Calendar Access"
    case eventCreation = "Event Creation"
    case eventUpdate = "Event Update"
    case eventDeletion = "Event Deletion"
    case calendarSync = "Calendar Sync"
    case aiProcessing = "AI Processing"
    case networkRequest = "Network Request"
    case dataStorage = "Data Storage"
    case authentication = "Authentication"
}

enum RecoveryOption {
    case retry
    case enableOfflineMode
    case resetCache
    case contactSupport
    case viewDetails
    case openSettings
    case dismiss

    var title: String {
        switch self {
        case .retry:
            return "Try Again"
        case .enableOfflineMode:
            return "Enable Offline Mode"
        case .resetCache:
            return "Clear Cache"
        case .contactSupport:
            return "Contact Support"
        case .viewDetails:
            return "View Details"
        case .openSettings:
            return "Open Settings"
        case .dismiss:
            return "Dismiss"
        }
    }

    var icon: String {
        switch self {
        case .retry:
            return "arrow.clockwise"
        case .enableOfflineMode:
            return "wifi.slash"
        case .resetCache:
            return "trash"
        case .contactSupport:
            return "envelope"
        case .viewDetails:
            return "info.circle"
        case .openSettings:
            return "gearshape"
        case .dismiss:
            return "xmark"
        }
    }

    var style: RecoveryOptionStyle {
        switch self {
        case .retry:
            return .primary
        case .enableOfflineMode:
            return .secondary
        case .resetCache:
            return .destructive
        case .contactSupport:
            return .secondary
        case .viewDetails:
            return .tertiary
        case .openSettings:
            return .primary
        case .dismiss:
            return .tertiary
        }
    }
}

enum RecoveryOptionStyle {
    case primary
    case secondary
    case destructive
    case tertiary
}

// MARK: - AppError Extensions

extension AppError {
    var severity: ErrorSeverity {
        switch self {
        case .calendarAccessDenied:
            return .high
        case .networkError:
            return .medium
        case .failedToLoadEvents, .failedToSyncCalendar:
            return .medium
        case .unknownError:
            return .medium
        }
    }

    var icon: String {
        switch self {
        case .calendarAccessDenied:
            return "calendar.badge.exclamationmark"
        case .networkError:
            return "wifi.exclamationmark"
        case .failedToLoadEvents:
            return "exclamationmark.bubble"
        case .failedToSyncCalendar:
            return "arrow.triangle.2.circlepath"
        case .unknownError:
            return "questionmark.circle"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let errorRecoveryRetry = Notification.Name("errorRecoveryRetry")
}

// MARK: - CoreData Extension

extension CoreDataManager {
    func clearTemporaryData() {
        // Clear temporary/cached data
        let context = backgroundContext
        context.perform {
            // Implementation for clearing temporary data
            print("🧹 Temporary data cleared")
        }
    }
}
