import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var hasCalendarAccess = false

    private let eventStore = EKEventStore()

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