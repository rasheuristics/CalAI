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
            return "Please grant calendar access in Settings to view your events."
        case .failedToLoadEvents(let error):
            return "Unable to load your calendar events. \(error.localizedDescription)"
        case .failedToSyncCalendar(let source, let error):
            return "Unable to sync with \(source) Calendar. \(error.localizedDescription)"
        case .networkError(let error):
            return "Network connection issue. Please check your internet connection. \(error.localizedDescription)"
        case .unknownError(let error):
            return "An unexpected error occurred. \(error.localizedDescription)"
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
