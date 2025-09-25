import Foundation
import Combine
import CryptoKit

class DeltaSyncManager: ObservableObject {
    static let shared = DeltaSyncManager()

    @Published var deltaStats = DeltaSyncStats()

    private let coreDataManager = CoreDataManager.shared
    private var eventHashes: [String: String] = [:] // eventId -> contentHash

    private init() {
        loadEventHashes()
    }

    // MARK: - Delta Sync Operations

    func performDeltaSync(for source: CalendarSource, events: [UnifiedEvent]) {
        let startTime = Date()
        var stats = DeltaSyncStats()

        print("🔄 Starting delta sync for \(source.rawValue)")

        // Calculate deltas
        let delta = calculateDelta(for: events, source: source)

        // Apply changes
        stats.eventsProcessed = events.count
        stats.eventsCreated = delta.created.count
        stats.eventsUpdated = delta.updated.count
        stats.eventsDeleted = delta.deleted.count

        // Process created events
        for event in delta.created {
            coreDataManager.saveEvent(event, syncStatus: .synced)
            updateEventHash(for: event)
            print("➕ Created event: \(event.title)")
        }

        // Process updated events
        for event in delta.updated {
            coreDataManager.saveEvent(event, syncStatus: .synced)
            updateEventHash(for: event)
            print("📝 Updated event: \(event.title)")
        }

        // Process deleted events
        for eventId in delta.deleted {
            coreDataManager.permanentlyDeleteEvent(eventId: eventId, source: source)
            removeEventHash(for: eventId)
            print("🗑️ Deleted event: \(eventId)")
        }

        let processingTime = Date().timeIntervalSince(startTime)
        stats.processingTime = processingTime
        stats.compressionRatio = calculateCompressionRatio(original: events.count, processed: delta.totalChanges)

        DispatchQueue.main.async {
            self.deltaStats = stats
        }

        print("✅ Delta sync completed in \(String(format: "%.2f", processingTime))s")
        print("📊 Changes: +\(stats.eventsCreated) ~\(stats.eventsUpdated) -\(stats.eventsDeleted)")
    }

    private func calculateDelta(for events: [UnifiedEvent], source: CalendarSource) -> SyncDelta {
        let cachedEvents = coreDataManager.fetchEvents(for: source)
        let cachedEventIds = Set(cachedEvents.map { $0.id })
        let incomingEventIds = Set(events.map { $0.id })

        var created: [UnifiedEvent] = []
        var updated: [UnifiedEvent] = []
        var deleted: [String] = []

        // Find created and updated events
        for event in events {
            if let existingHash = eventHashes[event.id] {
                let currentHash = calculateContentHash(for: event)
                if existingHash != currentHash {
                    updated.append(event)
                }
            } else {
                created.append(event)
            }
        }

        // Find deleted events
        for cachedEventId in cachedEventIds {
            if !incomingEventIds.contains(cachedEventId) {
                deleted.append(cachedEventId)
            }
        }

        return SyncDelta(created: created, updated: updated, deleted: deleted)
    }

    // MARK: - Content Hashing

    private func calculateContentHash(for event: UnifiedEvent) -> String {
        let content = "\(event.title)|\(event.startDate.timeIntervalSince1970)|\(event.endDate.timeIntervalSince1970)|\(event.location ?? "")|\(event.description ?? "")|\(event.isAllDay)|\(event.organizer ?? "")"

        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func updateEventHash(for event: UnifiedEvent) {
        let hash = calculateContentHash(for: event)
        eventHashes[event.id] = hash
        saveEventHashes()
    }

    private func removeEventHash(for eventId: String) {
        eventHashes.removeValue(forKey: eventId)
        saveEventHashes()
    }

    // MARK: - Hash Persistence

    private func loadEventHashes() {
        if let data = UserDefaults.standard.data(forKey: "EventHashes"),
           let hashes = try? JSONDecoder().decode([String: String].self, from: data) {
            eventHashes = hashes
        }
    }

    private func saveEventHashes() {
        if let data = try? JSONEncoder().encode(eventHashes) {
            UserDefaults.standard.set(data, forKey: "EventHashes")
        }
    }

    // MARK: - Compression & Optimization

    private func calculateCompressionRatio(original: Int, processed: Int) -> Double {
        guard original > 0 else { return 1.0 }
        return 1.0 - (Double(processed) / Double(original))
    }

    func optimizeSyncPayload(_ events: [UnifiedEvent]) -> OptimizedPayload {
        var payload = OptimizedPayload()

        for event in events {
            let hash = calculateContentHash(for: event)

            if let existingHash = eventHashes[event.id] {
                if existingHash != hash {
                    // Event changed, include only changed fields
                    let changes = calculateFieldChanges(eventId: event.id, newEvent: event)
                    payload.updates[event.id] = changes
                }
            } else {
                // New event, include full data
                payload.creates.append(event)
            }
        }

        return payload
    }

    private func calculateFieldChanges(eventId: String, newEvent: UnifiedEvent) -> [String: Any] {
        var changes: [String: Any] = [:]

        // This would compare against cached version and identify changed fields
        // For now, we'll include all fields for simplicity
        changes["title"] = newEvent.title
        changes["startDate"] = newEvent.startDate
        changes["endDate"] = newEvent.endDate
        changes["location"] = newEvent.location
        changes["description"] = newEvent.description
        changes["isAllDay"] = newEvent.isAllDay
        changes["organizer"] = newEvent.organizer

        return changes
    }

    // MARK: - Batch Operations

    func performBatchDeltaSync(sources: [CalendarSource: [UnifiedEvent]]) async {
        print("🔄 Starting batch delta sync for \(sources.count) sources")

        await withTaskGroup(of: Void.self) { group in
            for (source, events) in sources {
                group.addTask {
                    await MainActor.run {
                        self.performDeltaSync(for: source, events: events)
                    }
                }
            }
        }

        print("✅ Batch delta sync completed")
    }

    // MARK: - Performance Analytics

    func getPerformanceMetrics() -> DeltaPerformanceMetrics {
        return DeltaPerformanceMetrics(
            averageProcessingTime: deltaStats.processingTime,
            compressionRatio: deltaStats.compressionRatio,
            totalEventsCached: eventHashes.count,
            lastSyncTimestamp: Date()
        )
    }

    func resetPerformanceMetrics() {
        deltaStats = DeltaSyncStats()
        eventHashes.removeAll()
        saveEventHashes()
    }
}

// MARK: - Supporting Types

struct SyncDelta {
    let created: [UnifiedEvent]
    let updated: [UnifiedEvent]
    let deleted: [String]

    var totalChanges: Int {
        created.count + updated.count + deleted.count
    }

    var isEmpty: Bool {
        totalChanges == 0
    }
}

struct OptimizedPayload {
    var creates: [UnifiedEvent] = []
    var updates: [String: [String: Any]] = [:] // eventId -> changes
    var deletes: [String] = []

    var totalOperations: Int {
        creates.count + updates.count + deletes.count
    }
}

struct DeltaSyncStats {
    var eventsProcessed: Int = 0
    var eventsCreated: Int = 0
    var eventsUpdated: Int = 0
    var eventsDeleted: Int = 0
    var processingTime: TimeInterval = 0
    var compressionRatio: Double = 0

    var efficiency: Double {
        let totalChanges = eventsCreated + eventsUpdated + eventsDeleted
        guard eventsProcessed > 0 else { return 0 }
        return Double(totalChanges) / Double(eventsProcessed)
    }
}

struct DeltaPerformanceMetrics {
    let averageProcessingTime: TimeInterval
    let compressionRatio: Double
    let totalEventsCached: Int
    let lastSyncTimestamp: Date
}

// MARK: - Extensions

extension SyncManager {
    func performOptimizedSync() async {
        let deltaManager = DeltaSyncManager.shared

        guard let calendarManager = calendarManager else { return }

        // Collect events from all sources
        var sourceEvents: [CalendarSource: [UnifiedEvent]] = [:]

        // iOS Events
        if calendarManager.hasCalendarAccess {
            let iosEvents = calendarManager.events.map { event in
                UnifiedEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.notes,
                    isAllDay: event.isAllDay,
                    source: .ios,
                    organizer: event.organizer?.name,
                    originalEvent: event
                )
            }
            sourceEvents[.ios] = iosEvents
        }

        // Google Events
        if let googleManager = calendarManager.googleCalendarManager, googleManager.isSignedIn {
            let googleEvents = googleManager.googleEvents.map { event in
                UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.description,
                    isAllDay: false,
                    source: .google,
                    organizer: nil,
                    originalEvent: event
                )
            }
            sourceEvents[.google] = googleEvents
        }

        // Outlook Events
        if let outlookManager = calendarManager.outlookCalendarManager, outlookManager.isSignedIn {
            let outlookEvents = outlookManager.outlookEvents.map { event in
                UnifiedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.description,
                    isAllDay: false,
                    source: .outlook,
                    organizer: nil,
                    originalEvent: event
                )
            }
            sourceEvents[.outlook] = outlookEvents
        }

        // Perform batch delta sync
        await deltaManager.performBatchDeltaSync(sources: sourceEvents)

        // Update UI
        await MainActor.run {
            calendarManager.loadAllUnifiedEvents()
        }
    }
}