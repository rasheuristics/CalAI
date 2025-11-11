import Foundation
import EventKit
import Combine

enum CalendarSource {
    case ios
    case google
    case outlook
}

struct UnifiedEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let description: String?
    let isAllDay: Bool
    let source: CalendarSource
    let originalEvent: Any

    var sourceLabel: String {
        switch source {
        case .ios: return "📱 iOS"
        case .google: return "🟢 Google"
        case .outlook: return "🔵 Outlook"
        }
    }

    var duration: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

class CalendarManager: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var unifiedEvents: [UnifiedEvent] = []
    @Published var hasCalendarAccess = false

    let eventStore = EKEventStore()

    // External calendar managers will be injected
    var googleCalendarManager: GoogleCalendarManager?
    var outlookCalendarManager: OutlookCalendarManager?

    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadEvents()
                    }
                }
            }
        }
    }

    func loadEvents() {
        guard hasCalendarAccess else { return }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)

        DispatchQueue.main.async {
            self.events = fetchedEvents.sorted { $0.startDate < $1.startDate }
            self.loadAllUnifiedEvents()
        }
    }

    func loadAllUnifiedEvents() {
        var allEvents: [UnifiedEvent] = []

        // Add iOS events
        let iosEvents = events.map { event in
            UnifiedEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                description: event.notes,
                isAllDay: event.isAllDay,
                source: .ios,
                originalEvent: event
            )
        }
        allEvents.append(contentsOf: iosEvents)

        // Add Google events
        if let googleManager = googleCalendarManager {
            let googleEvents = googleManager.googleEvents.map { event in
                UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.description,
                    isAllDay: false, // Google events default to not all-day
                    source: .google,
                    originalEvent: event
                )
            }
            allEvents.append(contentsOf: googleEvents)
        }

        // Add Outlook events
        if let outlookManager = outlookCalendarManager {
            let outlookEvents = outlookManager.outlookEvents.map { event in
                UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.description,
                    isAllDay: false, // Outlook events default to not all-day
                    source: .outlook,
                    originalEvent: event
                )
            }
            allEvents.append(contentsOf: outlookEvents)
        }

        // Sort all events by start date
        unifiedEvents = allEvents.sorted { $0.startDate < $1.startDate }
        print("✅ Loaded \(unifiedEvents.count) unified events from all sources")
    }

    func refreshAllCalendars() {
        print("🔄 Refreshing all calendar sources...")

        // Refresh iOS events
        loadEvents()

        // Refresh Google events
        if let googleManager = googleCalendarManager, googleManager.isSignedIn {
            googleManager.fetchEvents()
        }

        // Refresh Outlook events
        if let outlookManager = outlookCalendarManager, outlookManager.isSignedIn, outlookManager.selectedCalendar != nil {
            outlookManager.fetchEvents()
        }

        // Update unified events after a delay to allow external fetches to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadAllUnifiedEvents()
        }
    }

    func createEvent(title: String, startDate: Date, endDate: Date? = nil) {
        print("📝 Creating calendar event: \(title)")
        guard hasCalendarAccess else {
            print("❌ No calendar access for event creation")
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        print("📅 Event details: \(title) from \(startDate) to \(event.endDate)")

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event saved successfully")
            loadEvents()
        } catch {
            print("❌ Error creating event: \(error)")
        }
    }

    func deleteEvent(_ event: EKEvent) {
        print("🗑️ Deleting event: \(event.title ?? "Untitled")")
        guard hasCalendarAccess else {
            print("❌ No calendar access for event deletion")
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
            print("✅ Event deleted successfully")
            loadEvents()
        } catch {
            print("❌ Error deleting event: \(error)")
        }
    }

    func handleAIResponse(_ response: AIResponse) {
        print("📅 CalendarManager handling AI response: action=\(response.action), title=\(response.eventTitle ?? "nil")")

        switch response.action {
        case .createEvent:
            if let title = response.eventTitle,
               let startDate = response.startDate {
                print("✅ Creating event: \(title) at \(startDate)")
                createEvent(title: title, startDate: startDate, endDate: response.endDate)
            } else {
                print("❌ Missing title or start date for event creation")
            }
        case .queryEvents:
            print("📋 Loading events")
            loadEvents()
        case .unknown:
            print("❓ Unknown AI response: \(response.message)")
        }
    }
}