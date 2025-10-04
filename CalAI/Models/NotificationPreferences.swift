import Foundation

struct NotificationPreferences: Codable {
    // Physical meeting settings
    var physicalMeetingBufferMinutes: Int = 15
    var enableTravelTimeCalculation: Bool = true
    var minimumTravelTimeThresholdMinutes: Int = 5

    // Virtual meeting settings
    var virtualMeetingLeadMinutes: Int = 5

    // General settings
    var enableSmartNotifications: Bool = true
    var useHapticFeedback: Bool = true
    var hapticIntensity: HapticIntensity = .medium

    // Notification timing
    var notificationSound: String = "default"

    enum HapticIntensity: String, Codable, CaseIterable {
        case light = "Light"
        case medium = "Medium"
        case strong = "Strong"
    }

    // Persistence
    private static let userDefaultsKey = "smartNotificationPreferences"

    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences()
        }
        return preferences
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NotificationPreferences.userDefaultsKey)
        }
    }
}
