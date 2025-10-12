import Foundation
import Combine
import BackgroundTasks
import EventKit

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [CalendarSyncError] = []

    let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?

    // Calendar managers will be injected
    weak var calendarManager: CalendarManager?

    private init() {
        setupBackgroundSync()
        coreDataManager.enableRemoteChangeNotifications()
    }

    // MARK: - Real-time Sync

    func startRealTimeSync(interval: TimeInterval = 300) { // 5 minutes
        print("🔄 Starting real-time sync with \(interval)s interval")

        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }

        // Initial sync
        Task {
            await performIncrementalSync()
        }
    }

    func stopRealTimeSync() {
        print("⏹️ Stopping real-time sync")
        syncTimer?.invalidate()
        syncTimer = nil
    }

    @MainActor
    func performIncrementalSync() async {
        guard !isSyncing else {
            print("⏭️ Sync already in progress, skipping")
            return
        }

        isSyncing = true
        syncErrors.removeAll()

        print("🔄 Starting incremental sync...")

        // Sync each calendar source
        await syncCalendarSource(.ios)
        await syncCalendarSource(.google)
        await syncCalendarSource(.outlook)

        lastSyncDate = Date()
        isSyncing = false

        print("✅ Incremental sync completed")
    }

    private func syncCalendarSource(_ source: CalendarSource) async {
        let lastSync = coreDataManager.getLastSyncDate(for: source) ?? Date.distantPast

        do {
            switch source {
            case .ios:
                await syncIOSEvents(since: lastSync)
            case .google:
                await syncGoogleEvents(since: lastSync)
            case .outlook:
                await syncOutlookEvents(since: lastSync)
            }

            coreDataManager.updateSyncStatus(for: source, lastSyncDate: Date())

        } catch {
            let syncError = CalendarSyncError(source: source, error: error, timestamp: Date())
            await MainActor.run {
                syncErrors.append(syncError)
            }
            print("❌ Sync failed for \(source): \(error)")
        }
    }

    // MARK: - Platform-specific Sync

    private func syncIOSEvents(since lastSyncDate: Date) async {
        guard let calendarManager = calendarManager,
              calendarManager.hasCalendarAccess else {
            print("⚠️ No iOS calendar access for sync")
            return
        }

        print("📱 Syncing iOS events since \(lastSyncDate)")

        // Get events modified since last sync
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()

        let predicate = calendarManager.eventStore.predicateForEvents(
            withStart: lastSyncDate,
            end: endDate,
            calendars: nil
        )

        let events = calendarManager.eventStore.events(matching: predicate)
        let filteredEvents = events.filter { event in
            guard let lastModified = event.lastModifiedDate else { return true }
            return lastModified > lastSyncDate
        }

        if !filteredEvents.isEmpty {
            let unifiedEvents = filteredEvents.map { event in
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

            coreDataManager.saveEvents(unifiedEvents, syncStatus: .synced)
            print("📱 Synced \(unifiedEvents.count) iOS events")
        }
    }

    private func syncGoogleEvents(since lastSyncDate: Date) async {
        guard let calendarManager = calendarManager,
              let googleManager = calendarManager.googleCalendarManager,
              googleManager.isSignedIn else {
            print("⚠️ Google Calendar not available for sync")
            return
        }

        print("🟢 Syncing Google events since \(lastSyncDate)")

        // Trigger Google Calendar fetch with updated since parameter
        await MainActor.run {
            googleManager.fetchEventsSince(lastSyncDate)
        }

        // Give time for the fetch to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

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

        if !googleEvents.isEmpty {
            coreDataManager.saveEvents(googleEvents, syncStatus: .synced)
            print("🟢 Synced \(googleEvents.count) Google events")
        }
    }

    private func syncOutlookEvents(since lastSyncDate: Date) async {
        guard let calendarManager = calendarManager,
              let outlookManager = calendarManager.outlookCalendarManager,
              outlookManager.isSignedIn else {
            print("⚠️ Outlook Calendar not available for sync")
            return
        }

        print("🔵 Syncing Outlook events since \(lastSyncDate)")

        // Trigger Outlook Calendar fetch
        await MainActor.run {
            outlookManager.fetchEvents()
        }

        // Give time for the fetch to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

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

        if !outlookEvents.isEmpty {
            coreDataManager.saveEvents(outlookEvents, syncStatus: .synced)
            print("🔵 Synced \(outlookEvents.count) Outlook events")
        }
    }

    // MARK: - Background Sync

    private func setupBackgroundSync() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.calai.CalAI.sync",
                using: nil
            ) { task in
                self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }
    }

    @available(iOS 13.0, *)
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("🔄 Handling background sync")

        task.expirationHandler = {
            print("⏰ Background sync expired")
            task.setTaskCompleted(success: false)
        }

        Task {
            await performIncrementalSync()
            task.setTaskCompleted(success: true)
            scheduleBackgroundSync()
        }
    }

    func scheduleBackgroundSync() {
        guard #available(iOS 13.0, *) else { return }

        let request = BGAppRefreshTaskRequest(identifier: "com.calai.CalAI.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Background sync scheduled")
        } catch {
            print("❌ Failed to schedule background sync: \(error)")
        }
    }

    // MARK: - Conflict Resolution

    func resolveConflicts(for event: UnifiedEvent) -> ConflictResolution {
        // Check for conflicts with existing events
        let existingEvents = coreDataManager.fetchEvents(for: event.source)

        for existingEvent in existingEvents {
            if existingEvent.id == event.id {
                // Same event, check modification dates
                if let cachedEvent = existingEvent.originalEvent as? CachedEvent,
                   let lastModified = cachedEvent.lastModified {

                    // Prefer the most recently modified version
                    let currentTime = Date()
                    let timeDiff = abs(currentTime.timeIntervalSince(lastModified))

                    if timeDiff < 60 { // Modified within last minute
                        return .useRemote(reason: "Remote version is more recent")
                    } else {
                        return .useLocal(reason: "Local version is more recent")
                    }
                }
            }
        }

        return .noConflict
    }

    deinit {
        stopRealTimeSync()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

struct CalendarSyncError: Identifiable {
    let id = UUID()
    let source: CalendarSource
    let error: Error
    let timestamp: Date

    var description: String {
        "Sync failed for \(source.rawValue): \(error.localizedDescription)"
    }
}

enum ConflictResolution {
    case useLocal(reason: String)
    case useRemote(reason: String)
    case merge(strategy: MergeStrategy)
    case noConflict
}

enum MergeStrategy {
    case preferLocal
    case preferRemote
    case manual
}

// MARK: - Extensions

extension GoogleCalendarManager {
    func fetchEventsSince(_ date: Date) {
        // This would need to be implemented in GoogleCalendarManager
        // For now, just call the regular fetchEvents
        fetchEvents()
    }
}