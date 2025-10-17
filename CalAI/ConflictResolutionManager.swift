import Foundation
import SwiftUI

class ConflictResolutionManager: ObservableObject {
    static let shared = ConflictResolutionManager()

    @Published var pendingConflicts: [EventConflict] = []
    @Published var showingConflictDialog = false

    private let coreDataManager = CoreDataManager.shared

    private init() {}

    // MARK: - Conflict Detection

    func detectConflicts(for event: UnifiedEvent) -> [EventConflict] {
        var conflicts: [EventConflict] = []

        // Check for timing conflicts
        let overlappingEvents = findOverlappingEvents(for: event)
        if !overlappingEvents.isEmpty {
            let conflict = EventConflict(
                type: .timeOverlap,
                primaryEvent: event,
                conflictingEvents: overlappingEvents,
                detectedAt: Date()
            )
            conflicts.append(conflict)
        }

        // Check for duplicate events
        let duplicates = findDuplicateEvents(for: event)
        if !duplicates.isEmpty {
            let conflict = EventConflict(
                type: .duplicate,
                primaryEvent: event,
                conflictingEvents: duplicates,
                detectedAt: Date()
            )
            conflicts.append(conflict)
        }

        // Check for simultaneous edits
        if let editConflict = detectSimultaneousEdit(for: event) {
            conflicts.append(editConflict)
        }

        return conflicts
    }

    private func findOverlappingEvents(for event: UnifiedEvent) -> [UnifiedEvent] {
        let allEvents = coreDataManager.fetchEvents()

        return allEvents.filter { existingEvent in
            existingEvent.id != event.id &&
            existingEvent.source == event.source &&
            eventsOverlap(event, existingEvent)
        }
    }

    private func findDuplicateEvents(for event: UnifiedEvent) -> [UnifiedEvent] {
        let allEvents = coreDataManager.fetchEvents()

        return allEvents.filter { existingEvent in
            existingEvent.id != event.id &&
            isDuplicate(event, existingEvent)
        }
    }

    private func detectSimultaneousEdit(for event: UnifiedEvent) -> EventConflict? {
        // Get cached version of the event
        let cachedEvents = coreDataManager.fetchEvents(for: event.source)
        guard let cachedEvent = cachedEvents.first(where: { $0.id == event.id }),
              let cachedData = cachedEvent.originalEvent as? CachedEvent,
              let lastModified = cachedData.lastModified else {
            return nil
        }

        // Check if event was modified recently by another source
        let timeDiff = Date().timeIntervalSince(lastModified)
        if timeDiff < 300 { // Modified within last 5 minutes
            return EventConflict(
                type: .simultaneousEdit,
                primaryEvent: event,
                conflictingEvents: [cachedEvent],
                detectedAt: Date(),
                metadata: ["lastModified": lastModified]
            )
        }

        return nil
    }

    // MARK: - Conflict Resolution

    func resolveConflict(_ conflict: EventConflict, resolution: ConflictResolutionStrategy) {
        print("🔧 Resolving conflict: \(conflict.type) with strategy: \(resolution)")

        switch resolution {
        case .useLocal:
            applyLocalVersion(conflict)
        case .useRemote:
            applyRemoteVersion(conflict)
        case .merge:
            mergeVersions(conflict)
        case .createSeparate:
            createSeparateEvents(conflict)
        case .skip:
            skipConflict(conflict)
        }

        // Remove resolved conflict
        pendingConflicts.removeAll { $0.id == conflict.id }
    }

    private func applyLocalVersion(_ conflict: EventConflict) {
        // Keep local version, mark remote as resolved
        coreDataManager.markEventForSync(conflict.primaryEvent, syncStatus: .synced)
        print("✅ Applied local version for event: \(conflict.primaryEvent.title)")
    }

    private func applyRemoteVersion(_ conflict: EventConflict) {
        // Replace local with remote version
        if let remoteEvent = conflict.conflictingEvents.first {
            coreDataManager.saveEvent(remoteEvent, syncStatus: .synced)
            print("✅ Applied remote version for event: \(remoteEvent.title)")
        }
    }

    private func mergeVersions(_ conflict: EventConflict) {
        guard let remoteEvent = conflict.conflictingEvents.first else { return }

        let mergedEvent = createMergedEvent(
            local: conflict.primaryEvent,
            remote: remoteEvent
        )

        coreDataManager.saveEvent(mergedEvent, syncStatus: .synced)
        print("✅ Merged versions for event: \(mergedEvent.title)")
    }

    private func createSeparateEvents(_ conflict: EventConflict) {
        // Keep both events as separate entries
        coreDataManager.markEventForSync(conflict.primaryEvent, syncStatus: .synced)

        for conflictingEvent in conflict.conflictingEvents {
            let renamedEvent = UnifiedEvent(
                id: UUID().uuidString,
                title: "\(conflictingEvent.title) (Conflict Copy)",
                startDate: conflictingEvent.startDate,
                endDate: conflictingEvent.endDate,
                location: conflictingEvent.location,
                description: conflictingEvent.description,
                isAllDay: conflictingEvent.isAllDay,
                source: conflictingEvent.source,
                organizer: conflictingEvent.organizer,
                originalEvent: conflictingEvent.originalEvent,
                calendarId: conflictingEvent.calendarId,
                calendarName: conflictingEvent.calendarName,
                calendarColor: conflictingEvent.calendarColor
            )
            coreDataManager.saveEvent(renamedEvent, syncStatus: .synced)
        }

        print("✅ Created separate events for conflict")
    }

    private func skipConflict(_ conflict: EventConflict) {
        // Mark conflict as resolved without changes
        print("⏭️ Skipped conflict for event: \(conflict.primaryEvent.title)")
    }

    // MARK: - Helper Methods

    private func eventsOverlap(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }

    private func isDuplicate(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        return event1.title == event2.title &&
               Calendar.current.isDate(event1.startDate, equalTo: event2.startDate, toGranularity: .minute) &&
               Calendar.current.isDate(event1.endDate, equalTo: event2.endDate, toGranularity: .minute)
    }

    private func createMergedEvent(local: UnifiedEvent, remote: UnifiedEvent) -> UnifiedEvent {
        // Smart merge strategy - prefer non-empty fields
        return UnifiedEvent(
            id: local.id,
            title: !local.title.isEmpty ? local.title : remote.title,
            startDate: local.startDate, // Prefer local timing
            endDate: local.endDate,
            location: local.location?.isEmpty == false ? local.location : remote.location,
            description: local.description?.isEmpty == false ? local.description : remote.description,
            isAllDay: local.isAllDay,
            source: local.source,
            organizer: local.organizer?.isEmpty == false ? local.organizer : remote.organizer,
            originalEvent: local.originalEvent,
            calendarId: local.calendarId,
            calendarName: local.calendarName,
            calendarColor: local.calendarColor
        )
    }

    // MARK: - Auto-Resolution

    func enableAutoResolution() {
        print("🤖 Enabling automatic conflict resolution")
        // Implement smart auto-resolution rules here
    }

    func getAutoResolutionStrategy(for conflict: EventConflict) -> ConflictResolutionStrategy? {
        switch conflict.type {
        case .duplicate:
            // Auto-resolve duplicates by using the newer version
            return .useRemote
        case .timeOverlap:
            // Don't auto-resolve time conflicts - require user input
            return nil
        case .simultaneousEdit:
            // Auto-merge if changes are compatible
            return .merge
        }
    }

    // MARK: - UI Support

    func presentConflictResolution(for conflicts: [EventConflict]) {
        pendingConflicts.append(contentsOf: conflicts)
        if !conflicts.isEmpty {
            showingConflictDialog = true
        }
    }
}

// MARK: - Supporting Types

struct EventConflict: Identifiable {
    let id = UUID()
    let type: ConflictType
    let primaryEvent: UnifiedEvent
    let conflictingEvents: [UnifiedEvent]
    let detectedAt: Date
    var metadata: [String: Any] = [:]

    enum ConflictType {
        case duplicate
        case timeOverlap
        case simultaneousEdit
    }
}

enum ConflictResolutionStrategy {
    case useLocal
    case useRemote
    case merge
    case createSeparate
    case skip
}

// Note: ConflictResolutionView is defined in Features/Events/Views/ConflictResolutionView.swift