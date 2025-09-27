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
    let organizer: String?
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
    private let coreDataManager = CoreDataManager.shared
    private let syncManager = SyncManager.shared
    private let deltaSyncManager = DeltaSyncManager.shared
    private let webhookManager = WebhookManager.shared
    private let conflictResolutionManager = ConflictResolutionManager.shared

    // External calendar managers will be injected
    var googleCalendarManager: GoogleCalendarManager?
    var outlookCalendarManager: OutlookCalendarManager?

    init() {
        // Inject self into sync manager
        syncManager.calendarManager = self
        // Setup advanced sync asynchronously to avoid blocking main thread
        setupAdvancedSyncAsync()
    }

    private func setupAdvancedSyncAsync() {
        // Enable all Phase 6 sync capabilities asynchronously
        Task { @MainActor in
            // Delay to ensure UI is fully loaded first
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            await enableAdvancedSyncFeatures()
        }
    }

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

        // First load cached events from Core Data
        let cachedEvents = coreDataManager.fetchEvents()
        allEvents.append(contentsOf: cachedEvents)
        print("💾 Loaded \(cachedEvents.count) cached events from Core Data")

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
                organizer: event.organizer?.name,
                originalEvent: event
            )
        }

        // Cache iOS events to Core Data
        coreDataManager.saveEvents(iosEvents, syncStatus: .synced)

        // Merge with existing events, avoiding duplicates
        for iosEvent in iosEvents {
            if !allEvents.contains(where: { $0.id == iosEvent.id && $0.source == iosEvent.source }) {
                allEvents.append(iosEvent)
            }
        }
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
                    organizer: nil, // Google events organizer can be added later
                    originalEvent: event
                )
            }

            // Cache Google events to Core Data
            coreDataManager.saveEvents(googleEvents, syncStatus: .synced)

            // Merge with existing events, avoiding duplicates
            for googleEvent in googleEvents {
                if !allEvents.contains(where: { $0.id == googleEvent.id && $0.source == googleEvent.source }) {
                    allEvents.append(googleEvent)
                }
            }
            print("🟢 Added \(googleEvents.count) Google events to unified list")
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
                    organizer: nil, // Outlook events organizer can be added later
                    originalEvent: event
                )
            }

            // Cache Outlook events to Core Data
            coreDataManager.saveEvents(outlookEvents, syncStatus: .synced)

            // Merge with existing events, avoiding duplicates
            for outlookEvent in outlookEvents {
                if !allEvents.contains(where: { $0.id == outlookEvent.id && $0.source == outlookEvent.source }) {
                    allEvents.append(outlookEvent)
                }
            }
            print("🔵 Added \(outlookEvents.count) Outlook events to unified list")
        }

        // Sort all events by start date
        unifiedEvents = allEvents.sorted { $0.startDate < $1.startDate }
        print("✅ Loaded \(unifiedEvents.count) unified events from all sources")
    }

    func refreshAllCalendars() {
        print("🔄 Refreshing all calendar sources...")

        // Update sync status for each source
        coreDataManager.updateSyncStatus(for: .ios, lastSyncDate: Date())

        // Refresh iOS events
        loadEvents()

        // Refresh Google events
        if let googleManager = googleCalendarManager, googleManager.isSignedIn {
            googleManager.fetchEvents()
            coreDataManager.updateSyncStatus(for: .google, lastSyncDate: Date())
        }

        // Refresh Outlook events
        if let outlookManager = outlookCalendarManager, outlookManager.isSignedIn, outlookManager.selectedCalendar != nil {
            outlookManager.fetchEvents()
            coreDataManager.updateSyncStatus(for: .outlook, lastSyncDate: Date())
        }

        // Update unified events after a delay to allow external fetches to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadAllUnifiedEvents()
        }
    }

    func loadOfflineEvents() {
        print("📱 Loading offline events from cache...")

        let cachedEvents = coreDataManager.fetchEvents()

        DispatchQueue.main.async {
            self.unifiedEvents = cachedEvents.sorted { $0.startDate < $1.startDate }
            print("💾 Loaded \(cachedEvents.count) offline events from Core Data")
        }
    }

    func getLastSyncDate(for source: CalendarSource) -> Date? {
        return coreDataManager.getLastSyncDate(for: source)
    }

    func cleanupOldCachedEvents() {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        coreDataManager.cleanupOldEvents(olderThan: oneMonthAgo)
    }

    // MARK: - Real-time Sync Methods

    func startRealTimeSync() {
        print("🔄 Starting real-time calendar sync")
        syncManager.startRealTimeSync()
    }

    func stopRealTimeSync() {
        print("⏹️ Stopping real-time calendar sync")
        syncManager.stopRealTimeSync()
    }

    func performManualSync() async {
        print("🔄 Performing manual sync")
        await syncManager.performIncrementalSync()

        // Refresh UI after sync
        DispatchQueue.main.async {
            self.loadAllUnifiedEvents()
        }
    }

    var isSyncing: Bool {
        syncManager.isSyncing
    }

    var lastSyncDate: Date? {
        syncManager.lastSyncDate
    }

    var syncErrors: [SyncError] {
        syncManager.syncErrors
    }

    // MARK: - Advanced Sync Features (Phase 6)

    private func enableAdvancedSyncFeatures() async {
        print("🚀 Enabling Phase 6 advanced sync features...")

        // Enable webhooks for real-time updates
        await syncManager.enableWebhooks()

        // Setup conflict resolution
        conflictResolutionManager.enableAutoResolution()

        print("✅ Phase 6 advanced sync features enabled")
    }

    func performOptimizedSync() async {
        print("⚡ Performing optimized delta sync...")
        await syncManager.performOptimizedSync()
    }


    func resolveAllConflicts() {
        print("🔧 Resolving all pending conflicts...")

        for event in unifiedEvents {
            let conflicts = conflictResolutionManager.detectConflicts(for: event)
            if !conflicts.isEmpty {
                conflictResolutionManager.presentConflictResolution(for: conflicts)
            }
        }
    }

    // MARK: - Sync Status & Metrics


    // MARK: - Cross-Device Sync Stubs (Disabled for now)
    var crossDeviceSyncStatus: String { "Cross-device sync disabled" }
    var lastCrossDeviceSync: Date? { nil }
    var connectedDevices: [String] { [] }

    func syncToAllDevices() async {
        print("ℹ️ Cross-device sync is disabled in this version")
    }

    var deltaPerformanceMetrics: DeltaPerformanceMetrics {
        deltaSyncManager.getPerformanceMetrics()
    }

    var registeredWebhooks: [RegisteredWebhook] {
        webhookManager.registeredWebhooks
    }

    var pendingConflicts: [EventConflict] {
        conflictResolutionManager.pendingConflicts
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
            if let queryDate = response.startDate {
                checkAvailability(for: queryDate) { [weak self] isAvailable, conflictingEvents in
                    DispatchQueue.main.async {
                        self?.handleAvailabilityResult(isAvailable: isAvailable,
                                                     conflictingEvents: conflictingEvents,
                                                     queryDate: queryDate)
                    }
                }
            } else {
                loadEvents()
            }
        case .unknown:
            print("❓ Unknown AI response: \(response.message)")
        }
    }

    // MARK: - Availability Checking

    func checkAvailability(for queryDate: Date, completion: @escaping (Bool, [UnifiedEvent]) -> Void) {
        print("🔍 Checking availability for \(queryDate)")

        // Ensure events are loaded
        loadAllUnifiedEvents()

        // Use a slight delay to ensure events are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Define a 1-hour window around the query time
            let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: queryDate) ?? queryDate

            // Find conflicting events
            let conflictingEvents = self.unifiedEvents.filter { event in
                // Check if the event overlaps with the query time window
                return (event.startDate < endDate && event.endDate > queryDate)
            }

            let isAvailable = conflictingEvents.isEmpty

            print("📊 Availability check result: \(isAvailable ? "FREE" : "BUSY"), \(conflictingEvents.count) conflicts")

            completion(isAvailable, conflictingEvents)
        }
    }

    private func handleAvailabilityResult(isAvailable: Bool, conflictingEvents: [UnifiedEvent], queryDate: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let formattedDate = formatter.string(from: queryDate)

        var resultMessage: String

        if isAvailable {
            resultMessage = "✅ You're free at \(formattedDate)!"
        } else {
            resultMessage = "❌ You have \(conflictingEvents.count) conflict\(conflictingEvents.count == 1 ? "" : "s") at \(formattedDate):"

            for event in conflictingEvents.prefix(3) {
                resultMessage += "\n• \(event.title) (\(event.duration))"
            }

            if conflictingEvents.count > 3 {
                resultMessage += "\n• ...and \(conflictingEvents.count - 3) more"
            }
        }

        print("📢 Availability result: \(resultMessage)")

        // Post notification for UI to show the result
        NotificationCenter.default.post(
            name: NSNotification.Name("AvailabilityResult"),
            object: nil,
            userInfo: ["message": resultMessage]
        )
    }
}