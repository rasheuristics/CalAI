import Foundation
import UserNotifications
import CoreLocation
import UIKit

class SmartNotificationManager: NSObject, ObservableObject {
    static let shared = SmartNotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let analyzer = MeetingAnalyzer.shared
    private let travelManager = TravelTimeManager.shared

    @Published var isAuthorized = false
    @Published var preferences = NotificationPreferences.load()

    private override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorization()
    }

    // MARK: - Permission Management

    /// Request notification permission with time-sensitive capability
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]

        notificationCenter.requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted

                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if granted {
                    print("✅ Time-sensitive notification permission granted")
                    completion(true)
                } else {
                    print("❌ Notification permission denied")
                    completion(false)
                }
            }
        }
    }

    /// Check current authorization status
    func checkAuthorization() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                print("🔵 Notification authorization status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }

    // MARK: - Smart Notification Scheduling

    /// Schedule a smart notification for a meeting
    func scheduleMeetingNotification(
        title: String,
        location: String?,
        notes: String?,
        startDate: Date,
        endDate: Date
    ) {
        guard preferences.enableSmartNotifications else {
            print("⚠️ Smart notifications disabled in preferences")
            return
        }

        // Analyze the meeting
        let meetingInfo = analyzer.analyze(
            title: title,
            location: location,
            notes: notes,
            startDate: startDate,
            endDate: endDate
        )

        print("🔵 Scheduling notification for '\(meetingInfo.title)'")
        print("   Type: \(meetingInfo.type)")

        // Schedule universal 15-minute reminder if enabled
        if preferences.enable15MinuteReminder {
            schedule15MinuteReminder(meetingInfo: meetingInfo)
        }

        // Schedule based on meeting type
        switch meetingInfo.type {
        case .physical(let location):
            schedulePhysicalMeetingNotification(meetingInfo: meetingInfo, location: location)

        case .virtual(let link, let platform):
            scheduleVirtualMeetingNotification(meetingInfo: meetingInfo, link: link, platform: platform)

        case .hybrid(let location, let link, let platform):
            // For hybrid, schedule both and use the earlier notification time
            scheduleHybridMeetingNotification(meetingInfo: meetingInfo, location: location, link: link, platform: platform)

        case .unknown:
            // Fall back to standard reminder
            scheduleStandardNotification(meetingInfo: meetingInfo)
        }
    }

    // MARK: - Universal 15-Minute Reminder

    private func schedule15MinuteReminder(meetingInfo: MeetingInfo) {
        let notificationTime = meetingInfo.startDate.addingTimeInterval(-15 * 60)

        createAndScheduleNotification(
            meetingInfo: meetingInfo,
            notificationTime: notificationTime,
            title: "Meeting in 15 Minutes",
            body: "'\(meetingInfo.title)' starts in 15 minutes.",
            categoryIdentifier: "FIFTEEN_MINUTE_REMINDER",
            userInfo: ["meetingType": "15min_reminder"],
            identifier: "15min_\(meetingInfo.title)_\(meetingInfo.startDate.timeIntervalSince1970)"
        )
    }

    // MARK: - Physical Meeting Notifications

    private func schedulePhysicalMeetingNotification(meetingInfo: MeetingInfo, location: String) {
        guard preferences.enableTravelTimeCalculation && preferences.enableTravelTimeReminder else {
            // If travel time calculation is disabled, use standard notification
            scheduleStandardNotification(meetingInfo: meetingInfo)
            return
        }

        // Geocode the location
        analyzer.geocodeLocation(location) { [weak self] coordinate in
            guard let self = self, let coordinate = coordinate else {
                print("⚠️ Could not geocode location, using standard notification")
                self?.scheduleStandardNotification(meetingInfo: meetingInfo)
                return
            }

            // Calculate departure time
            self.travelManager.calculateDepartureTime(
                meetingStartTime: meetingInfo.startDate,
                destinationCoordinate: coordinate,
                bufferMinutes: self.preferences.physicalMeetingBufferMinutes
            ) { departureTime, travelTime in
                guard let departureTime = departureTime,
                      let travelTime = travelTime else {
                    print("⚠️ Could not calculate departure time, using standard notification")
                    self.scheduleStandardNotification(meetingInfo: meetingInfo)
                    return
                }

                let travelMinutes = Int(travelTime / 60)

                // Check if travel time meets minimum threshold
                if travelMinutes < self.preferences.minimumTravelTimeThresholdMinutes {
                    print("⚠️ Travel time (\(travelMinutes) min) below threshold, using standard notification")
                    self.scheduleStandardNotification(meetingInfo: meetingInfo)
                    return
                }

                // Schedule the notification
                self.createAndScheduleNotification(
                    meetingInfo: meetingInfo,
                    notificationTime: departureTime,
                    title: "Time to Leave",
                    body: "Leave now for '\(meetingInfo.title)' at \(location). Travel time: \(travelMinutes) min.",
                    categoryIdentifier: "PHYSICAL_MEETING",
                    userInfo: [
                        "meetingType": "physical",
                        "location": location,
                        "travelMinutes": travelMinutes,
                        "destinationLat": coordinate.latitude,
                        "destinationLon": coordinate.longitude
                    ],
                    identifier: "travel_\(meetingInfo.title)_\(meetingInfo.startDate.timeIntervalSince1970)"
                )
            }
        }
    }

    // MARK: - Virtual Meeting Notifications

    private func scheduleVirtualMeetingNotification(meetingInfo: MeetingInfo, link: String, platform: MeetingType.VirtualPlatform) {
        // Schedule 5-minute join reminder if enabled
        if preferences.enable5MinuteVirtualReminder {
            let fiveMinNotificationTime = meetingInfo.startDate.addingTimeInterval(-5 * 60)

            createAndScheduleNotification(
                meetingInfo: meetingInfo,
                notificationTime: fiveMinNotificationTime,
                title: "Join Meeting Now",
                body: "'\(meetingInfo.title)' starts in 5 minutes on \(platform.rawValue). Tap to join.",
                categoryIdentifier: "VIRTUAL_MEETING",
                userInfo: [
                    "meetingType": "virtual",
                    "meetingLink": link,
                    "platform": platform.rawValue
                ],
                identifier: "virtual_5min_\(meetingInfo.title)_\(meetingInfo.startDate.timeIntervalSince1970)"
            )
        }
    }

    // MARK: - Hybrid Meeting Notifications

    private func scheduleHybridMeetingNotification(meetingInfo: MeetingInfo, location: String, link: String, platform: MeetingType.VirtualPlatform) {
        // For hybrid meetings, give user both options
        // Schedule virtual meeting notification (shorter lead time)
        let virtualLeadMinutes = preferences.virtualMeetingLeadMinutes
        let virtualNotificationTime = meetingInfo.startDate.addingTimeInterval(-TimeInterval(virtualLeadMinutes * 60))

        createAndScheduleNotification(
            meetingInfo: meetingInfo,
            notificationTime: virtualNotificationTime,
            title: "Meeting Options Available",
            body: "'\(meetingInfo.title)' starts in \(virtualLeadMinutes) min. Join virtually or check travel time.",
            categoryIdentifier: "HYBRID_MEETING",
            userInfo: [
                "meetingType": "hybrid",
                "location": location,
                "meetingLink": link,
                "platform": platform.rawValue
            ]
        )
    }

    // MARK: - Standard Notification (Fallback)

    private func scheduleStandardNotification(meetingInfo: MeetingInfo) {
        let leadMinutes = 15
        let notificationTime = meetingInfo.startDate.addingTimeInterval(-TimeInterval(leadMinutes * 60))

        createAndScheduleNotification(
            meetingInfo: meetingInfo,
            notificationTime: notificationTime,
            title: "Upcoming Meeting",
            body: "'\(meetingInfo.title)' starts in \(leadMinutes) minutes.",
            categoryIdentifier: "STANDARD_MEETING",
            userInfo: ["meetingType": "standard"]
        )
    }

    // MARK: - Core Notification Creation

    private func createAndScheduleNotification(
        meetingInfo: MeetingInfo,
        notificationTime: Date,
        title: String,
        body: String,
        categoryIdentifier: String,
        userInfo: [String: Any],
        identifier: String? = nil
    ) {
        // Don't schedule if notification time is in the past
        guard notificationTime > Date() else {
            print("⚠️ Notification time is in the past, skipping")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = categoryIdentifier

        // Add user info for handling actions
        var fullUserInfo = userInfo
        fullUserInfo["meetingTitle"] = meetingInfo.title
        fullUserInfo["meetingStartTime"] = meetingInfo.startDate.timeIntervalSince1970
        content.userInfo = fullUserInfo

        // Create trigger
        let timeInterval = notificationTime.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

        // Use custom identifier or create unique one
        let notificationIdentifier = identifier ?? "meeting_\(meetingInfo.title)_\(meetingInfo.startDate.timeIntervalSince1970)"

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("✅ Scheduled '\(title)' notification for \(formatter.string(from: notificationTime))")
            }
        }
    }

    // MARK: - Notification Categories & Actions

    func setupNotificationCategories() {
        // Physical meeting actions
        let getDirectionsAction = UNNotificationAction(
            identifier: "GET_DIRECTIONS",
            title: "Get Directions",
            options: .foreground
        )

        let physicalCategory = UNNotificationCategory(
            identifier: "PHYSICAL_MEETING",
            actions: [getDirectionsAction],
            intentIdentifiers: [],
            options: []
        )

        // Virtual meeting actions
        let joinMeetingAction = UNNotificationAction(
            identifier: "JOIN_MEETING",
            title: "Join Meeting",
            options: .foreground
        )

        let virtualCategory = UNNotificationCategory(
            identifier: "VIRTUAL_MEETING",
            actions: [joinMeetingAction],
            intentIdentifiers: [],
            options: []
        )

        // Hybrid meeting actions
        let hybridCategory = UNNotificationCategory(
            identifier: "HYBRID_MEETING",
            actions: [joinMeetingAction, getDirectionsAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([physicalCategory, virtualCategory, hybridCategory])
        print("✅ Notification categories configured")
    }

    // MARK: - Utility Methods

    /// Remove all pending meeting notifications
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("🔵 Removed all pending notifications")
    }

    /// Update preferences and save
    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
        preferences.save()
        print("✅ Preferences updated and saved")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension SmartNotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 Notification received while app in foreground")
        completionHandler([.banner, .sound, .badge])
    }

    // Handle user interaction with notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        print("🔔 Notification action: \(actionIdentifier)")

        switch actionIdentifier {
        case "GET_DIRECTIONS":
            handleGetDirections(userInfo: userInfo)

        case "JOIN_MEETING":
            handleJoinMeeting(userInfo: userInfo)

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            print("🔵 User tapped notification")

        default:
            break
        }

        completionHandler()
    }

    // MARK: - Action Handlers

    private func handleGetDirections(userInfo: [AnyHashable: Any]) {
        guard let lat = userInfo["destinationLat"] as? Double,
              let lon = userInfo["destinationLon"] as? Double else {
            print("⚠️ No destination coordinates in notification")
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let urlString = "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)"

        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                #if os(iOS)
                UIApplication.shared.open(url)
                print("✅ Opening Apple Maps for directions")
                #endif
            }
        }
    }

    private func handleJoinMeeting(userInfo: [AnyHashable: Any]) {
        guard let meetingLink = userInfo["meetingLink"] as? String,
              let url = URL(string: meetingLink) else {
            print("⚠️ No valid meeting link in notification")
            return
        }

        DispatchQueue.main.async {
            #if os(iOS)
            UIApplication.shared.open(url)
            print("✅ Opening meeting link: \(meetingLink)")
            #endif
        }
    }
}
