import Foundation
import CoreLocation
import UserNotifications

// MARK: - Smart Notification Models

/// Represents an intelligent notification with context awareness
struct SmartNotification: Identifiable {
    let id: UUID
    let eventId: String
    let eventTitle: String
    let eventStartDate: Date
    let eventLocation: String?
    let notificationType: NotificationType
    let scheduledDate: Date
    let context: NotificationContext
    var isDelivered: Bool = false
    var isActedUpon: Bool = false

    init(eventId: String, eventTitle: String, eventStartDate: Date, eventLocation: String?, type: NotificationType, scheduledDate: Date, context: NotificationContext) {
        self.id = UUID()
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.eventStartDate = eventStartDate
        self.eventLocation = eventLocation
        self.notificationType = type
        self.scheduledDate = scheduledDate
        self.context = context
    }
}

/// Types of smart notifications
enum NotificationType: String, Codable {
    case standard = "Standard Reminder"
    case departureAlert = "Time to Leave"
    case trafficWarning = "Traffic Alert"
    case weatherAlert = "Weather Advisory"
    case meetingPrep = "Meeting Preparation"
    case locationReminder = "Location-Based Reminder"

    var icon: String {
        switch self {
        case .standard:
            return "bell.fill"
        case .departureAlert:
            return "car.fill"
        case .trafficWarning:
            return "exclamationmark.triangle.fill"
        case .weatherAlert:
            return "cloud.rain.fill"
        case .meetingPrep:
            return "doc.text.fill"
        case .locationReminder:
            return "location.fill"
        }
    }

    var priority: Int {
        switch self {
        case .trafficWarning: return 5
        case .departureAlert: return 4
        case .weatherAlert: return 3
        case .meetingPrep: return 2
        case .locationReminder: return 2
        case .standard: return 1
        }
    }
}

/// Context information for intelligent notifications
struct NotificationContext: Codable {
    var currentLocation: LocationInfo?
    var eventLocation: LocationInfo?
    var travelTime: TimeInterval?
    var trafficCondition: TrafficCondition?
    var weatherCondition: WeatherCondition?
    var meetingPrepInfo: MeetingPrepInfo?

    struct LocationInfo: Codable {
        let latitude: Double
        let longitude: Double
        let address: String?

        init(coordinate: CLLocationCoordinate2D, address: String? = nil) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
            self.address = address
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    struct TrafficCondition: Codable {
        let severity: TrafficSeverity
        let expectedDelay: TimeInterval
        let suggestedDepartureTime: Date?
        let route: String?

        enum TrafficSeverity: String, Codable {
            case clear = "Clear"
            case light = "Light"
            case moderate = "Moderate"
            case heavy = "Heavy"
            case severe = "Severe"

            var color: String {
                switch self {
                case .clear: return "green"
                case .light: return "yellow"
                case .moderate: return "orange"
                case .heavy: return "red"
                case .severe: return "purple"
                }
            }
        }
    }

    struct WeatherCondition: Codable {
        let condition: String // e.g., "Rain", "Snow", "Clear"
        let temperature: Double // in Celsius
        let precipitation: Double // probability 0-100
        let advisory: String?

        var shouldAlert: Bool {
            // Alert for rain, snow, extreme temps
            return precipitation > 50 || temperature < 0 || temperature > 35 || condition.lowercased().contains("storm")
        }

        var icon: String {
            let lowercased = condition.lowercased()
            if lowercased.contains("rain") {
                return "cloud.rain.fill"
            } else if lowercased.contains("snow") {
                return "snow"
            } else if lowercased.contains("cloud") {
                return "cloud.fill"
            } else if lowercased.contains("sun") || lowercased.contains("clear") {
                return "sun.max.fill"
            } else {
                return "cloud.sun.fill"
            }
        }
    }

    struct MeetingPrepInfo: Codable {
        let participants: [String]
        let hasAgenda: Bool
        let hasDocuments: Bool
        let suggestedPrepTime: TimeInterval // minutes before meeting
        let prepItems: [String]
    }
}

/// User preferences for smart notifications
struct SmartNotificationPreferences: Codable {
    var isEnabled: Bool = true
    var enableLocationAwareness: Bool = true
    var enableTrafficAlerts: Bool = true
    var enableWeatherAlerts: Bool = true
    var enableMeetingPrep: Bool = true

    // Timing preferences
    var standardReminderMinutes: Int = 15
    var meetingPrepMinutes: Int = 30
    var departureBufferMinutes: Int = 10 // Extra time before suggested departure

    // Threshold preferences
    var minimumTrafficDelayMinutes: Int = 10 // Only alert if delay > this
    var weatherAlertPrecipitationThreshold: Double = 60 // Alert if > 60% chance

    // Notification settings
    var soundEnabled: Bool = true
    var criticalAlertsEnabled: Bool = false

    static let userDefaultsKey = "SmartNotificationPreferences"

    static func load() -> SmartNotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let prefs = try? JSONDecoder().decode(SmartNotificationPreferences.self, from: data) else {
            return SmartNotificationPreferences()
        }
        return prefs
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

/// Notification delivery result
enum NotificationDeliveryResult {
    case scheduled(identifier: String)
    case delivered
    case failed(Error)
    case permissionDenied

    var isSuccess: Bool {
        switch self {
        case .scheduled, .delivered:
            return true
        case .failed, .permissionDenied:
            return false
        }
    }
}

/// Error types for smart notifications
enum SmartNotificationError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable
    case networkError
    case invalidEvent
    case schedulingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permissions are required for smart alerts"
        case .locationUnavailable:
            return "Location services are unavailable"
        case .networkError:
            return "Unable to fetch traffic or weather data"
        case .invalidEvent:
            return "Event information is incomplete"
        case .schedulingFailed:
            return "Failed to schedule notification"
        }
    }
}
