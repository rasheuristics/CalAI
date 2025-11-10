//
//  WidgetSharedModels.swift
//  CalAI
//
//  Shared models and storage for app-widget communication
//  Created by Claude Code on 11/9/25.
//

import Foundation

// MARK: - Shared Storage

/// Shared storage for calendar events accessible by both app and widget
class SharedCalendarStorage {
    static let shared = SharedCalendarStorage()

    private let appGroupID = "group.com.rasheuristics.calendarweaver"
    private let eventsKey = "sharedCalendarEvents"
    private let tasksKey = "sharedTasksCount"

    private init() {}

    // MARK: - Save Data

    func saveEvents(_ events: [WidgetCalendarEvent]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to access App Group UserDefaults")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(events)
            userDefaults.set(data, forKey: eventsKey)
            userDefaults.synchronize()
            print("✅ Saved \(events.count) events to shared storage")
        } catch {
            print("❌ Failed to encode events: \(error)")
        }
    }

    func saveTasksCount(_ count: Int) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to access App Group UserDefaults")
            return
        }

        userDefaults.set(count, forKey: tasksKey)
        userDefaults.synchronize()
        print("✅ Saved tasks count: \(count)")
    }

    // MARK: - Load Data

    func loadEvents() -> [WidgetCalendarEvent] {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: eventsKey) else {
            print("⚠️ No events found in shared storage")
            return []
        }

        do {
            let decoder = JSONDecoder()
            let events = try decoder.decode([WidgetCalendarEvent].self, from: data)
            print("✅ Loaded \(events.count) events from shared storage")
            return events
        } catch {
            print("❌ Failed to decode events: \(error)")
            return []
        }
    }

    func loadTasksCount() -> Int {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to access App Group UserDefaults")
            return 0
        }

        return userDefaults.integer(forKey: tasksKey)
    }
}

// MARK: - Widget Calendar Event Model

/// Lightweight event model for widget display
struct WidgetCalendarEvent: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?

    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
    }

    /// Formatted time string for display (e.g., "10:00 AM")
    var timeString: String {
        if isAllDay {
            return "All Day"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    /// Check if this event is today
    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }

    /// Check if this event is upcoming (in the future)
    var isUpcoming: Bool {
        startDate > Date()
    }
}
