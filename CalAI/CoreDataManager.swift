import Foundation
import CoreData
import Combine
import EventKit

enum SyncStatus: String, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case failed = "failed"
    case deleted = "deleted"
}

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    @Published var isInitialized = false

    private init() {
        setupCoreData()
    }

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CalAIDataModel")

        // Configure for better performance
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("❌ Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data failed to load: \(error)")
            } else {
                print("✅ Core Data loaded successfully")
                DispatchQueue.main.async {
                    self?.isInitialized = true
                }
            }
        }

        // Enable automatic merging from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Core Data Setup

    private func setupCoreData() {
        // Initialize the persistent container
        _ = persistentContainer
    }

    // MARK: - Save Operations

    func save() {
        guard context.hasChanges else { return }

        do {
            try context.save()
            print("✅ Core Data context saved successfully")
        } catch {
            print("❌ Failed to save Core Data context: \(error)")
            // In production, you might want to handle this more gracefully
            context.rollback()
        }
    }

    func saveBackgroundContext(_ backgroundContext: NSManagedObjectContext) {
        guard backgroundContext.hasChanges else { return }

        backgroundContext.performAndWait {
            do {
                try backgroundContext.save()
                print("✅ Background Core Data context saved successfully")
            } catch {
                print("❌ Failed to save background Core Data context: \(error)")
                backgroundContext.rollback()
            }
        }
    }

    // MARK: - Event Operations

    func saveEvent(_ unifiedEvent: UnifiedEvent, syncStatus: SyncStatus = .synced) {
        let backgroundContext = self.backgroundContext

        backgroundContext.perform {
            // Check if event already exists
            let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
            request.predicate = NSPredicate(format: "eventId == %@ AND source == %@",
                                          unifiedEvent.id, unifiedEvent.source.rawValue)

            do {
                let existingEvents = try backgroundContext.fetch(request)
                let cachedEvent: CachedEvent

                if let existing = existingEvents.first {
                    cachedEvent = existing
                    print("📝 Updating existing cached event: \(unifiedEvent.title)")
                } else {
                    cachedEvent = CachedEvent(context: backgroundContext)
                    print("📝 Creating new cached event: \(unifiedEvent.title)")
                }

                // Update the cached event with unified event data
                cachedEvent.eventId = unifiedEvent.id
                cachedEvent.title = unifiedEvent.title
                cachedEvent.startDate = unifiedEvent.startDate
                cachedEvent.endDate = unifiedEvent.endDate
                cachedEvent.location = unifiedEvent.location
                cachedEvent.eventDescription = unifiedEvent.description
                cachedEvent.isAllDay = unifiedEvent.isAllDay
                cachedEvent.source = unifiedEvent.source.rawValue
                cachedEvent.organizer = unifiedEvent.organizer
                cachedEvent.calendarId = self.extractCalendarId(from: unifiedEvent)
                cachedEvent.syncStatus = syncStatus.rawValue
                cachedEvent.lastModified = Date()

                self.saveBackgroundContext(backgroundContext)

            } catch {
                print("❌ Failed to save event to Core Data: \(error)")
            }
        }
    }

    func saveEvents(_ events: [UnifiedEvent], syncStatus: SyncStatus = .synced) {
        let backgroundContext = self.backgroundContext

        backgroundContext.perform {
            for event in events {
                // Check if event already exists
                let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
                request.predicate = NSPredicate(format: "eventId == %@ AND source == %@",
                                              event.id, event.source.rawValue)

                do {
                    let existingEvents = try backgroundContext.fetch(request)
                    let cachedEvent: CachedEvent

                    if let existing = existingEvents.first {
                        cachedEvent = existing
                    } else {
                        cachedEvent = CachedEvent(context: backgroundContext)
                    }

                    // Update the cached event
                    cachedEvent.eventId = event.id
                    cachedEvent.title = event.title
                    cachedEvent.startDate = event.startDate
                    cachedEvent.endDate = event.endDate
                    cachedEvent.location = event.location
                    cachedEvent.eventDescription = event.description
                    cachedEvent.isAllDay = event.isAllDay
                    cachedEvent.source = event.source.rawValue
                    cachedEvent.organizer = event.organizer
                    cachedEvent.calendarId = self.extractCalendarId(from: event)
                    cachedEvent.syncStatus = syncStatus.rawValue
                    cachedEvent.lastModified = Date()

                } catch {
                    print("❌ Failed to process event for Core Data: \(error)")
                }
            }

            self.saveBackgroundContext(backgroundContext)
            print("✅ Saved \(events.count) events to Core Data")
        }
    }

    func fetchEvents(for source: CalendarSource? = nil,
                    from startDate: Date? = nil,
                    to endDate: Date? = nil) -> [UnifiedEvent] {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        var predicates: [NSPredicate] = []

        // Filter by source if specified
        if let source = source {
            predicates.append(NSPredicate(format: "source == %@", source.rawValue))
        }

        // Filter by date range if specified
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "endDate >= %@", startDate as NSDate))
        }

        if let endDate = endDate {
            predicates.append(NSPredicate(format: "startDate <= %@", endDate as NSDate))
        }

        // Exclude deleted events
        predicates.append(NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue))

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // Sort by start date
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedEvent.startDate, ascending: true)]

        do {
            let cachedEvents = try context.fetch(request)
            let unifiedEvents = cachedEvents.compactMap { convertToUnifiedEvent($0) }
            print("📱 Fetched \(unifiedEvents.count) cached events from Core Data")
            return unifiedEvents
        } catch {
            print("❌ Failed to fetch events from Core Data: \(error)")
            return []
        }
    }

    func deleteEvent(eventId: String, source: CalendarSource) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "eventId == %@ AND source == %@",
                                      eventId, source.rawValue)

        do {
            let events = try context.fetch(request)
            for event in events {
                event.syncStatus = SyncStatus.deleted.rawValue
                event.lastModified = Date()
            }
            save()
            print("✅ Marked event as deleted in Core Data: \(eventId)")
        } catch {
            print("❌ Failed to delete event from Core Data: \(error)")
        }
    }

    func permanentlyDeleteEvent(eventId: String, source: CalendarSource) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "eventId == %@ AND source == %@",
                                      eventId, source.rawValue)

        do {
            let events = try context.fetch(request)
            for event in events {
                context.delete(event)
            }
            save()
            print("✅ Permanently deleted event from Core Data: \(eventId)")
        } catch {
            print("❌ Failed to permanently delete event from Core Data: \(error)")
        }
    }

    // MARK: - Real-time Sync Support

    func enableRemoteChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }

    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context != self.context else { return }

        DispatchQueue.main.async {
            self.context.mergeChanges(fromContextDidSave: notification)
            print("🔄 Merged remote changes into main context")
        }
    }

    func getChangesSince(lastSyncDate: Date, for source: CalendarSource) -> [UnifiedEvent] {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "source == %@ AND lastModified > %@",
            source.rawValue,
            lastSyncDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedEvent.lastModified, ascending: true)]

        do {
            let changedEvents = try context.fetch(request)
            return changedEvents.compactMap { convertToUnifiedEvent($0) }
        } catch {
            print("❌ Failed to fetch changed events: \(error)")
            return []
        }
    }

    func markEventForSync(_ event: UnifiedEvent, syncStatus: SyncStatus) {
        saveEvent(event, syncStatus: syncStatus)
    }

    // MARK: - Sync Status Operations

    func updateSyncStatus(for source: CalendarSource, lastSyncDate: Date, syncToken: String? = nil) {
        let request: NSFetchRequest<CalendarSyncStatus> = CalendarSyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source.rawValue)

        do {
            let existingStatus = try context.fetch(request)
            let syncStatus: CalendarSyncStatus

            if let existing = existingStatus.first {
                syncStatus = existing
            } else {
                syncStatus = CalendarSyncStatus(context: context)
                syncStatus.source = source.rawValue
            }

            syncStatus.lastSyncDate = lastSyncDate
            syncStatus.syncToken = syncToken

            save()
            print("✅ Updated sync status for \(source.rawValue)")
        } catch {
            print("❌ Failed to update sync status: \(error)")
        }
    }

    func getLastSyncDate(for source: CalendarSource) -> Date? {
        let request: NSFetchRequest<CalendarSyncStatus> = CalendarSyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source.rawValue)

        do {
            let syncStatuses = try context.fetch(request)
            return syncStatuses.first?.lastSyncDate
        } catch {
            print("❌ Failed to get last sync date: \(error)")
            return nil
        }
    }

    func getSyncToken(for source: CalendarSource) -> String? {
        let request: NSFetchRequest<CalendarSyncStatus> = CalendarSyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", source.rawValue)

        do {
            let syncStatuses = try context.fetch(request)
            return syncStatuses.first?.syncToken
        } catch {
            print("❌ Failed to get sync token: \(error)")
            return nil
        }
    }

    // MARK: - Helper Methods

    private func convertToUnifiedEvent(_ cachedEvent: CachedEvent) -> UnifiedEvent? {
        guard let eventId = cachedEvent.eventId,
              let title = cachedEvent.title,
              let startDate = cachedEvent.startDate,
              let endDate = cachedEvent.endDate,
              let sourceString = cachedEvent.source,
              let source = CalendarSource(rawValue: sourceString) else {
            print("❌ Invalid cached event data")
            return nil
        }

        return UnifiedEvent(
            id: eventId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: cachedEvent.location,
            description: cachedEvent.eventDescription,
            isAllDay: cachedEvent.isAllDay,
            source: source,
            organizer: cachedEvent.organizer,
            originalEvent: cachedEvent // Use the Core Data object as the original event
        )
    }

    private func extractCalendarId(from unifiedEvent: UnifiedEvent) -> String? {
        // Extract calendar ID based on the event source
        switch unifiedEvent.source {
        case .ios:
            if let ekEvent = unifiedEvent.originalEvent as? EKEvent {
                return ekEvent.calendar?.calendarIdentifier
            }
        case .google:
            if let googleEvent = unifiedEvent.originalEvent as? GoogleEvent {
                return googleEvent.calendarId
            }
        case .outlook:
            if let outlookEvent = unifiedEvent.originalEvent as? OutlookEvent {
                return outlookEvent.calendarId
            }
        }
        return nil
    }

    // MARK: - Cleanup Operations

    func cleanupOldEvents(olderThan date: Date) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "endDate < %@ AND syncStatus == %@",
                                      date as NSDate, SyncStatus.synced.rawValue)

        do {
            let oldEvents = try context.fetch(request)
            for event in oldEvents {
                context.delete(event)
            }
            save()
            print("✅ Cleaned up \(oldEvents.count) old events from Core Data")
        } catch {
            print("❌ Failed to cleanup old events: \(error)")
        }
    }

    func getPendingSyncEvents(for source: CalendarSource) -> [UnifiedEvent] {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@ AND syncStatus == %@",
                                      source.rawValue, SyncStatus.pending.rawValue)

        do {
            let cachedEvents = try context.fetch(request)
            return cachedEvents.compactMap { convertToUnifiedEvent($0) }
        } catch {
            print("❌ Failed to fetch pending sync events: \(error)")
            return []
        }
    }
}

// MARK: - CalendarSource Extension

extension CalendarSource {
    var rawValue: String {
        switch self {
        case .ios: return "ios"
        case .google: return "google"
        case .outlook: return "outlook"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "ios": self = .ios
        case "google": self = .google
        case "outlook": self = .outlook
        default: return nil
        }
    }
}