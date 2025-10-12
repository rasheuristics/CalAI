import Foundation
import UserNotifications
import Combine

/// Service for generating and delivering morning briefings
class MorningBriefingService: ObservableObject {
    static let shared = MorningBriefingService()

    @Published var todaysBriefing: DailyBriefing?
    @Published var settings: MorningBriefingSettings
    @Published var isGenerating = false

    private var calendarManager: CalendarManager?
    private var weatherService: WeatherService?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.settings = MorningBriefingSettings.load()
    }

    // MARK: - Configuration

    func configure(calendarManager: CalendarManager) {
        print("📋 MorningBriefingService: Configuring...")
        self.calendarManager = calendarManager
        self.weatherService = WeatherService.shared
        print("📋 MorningBriefingService: WeatherService set to \(weatherService != nil ? "✅ shared instance" : "❌ nil")")

        // Request location permission for weather
        weatherService?.requestLocationPermission()
        print("📋 MorningBriefingService: Location permission requested")

        // Schedule notification if enabled
        if settings.isEnabled {
            print("📋 MorningBriefingService: Scheduling notifications (enabled)")
            scheduleNotification()
        } else {
            print("📋 MorningBriefingService: Notifications disabled in settings")
        }
        print("📋 MorningBriefingService: Configuration complete")
    }

    // MARK: - Settings Management

    func updateSettings(_ newSettings: MorningBriefingSettings) {
        settings = newSettings
        settings.save()

        // Reschedule notification with new time
        if settings.isEnabled {
            scheduleNotification()
        } else {
            cancelNotification()
        }
    }

    // MARK: - Briefing Generation

    func generateBriefing(for date: Date = Date(), completion: @escaping (DailyBriefing) -> Void) {
        print("📋 Starting briefing generation...")
        isGenerating = true

        // Get today's events
        guard let calendarManager = calendarManager else {
            print("❌ CalendarManager not configured")
            isGenerating = false
            return
        }

        print("📋 CalendarManager configured, checking weather service...")
        guard let weatherService = weatherService else {
            print("❌ WeatherService not configured!")
            isGenerating = false
            return
        }
        print("✅ WeatherService is configured")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Filter events for today
        let todaysEvents = calendarManager.unifiedEvents.filter { event in
            event.startDate >= startOfDay && event.startDate < endOfDay
        }.sorted { $0.startDate < $1.startDate }

        // Convert to briefing events
        let briefingEvents = todaysEvents.map { event in
            BriefingEvent(
                id: event.id,
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                source: event.source
            )
        }

        // Generate suggestions
        let suggestions = DayAnalyzer.generateSuggestions(for: briefingEvents)

        print("📋 Fetching weather data...")
        // Fetch weather
        weatherService.fetchCurrentWeather { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                var weather: WeatherData? = nil

                switch result {
                case .success(let weatherData):
                    print("✅ Weather fetched successfully: \(weatherData.temperature)°, \(weatherData.condition)")
                    weather = weatherData
                case .failure(let error):
                    print("❌ Weather fetch failed: \(error.localizedDescription)")
                    // Continue without weather data
                }

                let briefing = DailyBriefing(
                    date: date,
                    weather: weather,
                    events: briefingEvents,
                    suggestions: suggestions
                )

                print("📋 Briefing created:")
                print("   - Date: \(date)")
                print("   - Weather: \(weather != nil ? "✅ Available (\(weather!.temperatureFormatted))" : "❌ Not available")")
                print("   - Events: \(briefingEvents.count)")
                print("   - Suggestions: \(suggestions.count)")

                self.todaysBriefing = briefing
                self.isGenerating = false
                completion(briefing)
            }
        }
    }

    // MARK: - Notification Management

    func scheduleNotification() {
        let center = UNUserNotificationCenter.current()

        // Request authorization
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                self.scheduleDailyNotification()
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    private func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()

        // Remove existing morning briefing notifications
        center.removePendingNotificationRequests(withIdentifiers: ["morningBriefing"])

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Your daily briefing is ready"
        content.categoryIdentifier = "MORNING_BRIEFING"
        content.userInfo = ["type": "morningBriefing"]

        // Add sound if enabled
        if settings.soundEnabled {
            content.sound = .default
        }

        // Create trigger for daily delivery
        var dateComponents = DateComponents()
        dateComponents.hour = settings.briefingHour
        dateComponents.minute = settings.briefingMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create request
        let request = UNNotificationRequest(
            identifier: "morningBriefing",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule morning briefing: \(error.localizedDescription)")
            } else {
                print("✅ Morning briefing scheduled for \(dateComponents.hour!):\(String(format: "%02d", dateComponents.minute!))")
            }
        }
    }

    func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morningBriefing"])
        print("🔕 Morning briefing notifications cancelled")
    }

    // MARK: - Voice Generation

    func generateVoiceScript(for briefing: DailyBriefing) -> String {
        var script = "\(briefing.greeting). "

        // Weather
        if let weather = briefing.weather {
            script += "It's currently \(Int(weather.temperature)) degrees and \(weather.conditionDescription). "
            script += "Today's high will be \(Int(weather.high)) and low \(Int(weather.low)). "

            if weather.shouldShowPrecipitation {
                script += "There's a \(weather.precipitationChance) percent chance of precipitation. "
            }
        }

        // Events
        if briefing.events.isEmpty {
            script += "You have no events scheduled today. "
        } else if briefing.events.count == 1 {
            script += "You have 1 event today. "
        } else {
            script += "You have \(briefing.events.count) events today. "
        }

        // List events
        for (index, event) in briefing.events.prefix(5).enumerated() {
            if index == 0 {
                script += "Starting with "
            } else if index == briefing.events.count - 1 {
                script += "And finally, "
            } else {
                script += "Then, "
            }

            script += "\(event.title) at \(formatTimeForVoice(event.startTime)). "

            if let location = event.location, !location.isEmpty {
                script += "Located at \(location). "
            }
        }

        if briefing.events.count > 5 {
            script += "Plus \(briefing.events.count - 5) more events. "
        }

        // Suggestions
        if !briefing.suggestions.isEmpty {
            script += briefing.suggestions.prefix(3).joined(separator: ". ") + ". "
        }

        script += "Have a great day!"

        return script
    }

    private func formatTimeForVoice(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: date)

        // Convert "3:00 PM" to "3 PM" for voice
        return timeString.replacingOccurrences(of: ":00", with: "")
    }

    // MARK: - Testing

    /// Generate a test briefing immediately (for testing)
    func generateTestBriefing() {
        generateBriefing(for: Date()) { briefing in
            print("📋 Test briefing generated:")
            print("   Events: \(briefing.eventCount)")
            print("   Weather: \(briefing.weather?.temperatureFormatted ?? "N/A")")
            print("   Suggestions: \(briefing.suggestions.count)")
        }
    }

    /// Send a test notification immediately
    func sendTestNotification() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Test Morning Briefing"
                content.body = "Your daily briefing is ready (Test)"
                content.categoryIdentifier = "MORNING_BRIEFING"

                if self.settings.soundEnabled {
                    content.sound = .default
                }

                // Trigger in 5 seconds
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "testMorningBriefing",
                    content: content,
                    trigger: trigger
                )

                center.add(request) { error in
                    if let error = error {
                        print("❌ Failed to send test notification: \(error.localizedDescription)")
                    } else {
                        print("✅ Test notification scheduled for 5 seconds from now")
                    }
                }
            } else {
                print("❌ Notification permission denied")
            }
        }
    }
}
