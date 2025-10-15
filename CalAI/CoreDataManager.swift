import Foundation
import CoreData
import Combine
import EventKit

// In-file definition to solve compiler scope issues
@objc(LoggedUserAction)
public class LoggedUserAction: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LoggedUserAction> {
        return NSFetchRequest<LoggedUserAction>(entityName: "LoggedUserAction")
    }

    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var actionType: String
    @NSManaged public var eventID: String?
    @NSManaged public var eventTitle: String?
    @NSManaged public var eventDuration: Double
    @NSManaged public var attendeeCount: Int16
}

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
        let model = CoreDataManager.createManagedObjectModel()
        let container = NSPersistentContainer(name: "CalAIDataModel", managedObjectModel: model)

        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            } else {
                print("✅ Core Data loaded successfully from programmatic model")
                DispatchQueue.main.async {
                    self?.isInitialized = true
                }
            }
        }

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

    // MARK: - Programmatic Model Creation

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let cachedEventEntity = NSEntityDescription()
        cachedEventEntity.name = "CachedEvent"
        cachedEventEntity.managedObjectClassName = "CachedEvent"

        var cachedEventProps: [NSAttributeDescription] = []
        cachedEventProps.append(createAttribute(name: "calendarId", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "endDate", type: .dateAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "eventDescription", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "eventId", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "isAllDay", type: .booleanAttributeType))
        cachedEventProps.append(createAttribute(name: "lastModified", type: .dateAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "location", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "organizer", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "source", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "startDate", type: .dateAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "syncStatus", type: .stringAttributeType, isOptional: true))
        cachedEventProps.append(createAttribute(name: "title", type: .stringAttributeType, isOptional: true))
        cachedEventEntity.properties = cachedEventProps

        let syncStatusEntity = NSEntityDescription()
        syncStatusEntity.name = "CalendarSyncStatus"
        syncStatusEntity.managedObjectClassName = "CalendarSyncStatus"

        var syncStatusProps: [NSAttributeDescription] = []
        syncStatusProps.append(createAttribute(name: "lastSyncDate", type: .dateAttributeType, isOptional: true))
        syncStatusProps.append(createAttribute(name: "source", type: .stringAttributeType, isOptional: true))
        syncStatusProps.append(createAttribute(name: "syncToken", type: .stringAttributeType, isOptional: true))
        syncStatusEntity.properties = syncStatusProps

        let loggedActionEntity = NSEntityDescription()
        loggedActionEntity.name = "LoggedUserAction"
        loggedActionEntity.managedObjectClassName = "LoggedUserAction"

        var loggedActionProps: [NSAttributeDescription] = []
        loggedActionProps.append(createAttribute(name: "id", type: .UUIDAttributeType))
        loggedActionProps.append(createAttribute(name: "timestamp", type: .dateAttributeType))
        loggedActionProps.append(createAttribute(name: "actionType", type: .stringAttributeType))
        loggedActionProps.append(createAttribute(name: "eventID", type: .stringAttributeType, isOptional: true))
        loggedActionProps.append(createAttribute(name: "eventTitle", type: .stringAttributeType, isOptional: true))
        loggedActionProps.append(createAttribute(name: "eventDuration", type: .doubleAttributeType))
        loggedActionProps.append(createAttribute(name: "attendeeCount", type: .integer16AttributeType))
        loggedActionEntity.properties = loggedActionProps

        model.entities = [cachedEventEntity, syncStatusEntity, loggedActionEntity]
        return model
    }

    private static func createAttribute(name: String, type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }

    private func setupCoreData() {
        _ = persistentContainer
    }

    // MARK: - Save Operations

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }

    func saveBackgroundContext(_ backgroundContext: NSManagedObjectContext) {
        guard backgroundContext.hasChanges else { return }
        backgroundContext.performAndWait {
            do {
                try backgroundContext.save()
            } catch {
                backgroundContext.rollback()
            }
        }
    }

    // MARK: - Event Operations

    func saveEvent(_ unifiedEvent: UnifiedEvent, syncStatus: SyncStatus = .synced) {
        let backgroundContext = self.backgroundContext
        backgroundContext.perform {
            let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
            request.predicate = NSPredicate(format: "eventId == %@ AND source == %@", unifiedEvent.id, unifiedEvent.source.rawValue)
            do {
                let existingEvents = try backgroundContext.fetch(request)
                let cachedEvent: CachedEvent
                if let existing = existingEvents.first {
                    cachedEvent = existing
                } else {
                    cachedEvent = CachedEvent(context: backgroundContext)
                    self.logUserAction(actionType: "eventCreated", for: unifiedEvent, in: backgroundContext)
                }

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
                let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
                request.predicate = NSPredicate(format: "eventId == %@ AND source == %@", event.id, event.source.rawValue)
                do {
                    let existingEvents = try backgroundContext.fetch(request)
                    let cachedEvent: CachedEvent
                    if let existing = existingEvents.first {
                        cachedEvent = existing
                    } else {
                        cachedEvent = CachedEvent(context: backgroundContext)
                    }
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
        }
    }

    func fetchEvents(for source: CalendarSource? = nil, from startDate: Date? = nil, to endDate: Date? = nil) -> [UnifiedEvent] {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        var predicates: [NSPredicate] = []
        if let source = source {
            predicates.append(NSPredicate(format: "source == %@", source.rawValue))
        }
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "endDate >= %@", startDate as NSDate))
        }
        if let endDate = endDate {
            predicates.append(NSPredicate(format: "startDate <= %@", endDate as NSDate))
        }
        predicates.append(NSPredicate(format: "syncStatus != %@", SyncStatus.deleted.rawValue))
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedEvent.startDate, ascending: true)]
        do {
            let cachedEvents = try context.fetch(request)
            return cachedEvents.compactMap { convertToUnifiedEvent($0) }
        } catch {
            return []
        }
    }

    func deleteEvent(eventId: String, source: CalendarSource) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "eventId == %@ AND source == %@", eventId, source.rawValue)
        do {
            let events = try context.fetch(request)
            for event in events {
                event.syncStatus = SyncStatus.deleted.rawValue
                event.lastModified = Date()
            }
            save()
        } catch {
            print("❌ Failed to delete event from Core Data: \(error)")
        }
    }

    func permanentlyDeleteEvent(eventId: String, source: CalendarSource) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "eventId == %@ AND source == %@", eventId, source.rawValue)
        do {
            let events = try context.fetch(request)
            for event in events {
                context.delete(event)
            }
            save()
        } catch {
            print("❌ Failed to permanently delete event from Core Data: \(error)")
        }
    }

    // MARK: - Personalization Logging

    func logUserAction(actionType: String, for event: UnifiedEvent, in context: NSManagedObjectContext) {
        let newAction = LoggedUserAction(context: context)
        newAction.id = UUID()
        newAction.timestamp = Date()
        newAction.actionType = actionType
        newAction.eventID = event.id
        newAction.eventTitle = event.title
        newAction.eventDuration = event.endDate.timeIntervalSince(event.startDate)
        if let ekEvent = event.originalEvent as? EKEvent {
            newAction.attendeeCount = Int16(ekEvent.attendees?.count ?? 0)
        } else {
            newAction.attendeeCount = 0
        }
        print("✍️ Logging user action: \(actionType) for event \(event.title ?? "Untitled")")
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
    
    // MARK: - Sync Status Operations

    func markEventForSync(_ event: UnifiedEvent, syncStatus: SyncStatus) {
        saveEvent(event, syncStatus: syncStatus)
    }

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
            return nil
        }
    }

    // MARK: - Helper Methods

    private func convertToUnifiedEvent(_ cachedEvent: CachedEvent) -> UnifiedEvent? {
        guard let eventId = cachedEvent.eventId, let title = cachedEvent.title, let startDate = cachedEvent.startDate, let endDate = cachedEvent.endDate, let sourceString = cachedEvent.source, let source = CalendarSource(rawValue: sourceString) else {
            return nil
        }
        return UnifiedEvent(id: eventId, title: title, startDate: startDate, endDate: endDate, location: cachedEvent.location, description: cachedEvent.eventDescription, isAllDay: cachedEvent.isAllDay, source: source, organizer: cachedEvent.organizer, originalEvent: cachedEvent)
    }

    private func extractCalendarId(from unifiedEvent: UnifiedEvent) -> String? {
        switch unifiedEvent.source {
        case .ios:
            if let ekEvent = unifiedEvent.originalEvent as? EKEvent {
                return ekEvent.calendar?.calendarIdentifier
            }
            return nil
        // Cases for Google/Outlook would be needed here if they have specific originalEvent types
        default:
            return nil
        }
    }

    // MARK: - Cleanup Operations

    func cleanupOldEvents(olderThan date: Date) {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "endDate < %@ AND syncStatus == %@", date as NSDate, SyncStatus.synced.rawValue)
        do {
            let oldEvents = try context.fetch(request)
            for event in oldEvents {
                context.delete(event)
            }
            save()
        } catch {
            print("❌ Failed to cleanup old events: \(error)")
        }
    }

    func getPendingSyncEvents(for source: CalendarSource) -> [UnifiedEvent] {
        let request: NSFetchRequest<CachedEvent> = CachedEvent.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@ AND syncStatus == %@", source.rawValue, SyncStatus.pending.rawValue)
        do {
            let cachedEvents = try context.fetch(request)
            return cachedEvents.compactMap { convertToUnifiedEvent($0) }
        } catch {
            return []
        }
    }
}
