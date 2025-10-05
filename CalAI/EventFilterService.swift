import Foundation

/// Centralized event filtering logic to eliminate code duplication
struct EventFilterService {
    private let calendar = Calendar.current

    /// Filter UnifiedEvents for a specific date
    /// - Handles all-day events that span multiple days
    /// - Handles timed events that occur on the same day
    func filterUnifiedEvents(_ events: [UnifiedEvent], for date: Date) -> [UnifiedEvent] {
        return events.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                let eventStartDay = calendar.startOfDay(for: event.startDate)
                let eventEndDay = calendar.startOfDay(for: event.endDate)
                let selectedDay = calendar.startOfDay(for: date)
                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                // For timed events, check if event starts on same day
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
        }
    }

    /// Filter CalendarEvents for a specific day (used in timeline views)
    /// - Parameters:
    ///   - events: Array of CalendarEvents to filter
    ///   - dayStart: Start of the target day
    ///   - dayEnd: End of the target day
    func filterCalendarEvents(_ events: [CalendarEvent], dayStart: Date, dayEnd: Date) -> [CalendarEvent] {
        return events.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                let eventStartDay = calendar.startOfDay(for: event.start)
                let eventEndDay = calendar.startOfDay(for: event.end)
                let selectedDay = dayStart

                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                // For timed events, check if event starts on same day
                return calendar.isDate(event.start, inSameDayAs: dayStart)
            }
        }
    }
}
