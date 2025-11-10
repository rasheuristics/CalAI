//
//  AmbientContextManager.swift
//  CalAI
//
//  Ambient context awareness for intelligent, environment-aware assistance
//  Created by Claude Code on 11/9/25.
//

import Foundation
import CoreLocation
import CoreMotion
import Combine
import EventKit

// MARK: - Context Types

enum LocationContext: String, Codable {
    case home = "home"
    case work = "work"
    case commuting = "commuting"
    case meetingVenue = "meeting_venue"
    case gym = "gym"
    case unknown = "unknown"

    var suggestedActions: [String] {
        switch self {
        case .home:
            return ["Review tomorrow's schedule", "Plan next week", "Check upcoming deadlines"]
        case .work:
            return ["Check today's meetings", "Find free time for focus work", "Schedule team sync"]
        case .commuting:
            return ["Listen to calendar summary", "Review next meeting agenda", "Reschedule if running late"]
        case .meetingVenue:
            return ["Check in to meeting", "View meeting notes", "Set reminder for follow-ups"]
        case .gym:
            return ["Block workout time", "Schedule recovery time", "Plan post-workout meetings"]
        case .unknown:
            return []
        }
    }
}

enum TimeContext: String, Codable {
    case earlyMorning = "early_morning" // 5am-8am
    case morning = "morning" // 8am-12pm
    case afternoon = "afternoon" // 12pm-5pm
    case evening = "evening" // 5pm-9pm
    case night = "night" // 9pm-5am

    var suggestedActions: [String] {
        switch self {
        case .earlyMorning:
            return ["Plan today", "Review morning meetings", "Set daily priorities"]
        case .morning:
            return ["Focus work blocks", "Morning standups", "Important meetings"]
        case .afternoon:
            return ["Check progress", "Afternoon meetings", "Collaborative work"]
        case .evening:
            return ["Wrap up tasks", "Tomorrow's prep", "Evening reviews"]
        case .night:
            return ["Review day", "Plan tomorrow", "Personal time"]
        }
    }

    static func from(hour: Int) -> TimeContext {
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

enum ActivityContext: String, Codable {
    case stationary = "stationary"
    case walking = "walking"
    case running = "running"
    case driving = "driving"
    case cycling = "cycling"
    case unknown = "unknown"

    var allowsVoiceInteraction: Bool {
        switch self {
        case .stationary, .walking:
            return true
        case .driving:
            return true // Voice-only for safety
        case .running, .cycling:
            return false // Too active
        case .unknown:
            return true
        }
    }

    var preferredInputMode: String {
        switch self {
        case .driving:
            return "voice_only"
        case .stationary:
            return "voice_or_text"
        case .walking:
            return "quick_voice"
        case .running, .cycling:
            return "none"
        case .unknown:
            return "voice_or_text"
        }
    }
}

enum WorkloadContext: String, Codable {
    case light = "light" // < 3 meetings today
    case moderate = "moderate" // 3-6 meetings
    case heavy = "heavy" // 6-10 meetings
    case overloaded = "overloaded" // 10+ meetings

    var suggestedActions: [String] {
        switch self {
        case .light:
            return ["Schedule focus work", "Plan ahead", "Take on new tasks"]
        case .moderate:
            return ["Maintain balance", "Buffer time between meetings", "Stay on schedule"]
        case .heavy:
            return ["Prioritize critical meetings", "Delegate if possible", "Block lunch break"]
        case .overloaded:
            return ["Reschedule non-critical", "Ask for help", "Protect personal time"]
        }
    }
}

// MARK: - Ambient Context Snapshot

struct AmbientContext: Codable {
    let timestamp: Date

    // Location context
    let locationContext: LocationContext
    let currentLocation: String?
    let isAtKnownLocation: Bool
    let nearbyMeetingVenue: Bool

    // Time context
    let timeContext: TimeContext
    let isWorkingHours: Bool
    let minutesUntilNextMeeting: Int?

    // Activity context
    let activityContext: ActivityContext
    let isMoving: Bool
    let isBusy: Bool

    // Workload context
    let workloadContext: WorkloadContext
    let meetingsToday: Int
    let meetingsThisWeek: Int
    let hasConflicts: Bool

    // Device context
    let batteryLevel: Float
    let isCharging: Bool
    let hasNetworkConnection: Bool

    // Calendar context
    let inMeeting: Bool
    let nextMeetingTitle: String?
    let hasImminentMeeting: Bool // < 15 min

    var confidenceLevel: Double {
        var confidence = 0.0

        // Higher confidence if we have good location data
        if isAtKnownLocation { confidence += 0.3 }

        // Higher confidence during working hours
        if isWorkingHours { confidence += 0.2 }

        // Higher confidence if we know activity
        if activityContext != .unknown { confidence += 0.2 }

        // Higher confidence if we have calendar data
        if minutesUntilNextMeeting != nil { confidence += 0.3 }

        return confidence
    }

    var suggestedBehavior: String {
        // In meeting - minimal interruptions
        if inMeeting {
            return "silent_mode"
        }

        // Meeting very soon - quick interactions only
        if hasImminentMeeting {
            return "quick_interactions"
        }

        // Driving - voice only
        if activityContext == .driving {
            return "voice_only"
        }

        // Heavy activity - no interruptions
        if activityContext == .running || activityContext == .cycling {
            return "do_not_disturb"
        }

        // Low battery - reduce processing
        if batteryLevel < 0.2 && !isCharging {
            return "power_saving"
        }

        // Working hours at work location - full features
        if isWorkingHours && locationContext == .work {
            return "full_features"
        }

        // Evening/night - personal mode
        if timeContext == .evening || timeContext == .night {
            return "personal_mode"
        }

        return "normal"
    }
}

// MARK: - Ambient Context Manager

class AmbientContextManager: NSObject, ObservableObject {
    static let shared = AmbientContextManager()

    @Published var currentContext: AmbientContext?
    @Published var locationContext: LocationContext = .unknown
    @Published var timeContext: TimeContext = .morning
    @Published var activityContext: ActivityContext = .unknown

    // Location tracking
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var knownLocations: [String: CLLocation] = [:]

    // Motion tracking
    private let motionManager = CMMotionActivityManager()
    private var currentActivity: CMMotionActivity?

    // Calendar context
    private weak var calendarManager: CalendarManager?

    // Context update
    private var contextUpdateTimer: Timer?
    private let contextUpdateInterval: TimeInterval = 60 // Update every minute

    // Combine
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupLocationTracking()
        setupMotionTracking()
        startContextUpdates()
        loadKnownLocations()
    }

    // MARK: - Setup

    private func setupLocationTracking() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100m

        // Request permission
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupMotionTracking() {
        if CMMotionActivityManager.isActivityAvailable() {
            motionManager.startActivityUpdates(to: .main) { [weak self] activity in
                self?.currentActivity = activity
                self?.updateActivityContext(from: activity)
            }
        }
    }

    private func startContextUpdates() {
        // Initial update
        updateContext()

        // Periodic updates
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: contextUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateContext()
        }
    }

    // MARK: - Context Updates

    func updateContext() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        // Time context
        timeContext = TimeContext.from(hour: hour)
        let isWorkingHours = (9...17).contains(hour) && calendar.component(.weekday, from: now) > 1 && calendar.component(.weekday, from: now) < 7

        // Location context (if we have location data)
        updateLocationContext()

        // Calendar context
        var meetingsToday = 0
        var meetingsThisWeek = 0
        var inMeeting = false
        var nextMeetingTitle: String?
        var minutesUntilNextMeeting: Int?
        var hasImminentMeeting = false
        var hasConflicts = false
        var nearbyMeetingVenue = false

        if let calendarManager = calendarManager {
            let events = calendarManager.unifiedEvents

            // Count meetings today
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            meetingsToday = events.filter { $0.startDate >= startOfDay && $0.startDate < endOfDay }.count

            // Count meetings this week
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            meetingsThisWeek = events.filter { $0.startDate >= startOfWeek && $0.startDate < endOfWeek }.count

            // Check if in meeting now
            inMeeting = events.contains { $0.startDate <= now && $0.endDate > now }

            // Find next meeting
            if let nextEvent = events.filter({ $0.startDate > now }).sorted(by: { $0.startDate < $1.startDate }).first {
                nextMeetingTitle = nextEvent.title
                minutesUntilNextMeeting = Int(nextEvent.startDate.timeIntervalSince(now) / 60)
                hasImminentMeeting = (minutesUntilNextMeeting ?? 999) < 15

                // Check if we're near the meeting venue
                if let meetingLocation = nextEvent.location,
                   let currentLoc = currentLocation {
                    // Simplified proximity check - in real app, would geocode the address
                    nearbyMeetingVenue = false // Placeholder
                }
            }

            // Check for conflicts
            hasConflicts = !calendarManager.checkConflicts(startDate: now, endDate: calendar.date(byAdding: .day, value: 1, to: now)!).conflictingEvents.isEmpty
        }

        // Workload context
        let workloadContext: WorkloadContext
        if meetingsToday < 3 {
            workloadContext = .light
        } else if meetingsToday < 6 {
            workloadContext = .moderate
        } else if meetingsToday < 10 {
            workloadContext = .heavy
        } else {
            workloadContext = .overloaded
        }

        // Device context
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        let hasNetworkConnection = true // Simplified - would use Network framework

        // Create context snapshot
        currentContext = AmbientContext(
            timestamp: now,
            locationContext: locationContext,
            currentLocation: currentLocation?.description,
            isAtKnownLocation: locationContext != .unknown,
            nearbyMeetingVenue: nearbyMeetingVenue,
            timeContext: timeContext,
            isWorkingHours: isWorkingHours,
            minutesUntilNextMeeting: minutesUntilNextMeeting,
            activityContext: activityContext,
            isMoving: activityContext == .walking || activityContext == .running || activityContext == .driving,
            isBusy: inMeeting || hasImminentMeeting,
            workloadContext: workloadContext,
            meetingsToday: meetingsToday,
            meetingsThisWeek: meetingsThisWeek,
            hasConflicts: hasConflicts,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            hasNetworkConnection: hasNetworkConnection,
            inMeeting: inMeeting,
            nextMeetingTitle: nextMeetingTitle,
            hasImminentMeeting: hasImminentMeeting
        )

        print("🌍 Context updated: \(locationContext.rawValue), \(timeContext.rawValue), \(activityContext.rawValue), \(workloadContext.rawValue)")
    }

    private func updateLocationContext() {
        guard let location = currentLocation else {
            locationContext = .unknown
            return
        }

        // Check against known locations
        for (name, knownLocation) in knownLocations {
            let distance = location.distance(from: knownLocation)
            if distance < 100 { // Within 100m
                if name == "Home" {
                    locationContext = .home
                } else if name == "Work" {
                    locationContext = .work
                } else if name == "Gym" {
                    locationContext = .gym
                }
                return
            }
        }

        // Check speed to determine if commuting
        if let speed = currentLocation?.speed, speed > 5 { // > 5 m/s (18 km/h)
            locationContext = .commuting
        } else {
            locationContext = .unknown
        }
    }

    private func updateActivityContext(from activity: CMMotionActivity?) {
        guard let activity = activity else {
            activityContext = .unknown
            return
        }

        if activity.stationary {
            activityContext = .stationary
        } else if activity.walking {
            activityContext = .walking
        } else if activity.running {
            activityContext = .running
        } else if activity.automotive {
            activityContext = .driving
        } else if activity.cycling {
            activityContext = .cycling
        } else {
            activityContext = .unknown
        }
    }

    // MARK: - Known Locations Management

    func learnLocation(name: String, location: CLLocation) {
        knownLocations[name] = location
        saveKnownLocations()
        print("📍 Learned location: \(name)")
    }

    func learnCurrentLocationAs(name: String) {
        guard let location = currentLocation else { return }
        learnLocation(name: name, location: location)
    }

    private func loadKnownLocations() {
        // Load from UserDefaults (simplified - would use more robust storage)
        if let data = UserDefaults.standard.data(forKey: "known_locations"),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            knownLocations = decoded.compactMapValues { coords in
                guard let lat = coords["latitude"], let lon = coords["longitude"] else { return nil }
                return CLLocation(latitude: lat, longitude: lon)
            }
        }
    }

    private func saveKnownLocations() {
        let encoded = knownLocations.mapValues { location in
            ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude]
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: "known_locations")
        }
    }

    // MARK: - Integration

    func setCalendarManager(_ manager: CalendarManager) {
        self.calendarManager = manager
        updateContext()
    }

    // MARK: - AI Context Generation

    func generateAIContext() -> String {
        guard let context = currentContext else {
            return ""
        }

        var contextString = "Current context:\n"

        // Location
        if context.locationContext != .unknown {
            contextString += "- Location: \(context.locationContext.rawValue)\n"
        }

        // Time
        contextString += "- Time: \(context.timeContext.rawValue)"
        if !context.isWorkingHours {
            contextString += " (outside work hours)"
        }
        contextString += "\n"

        // Activity
        if context.activityContext != .unknown {
            contextString += "- Activity: \(context.activityContext.rawValue)\n"
        }

        // Meeting status
        if context.inMeeting {
            contextString += "- Currently in a meeting\n"
        } else if context.hasImminentMeeting, let title = context.nextMeetingTitle, let minutes = context.minutesUntilNextMeeting {
            contextString += "- Next meeting '\(title)' in \(minutes) minutes\n"
        }

        // Workload
        contextString += "- Today's workload: \(context.workloadContext.rawValue) (\(context.meetingsToday) meetings)\n"

        // Suggested behavior
        let behavior = context.suggestedBehavior
        if behavior != "normal" {
            contextString += "- Suggested mode: \(behavior)\n"
        }

        return contextString
    }

    func getSuggestedActions() -> [String] {
        guard let context = currentContext else { return [] }

        var suggestions: [String] = []

        // Add location-based suggestions
        suggestions.append(contentsOf: context.locationContext.suggestedActions)

        // Add time-based suggestions
        suggestions.append(contentsOf: context.timeContext.suggestedActions)

        // Add workload-based suggestions
        suggestions.append(contentsOf: context.workloadContext.suggestedActions)

        // Add context-specific suggestions
        if context.hasImminentMeeting {
            suggestions.insert("Prepare for upcoming meeting", at: 0)
        }

        if context.nearbyMeetingVenue {
            suggestions.insert("Check in to nearby meeting", at: 0)
        }

        if context.hasConflicts {
            suggestions.insert("Resolve schedule conflicts", at: 0)
        }

        return Array(suggestions.prefix(5)) // Top 5
    }

    func shouldEnableFeature(_ feature: String) -> Bool {
        guard let context = currentContext else { return true }

        switch feature {
        case "voice_input":
            return context.activityContext.allowsVoiceInteraction
        case "notifications":
            return !context.inMeeting && context.activityContext != .running && context.activityContext != .cycling
        case "background_sync":
            return context.isCharging || context.batteryLevel > 0.3
        case "proactive_suggestions":
            return context.suggestedBehavior != "do_not_disturb"
        default:
            return true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AmbientContextManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        updateLocationContext()
        updateContext()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
