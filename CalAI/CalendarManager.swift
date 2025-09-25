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
        print("📅 Requesting iOS Calendar access...")

        // Check current authorization status first
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            print("📅 Current authorization status: \(status.rawValue)")

            switch status {
            case .fullAccess:
                print("✅ Already have full calendar access")
                hasCalendarAccess = true
                loadEvents()
                return
            case .authorized:
                print("✅ Already have calendar access")
                hasCalendarAccess = true
                loadEvents()
                return
            case .denied, .restricted:
                print("❌ Calendar access denied or restricted")
                hasCalendarAccess = false
                return
            case .notDetermined:
                print("📅 Authorization not determined, requesting access...")
            case .writeOnly:
                print("⚠️ Have write-only access, requesting full access...")
            @unknown default:
                print("❓ Unknown authorization status")
            }

            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    print("📅 iOS Calendar access granted: \(granted)")
                    if let error = error {
                        print("❌ iOS Calendar access error: \(error.localizedDescription)")
                    }
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadEvents()
                    } else {
                        print("❌ Calendar access denied")
                    }
                }
            }
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            print("📅 Current authorization status: \(status.rawValue)")

            switch status {
            case .authorized:
                print("✅ Already have calendar access")
                hasCalendarAccess = true
                loadEvents()
                return
            case .denied, .restricted:
                print("❌ Calendar access denied or restricted")
                hasCalendarAccess = false
                return
            case .notDetermined:
                print("📅 Authorization not determined, requesting access...")
            default:
                print("❓ Unknown authorization status")
            }

            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    print("📅 iOS Calendar access granted: \(granted)")
                    if let error = error {
                        print("❌ iOS Calendar access error: \(error.localizedDescription)")
                    }
                    self?.hasCalendarAccess = granted
                    if granted {
                        self?.loadEvents()
                    } else {
                        print("❌ Calendar access denied")
                    }
                }
            }
        }
    }

    func loadEvents() {
        print("📅 loadEvents called, hasCalendarAccess: \(hasCalendarAccess)")
        guard hasCalendarAccess else {
            print("❌ No calendar access, cannot load events")
            return
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        print("📅 Loading iOS events from \(startDate) to \(endDate)")

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)

        print("📅 Found \(fetchedEvents.count) iOS Calendar events")

        DispatchQueue.main.async {
            self.events = fetchedEvents.sorted { $0.startDate < $1.startDate }
            print("📅 Sorted \(self.events.count) iOS events, now loading unified events")
            self.loadAllUnifiedEvents()
        }
    }

    func loadAllUnifiedEvents() {
        print("📅 loadAllUnifiedEvents called")
        var allEvents: [UnifiedEvent] = []

        // Add iOS events
        print("📅 Converting \(events.count) iOS events to unified events")
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
        print("📱 Added \(iosEvents.count) iOS events to unified list")

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

        print("📅 Event details: \(title) from \(startDate) to \(event.endDate ?? startDate)")

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

    func createSampleEvents() {
        print("📅 Creating sample iOS Calendar events for testing...")
        guard hasCalendarAccess else {
            print("❌ No calendar access to create sample events")
            return
        }

        let calendar = Calendar.current
        let today = Date()

        // Sample event 1: Today
        let event1 = EKEvent(eventStore: eventStore)
        event1.title = "Sample iOS Event - Today"
        event1.startDate = calendar.date(byAdding: .hour, value: 2, to: today) ?? today
        event1.endDate = calendar.date(byAdding: .hour, value: 3, to: today) ?? today
        event1.location = "Conference Room A"
        event1.notes = "This is a sample iOS calendar event created by CalAI for testing"
        event1.calendar = eventStore.defaultCalendarForNewEvents

        // Sample event 2: Tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let event2 = EKEvent(eventStore: eventStore)
        event2.title = "Sample iOS Event - Tomorrow"
        event2.startDate = calendar.date(byAdding: .hour, value: 10, to: calendar.startOfDay(for: tomorrow)) ?? tomorrow
        event2.endDate = calendar.date(byAdding: .hour, value: 11, to: calendar.startOfDay(for: tomorrow)) ?? tomorrow
        event2.location = "Meeting Room B"
        event2.notes = "Another sample iOS calendar event"
        event2.calendar = eventStore.defaultCalendarForNewEvents

        // Sample event 3: All-day event
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let event3 = EKEvent(eventStore: eventStore)
        event3.title = "All-Day iOS Event"
        event3.startDate = calendar.startOfDay(for: dayAfterTomorrow)
        event3.endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dayAfterTomorrow)) ?? dayAfterTomorrow
        event3.isAllDay = true
        event3.notes = "Sample all-day iOS calendar event"
        event3.calendar = eventStore.defaultCalendarForNewEvents

        let sampleEvents = [event1, event2, event3]

        for (index, event) in sampleEvents.enumerated() {
            do {
                try eventStore.save(event, span: .thisEvent)
                print("✅ Created sample event \(index + 1): \(event.title ?? "Untitled")")
            } catch {
                print("❌ Error creating sample event \(index + 1): \(error.localizedDescription)")
            }
        }

        // Reload events after creating samples
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadEvents()
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