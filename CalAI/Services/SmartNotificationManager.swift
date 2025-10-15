import Foundation
import UserNotifications
import CoreLocation
import MapKit

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
        case .standard: return "bell.fill"
        case .departureAlert: return "car.fill"
        case .trafficWarning: return "exclamationmark.triangle.fill"
        case .weatherAlert: return "cloud.rain.fill"
        case .meetingPrep: return "doc.text.fill"
        case .locationReminder: return "location.fill"
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
        let condition: String
        let temperature: Double
        let precipitation: Double
        let advisory: String?

        var shouldAlert: Bool {
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
        let suggestedPrepTime: TimeInterval
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

    var standardReminderMinutes: Int = 15
    var meetingPrepMinutes: Int = 30
    var departureBufferMinutes: Int = 10

    var minimumTrafficDelayMinutes: Int = 10
    var weatherAlertPrecipitationThreshold: Double = 60

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

// MARK: - Smart Notification Manager

/// Manages intelligent, context-aware notifications for calendar events
class SmartNotificationManager: NSObject, ObservableObject {
    static let shared = SmartNotificationManager()

    @Published var preferences = SmartNotificationPreferences.load()
    @Published var scheduledNotifications: [SmartNotification] = []
    @Published var hasNotificationPermission = false
    @Published var isAuthorized = false

    private let notificationCenter = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    override private init() {
        super.init()
        locationManager.delegate = self
        checkNotificationPermission()
        requestLocationPermission()
    }

    // MARK: - Permission Management

    func checkNotificationPermission() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let authorized = settings.authorizationStatus == .authorized
                self?.hasNotificationPermission = authorized
                self?.isAuthorized = authorized
            }
        }
    }

    /// Alias for checkNotificationPermission for compatibility
    func checkAuthorization() {
        checkNotificationPermission()
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasNotificationPermission = granted
                self?.isAuthorized = granted
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }

    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Smart Notification Scheduling

    /// Schedule smart notifications for an event
    func scheduleSmartNotifications(for event: UnifiedEvent) {
        guard preferences.isEnabled, hasNotificationPermission else {
            print("⚠️ Smart notifications disabled or no permission")
            return
        }

        print("📅 Scheduling smart notifications for: \(event.title)")

        // Schedule different types of notifications based on event characteristics
        var notifications: [SmartNotification] = []

        // 1. Standard reminder
        if let standardNotif = createStandardReminder(for: event) {
            notifications.append(standardNotif)
        }

        // 2. Meeting prep reminder (if enabled and event has location/participants)
        if preferences.enableMeetingPrep, !event.isAllDay {
            if let prepNotif = createMeetingPrepReminder(for: event) {
                notifications.append(prepNotif)
            }
        }

        // 3. Location/traffic-aware departure alert
        if preferences.enableTrafficAlerts, let location = event.location, !location.isEmpty, !event.isAllDay {
            Task {
                if let departureNotif = await createDepartureAlert(for: event, location: location) {
                    await MainActor.run {
                        notifications.append(departureNotif)
                    }
                }
            }
        }

        // 4. Weather alert (if outdoor event or has location)
        if preferences.enableWeatherAlerts, let location = event.location, !location.isEmpty {
            Task {
                if let weatherNotif = await createWeatherAlert(for: event, location: location) {
                    await MainActor.run {
                        notifications.append(weatherNotif)
                    }
                }
            }
        }

        // Deliver notifications
        for notification in notifications {
            deliverNotification(notification)
        }

        scheduledNotifications.append(contentsOf: notifications)
    }

    // MARK: - Notification Creators

    private func createStandardReminder(for event: UnifiedEvent) -> SmartNotification? {
        let reminderTime = event.startDate.addingTimeInterval(-Double(preferences.standardReminderMinutes * 60))

        guard reminderTime > Date() else {
            print("⏰ Event starts too soon for standard reminder")
            return nil
        }

        let context = NotificationContext()

        return SmartNotification(
            eventId: event.id,
            eventTitle: event.title,
            eventStartDate: event.startDate,
            eventLocation: event.location,
            type: .standard,
            scheduledDate: reminderTime,
            context: context
        )
    }

    private func createMeetingPrepReminder(for event: UnifiedEvent) -> SmartNotification? {
        let prepTime = event.startDate.addingTimeInterval(-Double(preferences.meetingPrepMinutes * 60))

        guard prepTime > Date() else {
            print("⏰ Event starts too soon for prep reminder")
            return nil
        }

        // Create meeting prep info
        let prepInfo = NotificationContext.MeetingPrepInfo(
            participants: [], // Would be populated from event attendees
            hasAgenda: false,
            hasDocuments: false,
            suggestedPrepTime: Double(preferences.meetingPrepMinutes * 60),
            prepItems: generatePrepItems(for: event)
        )

        var context = NotificationContext()
        context.meetingPrepInfo = prepInfo

        return SmartNotification(
            eventId: event.id,
            eventTitle: event.title,
            eventStartDate: event.startDate,
            eventLocation: event.location,
            type: .meetingPrep,
            scheduledDate: prepTime,
            context: context
        )
    }

    private func createDepartureAlert(for event: UnifiedEvent, location: String) async -> SmartNotification? {
        guard let currentLoc = currentLocation else {
            print("📍 Current location unavailable")
            return nil
        }

        // Geocode event location
        guard let eventCoordinate = await geocodeLocation(location) else {
            print("📍 Unable to geocode event location: \(location)")
            return nil
        }

        // Calculate travel time with traffic
        let travelInfo = await calculateTravelTime(
            from: currentLoc.coordinate,
            to: eventCoordinate
        )

        // Add buffer time
        let bufferTime = Double(preferences.departureBufferMinutes) * 60.0
        let totalTravelTime = travelInfo.travelTime + bufferTime
        let departureTime = event.startDate.addingTimeInterval(-totalTravelTime)

        guard departureTime > Date() else {
            print("⏰ Departure time has passed")
            return nil
        }

        var context = NotificationContext()
        context.currentLocation = NotificationContext.LocationInfo(coordinate: currentLoc.coordinate)
        context.eventLocation = NotificationContext.LocationInfo(coordinate: eventCoordinate, address: location)
        context.travelTime = totalTravelTime
        context.trafficCondition = travelInfo.traffic

        let notifType: NotificationType = (travelInfo.traffic?.severity ?? .clear) == .clear ? .departureAlert : .trafficWarning

        return SmartNotification(
            eventId: event.id,
            eventTitle: event.title,
            eventStartDate: event.startDate,
            eventLocation: event.location,
            type: notifType,
            scheduledDate: departureTime,
            context: context
        )
    }

    private func createWeatherAlert(for event: UnifiedEvent, location: String) async -> SmartNotification? {
        guard let eventCoordinate = await geocodeLocation(location) else {
            return nil
        }

        guard let weather = await fetchWeather(for: eventCoordinate, at: event.startDate) else {
            return nil
        }

        // Only create alert if weather is noteworthy
        guard weather.shouldAlert else {
            return nil
        }

        let alertTime = event.startDate.addingTimeInterval(-Double(preferences.standardReminderMinutes * 60))

        guard alertTime > Date() else {
            return nil
        }

        var context = NotificationContext()
        context.weatherCondition = weather
        context.eventLocation = NotificationContext.LocationInfo(coordinate: eventCoordinate, address: location)

        return SmartNotification(
            eventId: event.id,
            eventTitle: event.title,
            eventStartDate: event.startDate,
            eventLocation: event.location,
            type: .weatherAlert,
            scheduledDate: alertTime,
            context: context
        )
    }

    // MARK: - Helper Methods

    private func generatePrepItems(for event: UnifiedEvent) -> [String] {
        var items: [String] = []

        items.append("Review meeting agenda")

        if let location = event.location, !location.isEmpty {
            items.append("Check directions to \(location)")
        }

        items.append("Prepare questions or discussion points")
        items.append("Test video/audio if remote meeting")

        return items
    }

    private func geocodeLocation(_ address: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            print("❌ Geocoding error: \(error)")
            return nil
        }
    }

    private func calculateTravelTime(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> (travelTime: TimeInterval, traffic: NotificationContext.TrafficCondition?) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()

            if let route = response.routes.first {
                let travelTime = route.expectedTravelTime

                // Estimate traffic severity based on travel time vs distance
                // This is a simple heuristic; real traffic data would require external API
                let averageSpeed = (route.distance / 1000) / (travelTime / 3600) // km/h
                let trafficSeverity: NotificationContext.TrafficCondition.TrafficSeverity

                if averageSpeed > 50 {
                    trafficSeverity = .clear
                } else if averageSpeed > 30 {
                    trafficSeverity = .light
                } else if averageSpeed > 20 {
                    trafficSeverity = .moderate
                } else if averageSpeed > 10 {
                    trafficSeverity = .heavy
                } else {
                    trafficSeverity = .severe
                }

                let traffic = NotificationContext.TrafficCondition(
                    severity: trafficSeverity,
                    expectedDelay: 0, // Would be calculated with real-time data
                    suggestedDepartureTime: nil,
                    route: route.name
                )

                return (travelTime, traffic)
            }
        } catch {
            print("❌ Directions error: \(error)")
        }

        // Default to 30 minutes if calculation fails
        return (1800, nil)
    }

    private func fetchWeather(for coordinate: CLLocationCoordinate2D, at date: Date) async -> NotificationContext.WeatherCondition? {
        // This would integrate with WeatherKit or another weather API
        // For now, return nil as placeholder
        // TODO: Integrate with WeatherManager if available
        return nil
    }

    // MARK: - Notification Delivery

    private func deliverNotification(_ notification: SmartNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.notificationType.rawValue
        content.body = buildNotificationBody(for: notification)
        content.sound = preferences.soundEnabled ? .default : nil
        content.categoryIdentifier = "CALENDAR_EVENT"
        content.userInfo = [
            "eventId": notification.eventId,
            "notificationType": notification.notificationType.rawValue
        ]

        // Calculate time interval
        let timeInterval = notification.scheduledDate.timeIntervalSinceNow

        guard timeInterval > 0 else {
            print("⚠️ Notification time has passed: \(notification.eventTitle)")
            return
        }

        // Set category for interactive actions
        content.categoryIdentifier = "CALENDAR_EVENT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Scheduled \(notification.notificationType.rawValue) for \(notification.eventTitle)")
            }
        }
    }

    private func buildNotificationBody(for notification: SmartNotification) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        switch notification.notificationType {
        case .standard:
            return "\(notification.eventTitle) starts at \(formatter.string(from: notification.eventStartDate))"

        case .departureAlert:
            if let travelTime = notification.context.travelTime {
                let minutes = Int(travelTime / 60)
                return "Time to leave for \(notification.eventTitle). Travel time: \(minutes) min"
            }
            return "Time to leave for \(notification.eventTitle)"

        case .trafficWarning:
            if let traffic = notification.context.trafficCondition {
                return "⚠️ \(traffic.severity.rawValue) traffic on your route to \(notification.eventTitle). Leave now!"
            }
            return "Traffic alert for \(notification.eventTitle)"

        case .weatherAlert:
            if let weather = notification.context.weatherCondition {
                return "🌧️ \(weather.condition) expected at \(notification.eventTitle). Bring an umbrella!"
            }
            return "Weather advisory for \(notification.eventTitle)"

        case .meetingPrep:
            if let prep = notification.context.meetingPrepInfo {
                return "\(notification.eventTitle) in \(preferences.meetingPrepMinutes) min. \(prep.prepItems.first ?? "Get ready!")"
            }
            return "Prepare for \(notification.eventTitle)"

        case .locationReminder:
            return "You're near the location for \(notification.eventTitle)"
        }
    }

    // MARK: - Management

    func cancelNotification(id: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        scheduledNotifications.removeAll { $0.id == id }
    }

    func cancelAllNotifications(for eventId: String) {
        let idsToRemove = scheduledNotifications
            .filter { $0.eventId == eventId }
            .map { $0.id.uuidString }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        scheduledNotifications.removeAll { $0.eventId == eventId }
    }

    func updatePreferences(_ newPreferences: SmartNotificationPreferences) {
        preferences = newPreferences
        preferences.save()
        print("✅ Smart notification preferences updated")
    }

    /// Update preferences from old NotificationPreferences model (for compatibility)
    func updatePreferences(_ oldPreferences: NotificationPreferences) {
        // Map old preferences to new SmartNotificationPreferences
        var newPrefs = SmartNotificationPreferences()
        newPrefs.isEnabled = oldPreferences.enableSmartNotifications
        newPrefs.standardReminderMinutes = 15
        newPrefs.meetingPrepMinutes = oldPreferences.virtualMeetingLeadMinutes
        newPrefs.departureBufferMinutes = oldPreferences.physicalMeetingBufferMinutes
        newPrefs.soundEnabled = oldPreferences.useHapticFeedback

        // Enable features based on old preferences
        newPrefs.enableLocationAwareness = oldPreferences.enableTravelTimeCalculation
        newPrefs.enableTrafficAlerts = oldPreferences.enableTravelTimeReminder
        newPrefs.enableMeetingPrep = oldPreferences.enable15MinuteReminder

        updatePreferences(newPrefs)
    }

    /// Setup notification categories for interactive notifications
    func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_EVENT",
            title: "View Event",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 10 min",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "CALENDAR_EVENT",
            actions: [viewAction, snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
        print("✅ Notification categories registered")
    }
}

// MARK: - CLLocationManagerDelegate

extension SmartNotificationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
    }
}
