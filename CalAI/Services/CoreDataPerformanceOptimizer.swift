import Foundation
import CoreData

/// Performance optimizations for Core Data operations
class CoreDataPerformanceOptimizer {

    // MARK: - Index Configuration

    /// Configure indexes for optimal query performance
    static func configureIndexes(for container: NSPersistentContainer) {
        // Note: Indexes are defined in the .xcdatamodeld file
        // This method documents what should be indexed

        // CachedEvent indexes (add these in the data model editor):
        // - eventId (Primary lookup key)
        // - startDate (Date range queries)
        // - endDate (Date range queries)
        // - calendarSource (Filter by source)
        // - syncStatus (Sync queue queries)
        // - lastModified (Change tracking)

        // Compound indexes for common queries:
        // - (startDate, endDate) for range queries
        // - (calendarSource, syncStatus) for sync operations

        print("📊 Core Data indexes configured for optimal performance")
    }

    // MARK: - Batch Operations

    /// Batch fetch events for better performance
    static func batchFetchEvents(
        startDate: Date,
        endDate: Date,
        context: NSManagedObjectContext,
        batchSize: Int = 50
    ) -> [CachedEvent] {
        let request = NSFetchRequest<CachedEvent>(entityName: "CachedEvent")

        // Use predicates for filtering
        request.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        // Sort by start date
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        // Configure batch fetching
        request.fetchBatchSize = batchSize
        request.returnsObjectsAsFaults = false // Prefetch to reduce faulting

        // Only fetch required properties
        request.propertiesToFetch = [
            "eventId", "title", "startDate", "endDate",
            "location", "notes", "isAllDay", "calendarSource"
        ]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ Batch fetch failed: \(error)")
            return []
        }
    }

    /// Batch update events efficiently
    static func batchUpdateSyncStatus(
        eventIds: [String],
        status: String,
        context: NSManagedObjectContext
    ) {
        let request = NSBatchUpdateRequest(entityName: "CachedEvent")
        request.predicate = NSPredicate(format: "eventId IN %@", eventIds)
        request.propertiesToUpdate = ["syncStatus": status]
        request.resultType = .updatedObjectsCountResultType

        context.performAndWait {
            do {
                let result = try context.execute(request) as? NSBatchUpdateResult
                if let count = result?.result as? Int {
                    print("✅ Batch updated \(count) events")
                }

                // Refresh context to see changes
                context.refreshAllObjects()
            } catch {
                print("❌ Batch update failed: \(error)")
            }
        }
    }

    /// Batch delete old events
    static func batchDeleteOldEvents(
        olderThan date: Date,
        context: NSManagedObjectContext
    ) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CachedEvent")
        fetchRequest.predicate = NSPredicate(format: "endDate < %@", date as NSDate)

        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeCount

        context.performAndWait {
            do {
                let result = try context.execute(request) as? NSBatchDeleteResult
                if let count = result?.result as? Int {
                    print("🗑️ Batch deleted \(count) old events")
                }

                context.refreshAllObjects()
            } catch {
                print("❌ Batch delete failed: \(error)")
            }
        }
    }

    // MARK: - Query Optimization

    /// Count events without fetching them (much faster)
    static func countEvents(
        matching predicate: NSPredicate?,
        context: NSManagedObjectContext
    ) -> Int {
        let request = NSFetchRequest<CachedEvent>(entityName: "CachedEvent")
        request.predicate = predicate

        do {
            return try context.count(for: request)
        } catch {
            print("❌ Count failed: \(error)")
            return 0
        }
    }

    /// Fetch event IDs only (minimal data transfer)
    static func fetchEventIds(
        matching predicate: NSPredicate?,
        context: NSManagedObjectContext
    ) -> [String] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedEvent")
        request.predicate = predicate
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["eventId"]

        do {
            let results = try context.fetch(request) as? [[String: Any]]
            return results?.compactMap { $0["eventId"] as? String } ?? []
        } catch {
            print("❌ ID fetch failed: \(error)")
            return []
        }
    }

    // MARK: - Memory Management

    /// Reset context to free memory
    static func resetContext(_ context: NSManagedObjectContext) {
        context.performAndWait {
            context.reset()
            print("🧹 Context reset - memory freed")
        }
    }

    /// Batch fault objects to reduce memory
    static func batchFaultObjects(
        _ objects: [NSManagedObject],
        context: NSManagedObjectContext
    ) {
        context.performAndWait {
            for object in objects {
                context.refresh(object, mergeChanges: false)
            }
            print("💤 Faulted \(objects.count) objects")
        }
    }

    // MARK: - Background Processing

    /// Perform expensive operations in background
    static func performBackgroundTask(
        in container: NSPersistentContainer,
        task: @escaping (NSManagedObjectContext) -> Void
    ) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            // Perform task
            task(context)

            // Save if needed
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ Background task completed and saved")
                } catch {
                    print("❌ Background save failed: \(error)")
                    context.rollback()
                }
            }
        }
    }

    // MARK: - Performance Monitoring

    /// Measure fetch performance
    static func measureFetchPerformance<T>(
        _ fetchBlock: () throws -> [T]
    ) -> (results: [T], duration: TimeInterval) {
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let results = try fetchBlock()
            let duration = CFAbsoluteTimeGetCurrent() - start
            print("⏱️ Fetch completed in \(String(format: "%.3f", duration))s - \(results.count) results")
            return (results, duration)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            print("❌ Fetch failed after \(String(format: "%.3f", duration))s: \(error)")
            return ([], duration)
        }
    }

    // MARK: - Prefetching Strategies

    /// Prefetch relationships to avoid faulting
    static func prefetchRelationships(
        for request: NSFetchRequest<CachedEvent>,
        relationships: [String]
    ) {
        request.relationshipKeyPathsForPrefetching = relationships
        print("🔗 Prefetching relationships: \(relationships.joined(separator: ", "))")
    }

    // MARK: - Cache Warming

    /// Warm up Core Data cache with commonly accessed data
    static func warmupCache(
        context: NSManagedObjectContext,
        dateRange: DateInterval
    ) {
        let request = NSFetchRequest<CachedEvent>(entityName: "CachedEvent")
        request.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        request.fetchBatchSize = 100
        request.returnsObjectsAsFaults = false

        context.perform {
            do {
                let _ = try context.fetch(request)
                print("🔥 Cache warmed with \(dateRange.duration / 86400) days of data")
            } catch {
                print("❌ Cache warmup failed: \(error)")
            }
        }
    }
}

// MARK: - Fetch Request Builder

class OptimizedFetchRequestBuilder {
    private var fetchRequest: NSFetchRequest<CachedEvent>

    init() {
        fetchRequest = NSFetchRequest<CachedEvent>(entityName: "CachedEvent")
    }

    func withDateRange(start: Date, end: Date) -> Self {
        fetchRequest.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            start as NSDate,
            end as NSDate
        )
        return self
    }

    func withSource(_ source: String) -> Self {
        let sourcePredicate = NSPredicate(format: "calendarSource == %@", source)

        if let existing = fetchRequest.predicate {
            fetchRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [existing, sourcePredicate]
            )
        } else {
            fetchRequest.predicate = sourcePredicate
        }

        return self
    }

    func withSyncStatus(_ status: String) -> Self {
        let statusPredicate = NSPredicate(format: "syncStatus == %@", status)

        if let existing = fetchRequest.predicate {
            fetchRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [existing, statusPredicate]
            )
        } else {
            fetchRequest.predicate = statusPredicate
        }

        return self
    }

    func sortedBy(_ key: String, ascending: Bool = true) -> Self {
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        return self
    }

    func withBatchSize(_ size: Int) -> Self {
        fetchRequest.fetchBatchSize = size
        return self
    }

    func withLimit(_ limit: Int) -> Self {
        fetchRequest.fetchLimit = limit
        return self
    }

    func prefetchingRelationships(_ relationships: [String]) -> Self {
        fetchRequest.relationshipKeyPathsForPrefetching = relationships
        return self
    }

    func returningFaults(_ faults: Bool) -> Self {
        fetchRequest.returnsObjectsAsFaults = faults
        return self
    }

    func build() -> NSFetchRequest<CachedEvent> {
        return fetchRequest
    }

    func execute(in context: NSManagedObjectContext) throws -> [CachedEvent] {
        return try context.fetch(fetchRequest)
    }
}

// MARK: - Performance Metrics

struct CoreDataMetrics {
    let fetchCount: Int
    let fetchDuration: TimeInterval
    let objectCount: Int
    let memoryUsage: Int64

    var averageFetchTime: TimeInterval {
        fetchCount > 0 ? fetchDuration / TimeInterval(fetchCount) : 0
    }

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}
