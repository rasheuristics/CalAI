import Foundation
import SwiftUI

// MARK: - Morning Briefing Models

/// Weather data for morning briefing
struct WeatherData: Codable {
    let temperature: Double
    let feelsLike: Double
    let condition: String
    let conditionDescription: String
    let high: Double
    let low: Double
    let precipitationChance: Int
    let humidity: Int
    let windSpeed: Double
    let icon: String

    var temperatureFormatted: String {
        return String(format: "%.0f°", temperature)
    }

    var highLowFormatted: String {
        return String(format: "H:%.0f° L:%.0f°", high, low)
    }

    var shouldShowPrecipitation: Bool {
        return precipitationChance > 30
    }

    var weatherEmoji: String {
        switch condition.lowercased() {
        case let c where c.contains("clear"):
            return "☀️"
        case let c where c.contains("cloud"):
            return "☁️"
        case let c where c.contains("rain"):
            return "🌧️"
        case let c where c.contains("storm"):
            return "⛈️"
        case let c where c.contains("snow"):
            return "❄️"
        case let c where c.contains("fog") || c.contains("mist"):
            return "🌫️"
        default:
            return "🌤️"
        }
    }
}

/// Daily briefing content
struct DailyBriefing: Identifiable {
    let id = UUID()
    let date: Date
    let weather: WeatherData?
    let events: [BriefingEvent]
    let suggestions: [String]

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    var eventCount: Int {
        return events.count
    }

    var daySummary: String {
        if events.isEmpty {
            return "No events scheduled today"
        } else if events.count == 1 {
            return "1 event scheduled today"
        } else {
            return "\(events.count) events scheduled today"
        }
    }
}

/// Event information for briefing
struct BriefingEvent: Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let location: String?
    let isAllDay: Bool
    let source: CalendarSource

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if isAllDay {
            return "All day"
        } else {
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        }
    }

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Morning briefing settings
struct MorningBriefingSettings: Codable {
    var isEnabled: Bool = true
    var briefingTime: Date = {
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    var soundEnabled: Bool = true
    var voiceAutoPlay: Bool = false

    /// Get hour and minute components
    var briefingHour: Int {
        return Calendar.current.component(.hour, from: briefingTime)
    }

    var briefingMinute: Int {
        return Calendar.current.component(.minute, from: briefingTime)
    }

    /// Storage key
    static let storageKey = "morningBriefingSettings"

    /// Load settings from UserDefaults
    static func load() -> MorningBriefingSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(MorningBriefingSettings.self, from: data) else {
            return MorningBriefingSettings()
        }
        return settings
    }

    /// Save settings to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Day Analysis

/// Analyzes calendar day and generates suggestions
struct DayAnalyzer {

    static func generateSuggestions(for events: [BriefingEvent]) -> [String] {
        var suggestions: [String] = []

        if events.isEmpty {
            suggestions.append("No meetings today - great day for deep work!")
            return suggestions
        }

        // Count events
        let eventCount = events.count

        // Analyze density
        if eventCount >= 7 {
            suggestions.append("Busy day with \(eventCount) events - stay focused!")
        } else if eventCount >= 5 {
            suggestions.append("Moderately busy day with \(eventCount) events")
        } else if eventCount >= 3 {
            suggestions.append("Balanced schedule with \(eventCount) events")
        } else {
            suggestions.append("Light schedule with \(eventCount) event\(eventCount > 1 ? "s" : "")")
        }

        // Analyze time distribution
        let morningEvents = events.filter { Calendar.current.component(.hour, from: $0.startTime) < 12 }
        let afternoonEvents = events.filter {
            let hour = Calendar.current.component(.hour, from: $0.startTime)
            return hour >= 12 && hour < 17
        }
        let eveningEvents = events.filter { Calendar.current.component(.hour, from: $0.startTime) >= 17 }

        if morningEvents.count > afternoonEvents.count + eveningEvents.count {
            suggestions.append("Morning-heavy schedule")
        } else if afternoonEvents.count > morningEvents.count + eveningEvents.count {
            suggestions.append("Afternoon-packed schedule")
        }

        // Find large gaps
        let sortedEvents = events.sorted { $0.startTime < $1.startTime }
        for i in 0..<sortedEvents.count - 1 {
            let gap = sortedEvents[i + 1].startTime.timeIntervalSince(sortedEvents[i].endTime)
            let gapHours = gap / 3600

            if gapHours >= 2 {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let startGap = formatter.string(from: sortedEvents[i].endTime)
                let endGap = formatter.string(from: sortedEvents[i + 1].startTime)
                suggestions.append("\(Int(gapHours)) hours free between \(startGap)-\(endGap)")
                break // Only mention first large gap
            }
        }

        // Check for back-to-back meetings
        var backToBackCount = 0
        for i in 0..<sortedEvents.count - 1 {
            let gap = sortedEvents[i + 1].startTime.timeIntervalSince(sortedEvents[i].endTime)
            if gap < 300 { // Less than 5 minutes
                backToBackCount += 1
            }
        }

        if backToBackCount >= 3 {
            suggestions.append("\(backToBackCount) back-to-back meetings - schedule breaks")
        }

        // First event time
        if let firstEvent = sortedEvents.first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: firstEvent.startTime)
            suggestions.append("First event at \(timeString)")
        }

        return suggestions
    }
}
