import Foundation
import EventKit
@testable import CalAI

/// Mock EventKit event store for testing calendar operations
class MockEventStore: EKEventStore {

    // MARK: - Mock State

    var events: [EKEvent] = []
    var calendars: [EKCalendar] = []
    var authorizationStatus: EKAuthorizationStatus = .authorized
    var shouldFailSave: Bool = false
    var shouldFailRemove: Bool = false
    var shouldFailFetch: Bool = false

    // MARK: - Call Tracking

    var requestAccessCalled = false
    var fetchEventsCalled = false
    var saveCalled = false
    var removeCalled = false
    var calendarsCalled = false

    var lastSaveCommit: Bool?
    var lastRemovedEvent: EKEvent?
    var lastFetchPredicate: NSPredicate?

    // MARK: - Override Authorization

    override func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        return authorizationStatus
    }

    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        requestAccessCalled = true
        return authorizationStatus == .authorized
    }

    // MARK: - Override Calendar Access

    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        calendarsCalled = true
        return calendars
    }

    override func defaultCalendarForNewEvents() -> EKCalendar? {
        return calendars.first
    }

    // MARK: - Override Event Fetching

    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        fetchEventsCalled = true
        lastFetchPredicate = predicate

        if shouldFailFetch {
            return []
        }

        return events
    }

    override func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        // Return a mock predicate that we can track
        let predicate = NSPredicate(format: "startDate >= %@ AND endDate <= %@", startDate as NSDate, endDate as NSDate)
        return predicate
    }

    // MARK: - Override Event Modification

    override func save(_ event: EKEvent, span: EKSpan, commit: Bool = true) throws {
        saveCalled = true
        lastSaveCommit = commit

        if shouldFailSave {
            throw MockEventStoreError.saveFailed
        }

        // Add to events array if not already there
        if !events.contains(where: { $0.eventIdentifier == event.eventIdentifier }) {
            events.append(event)
        }
    }

    override func remove(_ event: EKEvent, span: EKSpan, commit: Bool = true) throws {
        removeCalled = true
        lastRemovedEvent = event
        lastSaveCommit = commit

        if shouldFailRemove {
            throw MockEventStoreError.removeFailed
        }

        // Remove from events array
        events.removeAll { $0.eventIdentifier == event.eventIdentifier }
    }

    // MARK: - Helper Methods

    func reset() {
        events.removeAll()
        calendars.removeAll()
        authorizationStatus = .authorized
        shouldFailSave = false
        shouldFailRemove = false
        shouldFailFetch = false

        requestAccessCalled = false
        fetchEventsCalled = false
        saveCalled = false
        removeCalled = false
        calendarsCalled = false

        lastSaveCommit = nil
        lastRemovedEvent = nil
        lastFetchPredicate = nil
    }

    func addMockEvents(_ mockEvents: [EKEvent]) {
        events.append(contentsOf: mockEvents)
    }

    func addMockCalendars(_ mockCalendars: [EKCalendar]) {
        calendars.append(contentsOf: mockCalendars)
    }
}

// MARK: - Mock Errors

enum MockEventStoreError: Error {
    case saveFailed
    case removeFailed
    case fetchFailed
    case unauthorized
}
