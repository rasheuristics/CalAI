import Foundation

/// User-facing error types with localized messages
enum AppError: Identifiable, Equatable {
    case calendarAccessDenied
    case failedToLoadEvents(Error)
    case failedToSyncCalendar(source: String, Error)
    case networkError(Error)
    case unknownError(Error)

    var id: String {
        switch self {
        case .calendarAccessDenied:
            return "calendarAccessDenied"
        case .failedToLoadEvents:
            return "failedToLoadEvents"
        case .failedToSyncCalendar(let source, _):
            return "failedToSyncCalendar_\(source)"
        case .networkError:
            return "networkError"
        case .unknownError:
            return "unknownError"
        }
    }

    var title: String {
        switch self {
        case .calendarAccessDenied:
            return "Calendar Access Denied"
        case .failedToLoadEvents:
            return "Failed to Load Events"
        case .failedToSyncCalendar(let source, _):
            return "\(source) Sync Failed"
        case .networkError:
            return "Network Error"
        case .unknownError:
            return "Something Went Wrong"
        }
    }

    var message: String {
        switch self {
        case .calendarAccessDenied:
            return "Grant calendar permissions in Settings → Heu Calendar AI → Calendars to view your events."
        case .failedToLoadEvents(let error):
            let description = error.localizedDescription
            return "Unable to load calendar events. Try refreshing or check your calendar permissions.\n\nDetails: \(description)"
        case .failedToSyncCalendar(let source, let error):
            let description = error.localizedDescription
            return "Can't sync with \(source). Check your account connection in Settings.\n\nDetails: \(description)"
        case .networkError(let error):
            let description = error.localizedDescription
            return "No internet connection. Connect to Wi-Fi or cellular data and try again.\n\nDetails: \(description)"
        case .unknownError(let error):
            let description = error.localizedDescription
            return "Something unexpected happened. Try restarting the app.\n\nDetails: \(description)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .calendarAccessDenied:
            return false
        case .failedToLoadEvents, .failedToSyncCalendar, .networkError, .unknownError:
            return true
        }
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}
