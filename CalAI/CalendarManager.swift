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

    func createEvent(title: String, startDate: Date, endDate: Date? = nil, location: String? = nil, notes: String? = nil, participants: [String]? = nil) {
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

        if let location = location {
            event.location = location
        }

        if let notes = notes {
            event.notes = notes
        }

        // Add participants as attendees
        if let participants = participants {
            var attendees: [EKParticipant] = []
            for participant in participants {
                // Create structured location for participant (this is a simplified approach)
                if let attendee = createAttendee(for: participant, in: event) {
                    attendees.append(attendee)
                }
            }
            // Note: EKEvent attendees are read-only, but we can add them to notes
            if !participants.isEmpty {
                let participantList = participants.joined(separator: ", ")
                event.notes = (event.notes ?? "") + "\n\nParticipants: \(participantList)"
            }
        }

        print("📅 Event details: \(title) from \(startDate) to \(event.endDate ?? startDate)")

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event saved successfully")
            loadEvents()
        } catch {
            print("❌ Error creating event: \(error)")
        }
    }

    private func createAttendee(for participant: String, in event: EKEvent) -> EKParticipant? {
        // This is a simplified approach since EKParticipant creation is complex
        // In a real implementation, you'd need to handle contact resolution
        return nil
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

    func handleAICalendarResponse(_ response: AICalendarResponse) {
        print("📅 CalendarManager handling AI calendar response: \(response.message)")

        guard let command = response.command else {
            print("ℹ️ No command to execute in AI response")
            return
        }

        executeCalendarCommand(command)
    }

    private func executeCalendarCommand(_ command: CalendarCommand) {
        print("🎯 Executing calendar command: \(command.type)")

        switch command.type {
        case .createEvent:
            if let title = command.title,
               let startDate = command.startDate {
                print("✅ Creating event: \(title) at \(startDate)")
                createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: command.endDate,
                    location: command.location,
                    notes: command.notes,
                    participants: command.participants
                )
            } else {
                print("❌ Missing title or start date for event creation")
            }

        case .queryEvents:
            print("📋 Querying events")
            if let queryStartDate = command.queryStartDate {
                if let queryEndDate = command.queryEndDate {
                    queryEvents(from: queryStartDate, to: queryEndDate, searchQuery: command.searchQuery)
                } else {
                    checkAvailability(for: queryStartDate) { [weak self] isAvailable, conflictingEvents in
                        DispatchQueue.main.async {
                            self?.handleAvailabilityResult(
                                isAvailable: isAvailable,
                                conflictingEvents: conflictingEvents,
                                queryDate: queryStartDate
                            )
                        }
                    }
                }
            } else {
                loadEvents()
            }

        case .checkAvailability:
            print("🔍 Checking availability")
            if let startDate = command.startDate {
                let endDate = command.endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                checkAvailabilityForPeriod(from: startDate, to: endDate)
            }

        case .rescheduleEvent:
            print("🔄 Reschedule event: \(command.searchQuery ?? "event")")
            if let searchQuery = command.searchQuery,
               let newStartDate = command.newStartDate {
                rescheduleEvent(searchQuery: searchQuery, newStartDate: newStartDate, newEndDate: command.newEndDate)
            }

        case .findTimeSlot:
            print("🔍 Find time slot: \(command.timeSlotDuration ?? 60) minutes")
            if let duration = command.timeSlotDuration {
                findAvailableTimeSlot(durationMinutes: duration, preferredRange: command.preferredTimeRange)
            }

        case .inviteAttendees:
            print("👥 Invite attendees to: \(command.searchQuery ?? "event")")
            if let searchQuery = command.searchQuery,
               let attendees = command.attendeesToAdd {
                inviteAttendeesToEvent(searchQuery: searchQuery, attendees: attendees)
            }

        case .getWorkloadSummary:
            print("📊 Get workload summary: \(command.summaryType ?? "general")")
            generateWorkloadSummary(type: command.summaryType, timeRange: command.preferredTimeRange)

        case .blockTime:
            print("🚫 Block time: \(command.title ?? "blocked time")")
            if let startDate = command.startDate {
                createEvent(
                    title: command.title ?? "Blocked Time",
                    startDate: startDate,
                    endDate: command.endDate,
                    location: command.location,
                    notes: "Time blocked via voice command"
                )
            }

        case .updateEvent:
            print("📝 Update event: \(command.title ?? "event")")
            // TODO: Implement update functionality

        case .deleteEvent:
            print("🗑️ Delete event: \(command.title ?? "event")")
            // TODO: Implement delete functionality

        case .extendEvent:
            print("⏱️ Extend event: \(command.searchQuery ?? "event")")
            if let searchQuery = command.searchQuery,
               let duration = command.durationMinutes {
                extendEvent(searchQuery: searchQuery, additionalMinutes: duration)
            }

        case .moveEvent:
            print("📅 Move event: \(command.searchQuery ?? "event")")
            // Similar to reschedule
            if let searchQuery = command.searchQuery,
               let newStartDate = command.newStartDate {
                rescheduleEvent(searchQuery: searchQuery, newStartDate: newStartDate, newEndDate: command.newEndDate)
            }

        case .removeAttendees:
            print("👤 Remove attendees from: \(command.searchQuery ?? "event")")
            if let searchQuery = command.searchQuery,
               let attendees = command.attendeesToRemove {
                removeAttendeesFromEvent(searchQuery: searchQuery, attendees: attendees)
            }

        case .setRecurring:
            print("🔄 Set recurring: \(command.title ?? "event")")
            // TODO: Implement recurring event functionality

        case .clearSchedule:
            print("🗑️ Clear schedule for: \(command.preferredTimeRange ?? "specified time")")
            if let timeRange = command.preferredTimeRange {
                clearScheduleForTimeRange(timeRange)
            }

        case .showHelp:
            print("❓ Showing help commands")
            showHelpMessage()
        }
    }

    // Legacy method for backwards compatibility
    func handleAIResponse(_ response: AIResponse) {
        print("📅 CalendarManager handling legacy AI response: action=\(response.action), title=\(response.eventTitle ?? "nil")")

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
        case .rescheduleEvent:
            print("🔄 Reschedule event: \(response.eventTitle ?? "event")")
            // TODO: Implement reschedule functionality

        case .cancelEvent:
            print("❌ Cancel event: \(response.eventTitle ?? "event")")
            // TODO: Implement cancel functionality

        case .findTimeSlot:
            print("🔍 Find time slot: duration=\(response.timeSlotDuration ?? 3600)")
            // TODO: Implement time slot finding

        case .blockTime:
            print("🚫 Block time: \(response.eventTitle ?? "blocked time")")
            if let title = response.eventTitle,
               let startDate = response.startDate {
                createEvent(title: title, startDate: startDate, endDate: response.endDate)
            }

        case .extendEvent:
            print("⏱️ Extend event: \(response.eventTitle ?? "event")")
            // TODO: Implement extend functionality

        case .moveEvent:
            print("📅 Move event: \(response.eventTitle ?? "event")")
            // TODO: Implement move functionality

        case .batchOperation:
            print("📦 Batch operation: \(response.searchCriteria ?? "multiple events")")
            // TODO: Implement batch operations

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

    // MARK: - Additional Calendar Command Methods

    private func queryEvents(from startDate: Date, to endDate: Date, searchQuery: String? = nil) {
        print("📋 Querying events from \(startDate) to \(endDate)")

        // Ensure events are loaded
        loadAllUnifiedEvents()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            var filteredEvents = self.unifiedEvents.filter { event in
                return event.startDate >= startDate && event.startDate <= endDate
            }

            // Apply search query if provided
            if let searchQuery = searchQuery, !searchQuery.isEmpty {
                filteredEvents = filteredEvents.filter { event in
                    return event.title.localizedCaseInsensitiveContains(searchQuery) ||
                           event.location?.localizedCaseInsensitiveContains(searchQuery) == true ||
                           event.description?.localizedCaseInsensitiveContains(searchQuery) == true
                }
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            var resultMessage: String
            if filteredEvents.isEmpty {
                resultMessage = searchQuery != nil ?
                    "No events found matching '\(searchQuery!)'" :
                    "No events found in the specified time period"
            } else {
                resultMessage = searchQuery != nil ?
                    "Found \(filteredEvents.count) events matching '\(searchQuery!)':" :
                    "Found \(filteredEvents.count) events:"

                for event in filteredEvents.prefix(5) {
                    resultMessage += "\n• \(event.title) - \(formatter.string(from: event.startDate))"
                }

                if filteredEvents.count > 5 {
                    resultMessage += "\n• ...and \(filteredEvents.count - 5) more"
                }
            }

            print("📢 Query result: \(resultMessage)")

            // Post notification for UI to show the result
            NotificationCenter.default.post(
                name: NSNotification.Name("AvailabilityResult"),
                object: nil,
                userInfo: ["message": resultMessage]
            )
        }
    }

    private func checkAvailabilityForPeriod(from startDate: Date, to endDate: Date) {
        print("🔍 Checking availability for period from \(startDate) to \(endDate)")

        // Ensure events are loaded
        loadAllUnifiedEvents()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Find conflicting events
            let conflictingEvents = self.unifiedEvents.filter { event in
                return (event.startDate < endDate && event.endDate > startDate)
            }

            let isAvailable = conflictingEvents.isEmpty

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let formattedStart = formatter.string(from: startDate)
            let formattedEnd = formatter.string(from: endDate)

            var resultMessage: String

            if isAvailable {
                resultMessage = "✅ You're free from \(formattedStart) to \(formattedEnd)!"
            } else {
                resultMessage = "❌ You have \(conflictingEvents.count) conflict\(conflictingEvents.count == 1 ? "" : "s") during this period:"

                for event in conflictingEvents.prefix(3) {
                    resultMessage += "\n• \(event.title) (\(event.duration))"
                }

                if conflictingEvents.count > 3 {
                    resultMessage += "\n• ...and \(conflictingEvents.count - 3) more"
                }
            }

            print("📢 Availability period result: \(resultMessage)")

            // Post notification for UI to show the result
            NotificationCenter.default.post(
                name: NSNotification.Name("AvailabilityResult"),
                object: nil,
                userInfo: ["message": resultMessage]
            )
        }
    }

    // MARK: - Advanced Calendar Management Methods

    private func rescheduleEvent(searchQuery: String, newStartDate: Date, newEndDate: Date?) {
        print("🔄 Rescheduling event matching: \(searchQuery)")

        // Find matching events
        let matchingEvents = events.filter { event in
            return event.title?.localizedCaseInsensitiveContains(searchQuery) == true
        }

        guard let eventToReschedule = matchingEvents.first else {
            let message = "Could not find event matching '\(searchQuery)' to reschedule."
            postNotificationMessage(message)
            return
        }

        // Calculate duration if newEndDate not provided
        let originalDuration = eventToReschedule.endDate.timeIntervalSince(eventToReschedule.startDate)
        let calculatedEndDate = newEndDate ?? newStartDate.addingTimeInterval(originalDuration)

        // Update event
        eventToReschedule.startDate = newStartDate
        eventToReschedule.endDate = calculatedEndDate

        do {
            try eventStore.save(eventToReschedule, span: .thisEvent)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let message = "✅ Rescheduled '\(eventToReschedule.title ?? "event")' to \(formatter.string(from: newStartDate))"
            postNotificationMessage(message)
            loadEvents()
        } catch {
            let message = "❌ Failed to reschedule event: \(error.localizedDescription)"
            postNotificationMessage(message)
        }
    }

    private func findAvailableTimeSlot(durationMinutes: Int, preferredRange: String?) {
        print("🔍 Finding \(durationMinutes)-minute time slot in \(preferredRange ?? "any time")")

        let calendar = Calendar.current
        let now = Date()
        let startSearchDate: Date
        let endSearchDate: Date

        // Parse preferred range
        if let range = preferredRange?.lowercased() {
            if range.contains("tomorrow") {
                startSearchDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                endSearchDate = calendar.date(byAdding: .day, value: 1, to: startSearchDate) ?? startSearchDate
            } else if range.contains("week") {
                startSearchDate = now
                endSearchDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            } else if range.contains("morning") {
                startSearchDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
                endSearchDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
            } else if range.contains("afternoon") {
                startSearchDate = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now) ?? now
                endSearchDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
            } else {
                startSearchDate = now
                endSearchDate = calendar.date(byAdding: .day, value: 7, to: now) ?? now
            }
        } else {
            startSearchDate = now
            endSearchDate = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        }

        // Find available slots
        let slotDuration = TimeInterval(durationMinutes * 60)
        var availableSlots: [Date] = []
        var searchTime = startSearchDate

        while searchTime < endSearchDate && availableSlots.count < 5 {
            let slotEndTime = searchTime.addingTimeInterval(slotDuration)

            let conflicts = unifiedEvents.filter { event in
                return (event.startDate < slotEndTime && event.endDate > searchTime)
            }

            if conflicts.isEmpty && searchTime > now {
                availableSlots.append(searchTime)
            }

            searchTime = searchTime.addingTimeInterval(30 * 60) // Check every 30 minutes
        }

        // Report results
        var message: String
        if availableSlots.isEmpty {
            message = "❌ No available \(durationMinutes)-minute slots found in the specified time range."
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            message = "✅ Found \(availableSlots.count) available \(durationMinutes)-minute slots:"
            for slot in availableSlots.prefix(3) {
                message += "\n• \(formatter.string(from: slot))"
            }
            if availableSlots.count > 3 {
                message += "\n• ...and \(availableSlots.count - 3) more"
            }
        }

        postNotificationMessage(message)
    }

    private func inviteAttendeesToEvent(searchQuery: String, attendees: [String]) {
        print("👥 Inviting \(attendees.joined(separator: ", ")) to event: \(searchQuery)")

        let matchingEvents = events.filter { event in
            return event.title?.localizedCaseInsensitiveContains(searchQuery) == true
        }

        guard let eventToUpdate = matchingEvents.first else {
            let message = "Could not find event matching '\(searchQuery)' to add attendees."
            postNotificationMessage(message)
            return
        }

        // Add attendees to notes (EventKit doesn't allow direct attendee modification)
        let attendeeList = attendees.joined(separator: ", ")
        let currentNotes = eventToUpdate.notes ?? ""
        eventToUpdate.notes = currentNotes.isEmpty ?
            "Attendees: \(attendeeList)" :
            "\(currentNotes)\n\nAdded Attendees: \(attendeeList)"

        do {
            try eventStore.save(eventToUpdate, span: .thisEvent)
            let message = "✅ Added attendees to '\(eventToUpdate.title ?? "event")': \(attendeeList)"
            postNotificationMessage(message)
            loadEvents()
        } catch {
            let message = "❌ Failed to add attendees: \(error.localizedDescription)"
            postNotificationMessage(message)
        }
    }

    private func generateWorkloadSummary(type: String?, timeRange: String?) {
        print("📊 Generating \(type ?? "general") workload summary for \(timeRange ?? "default range")")

        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date

        // Parse time range
        if let range = timeRange?.lowercased() {
            if range.contains("week") {
                if range.contains("last") {
                    startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: calendar.startOfWeek(for: now)) ?? now
                    endDate = calendar.startOfWeek(for: now)
                } else if range.contains("next") {
                    startDate = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfWeek(for: now)) ?? now
                    endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
                } else {
                    startDate = calendar.startOfWeek(for: now)
                    endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
                }
            } else if range.contains("month") {
                startDate = calendar.startOfMonth(for: now) ?? now
                endDate = calendar.endOfMonth(for: now) ?? now
            } else {
                startDate = calendar.startOfDay(for: now)
                endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            }
        } else {
            startDate = calendar.startOfWeek(for: now)
            endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        }

        // Filter events for the time range
        let rangeEvents = unifiedEvents.filter { event in
            return event.startDate >= startDate && event.startDate < endDate
        }

        // Generate summary based on type
        var message: String

        if let summaryType = type?.lowercased() {
            switch summaryType {
            case "busiest_day":
                let dayGroups = Dictionary(grouping: rangeEvents) { event in
                    calendar.startOfDay(for: event.startDate)
                }
                let busiestDay = dayGroups.max { $0.value.count < $1.value.count }
                let formatter = DateFormatter()
                formatter.dateStyle = .full

                if let busiest = busiestDay {
                    message = "📊 Busiest day: \(formatter.string(from: busiest.key)) with \(busiest.value.count) events"
                } else {
                    message = "📊 No events found in the specified time range"
                }

            case "meeting_count":
                message = "📊 Total meetings: \(rangeEvents.count) in the specified period"

            case "travel":
                let travelEvents = rangeEvents.filter { event in
                    return event.title.localizedCaseInsensitiveContains("travel") ||
                           event.title.localizedCaseInsensitiveContains("flight") ||
                           event.title.localizedCaseInsensitiveContains("trip")
                }
                message = "✈️ Travel events: \(travelEvents.count) found"
                for event in travelEvents.prefix(5) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    message += "\n• \(event.title) - \(formatter.string(from: event.startDate))"
                }

            default:
                // Weekly summary
                let totalHours = rangeEvents.reduce(0.0) { total, event in
                    return total + event.endDate.timeIntervalSince(event.startDate) / 3600
                }
                message = "📊 Weekly Summary:\n• \(rangeEvents.count) total events\n• \(String(format: "%.1f", totalHours)) hours scheduled"
            }
        } else {
            // Default summary
            let totalHours = rangeEvents.reduce(0.0) { total, event in
                return total + event.endDate.timeIntervalSince(event.startDate) / 3600
            }
            message = "📊 Schedule Summary:\n• \(rangeEvents.count) events\n• \(String(format: "%.1f", totalHours)) hours scheduled"
        }

        postNotificationMessage(message)
    }

    private func extendEvent(searchQuery: String, additionalMinutes: Int) {
        print("⏱️ Extending event '\(searchQuery)' by \(additionalMinutes) minutes")

        let matchingEvents = events.filter { event in
            return event.title?.localizedCaseInsensitiveContains(searchQuery) == true
        }

        guard let eventToExtend = matchingEvents.first else {
            let message = "Could not find event matching '\(searchQuery)' to extend."
            postNotificationMessage(message)
            return
        }

        let newEndDate = eventToExtend.endDate.addingTimeInterval(TimeInterval(additionalMinutes * 60))
        eventToExtend.endDate = newEndDate

        do {
            try eventStore.save(eventToExtend, span: .thisEvent)
            let message = "✅ Extended '\(eventToExtend.title ?? "event")' by \(additionalMinutes) minutes"
            postNotificationMessage(message)
            loadEvents()
        } catch {
            let message = "❌ Failed to extend event: \(error.localizedDescription)"
            postNotificationMessage(message)
        }
    }

    private func removeAttendeesFromEvent(searchQuery: String, attendees: [String]) {
        print("👤 Removing attendees from event: \(searchQuery)")
        // Implementation similar to inviteAttendeesToEvent but for removal
        let message = "ℹ️ Attendee removal noted for '\(searchQuery)'"
        postNotificationMessage(message)
    }

    private func clearScheduleForTimeRange(_ timeRange: String) {
        print("🗑️ Clearing schedule for: \(timeRange)")
        let message = "ℹ️ Schedule clearing for '\(timeRange)' - please manually delete events as needed"
        postNotificationMessage(message)
    }

    private func postNotificationMessage(_ message: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("AvailabilityResult"),
                object: nil,
                userInfo: ["message": message]
            )
        }
    }

    // MARK: - Help System

    private func showHelpMessage() {
        let helpMessage = """
        📅 CalAI Voice Commands - Available Commands:

        🗓️ SCHEDULING:
        • "Schedule a meeting with John tomorrow at 2 PM"
        • "Book an appointment for Friday afternoon"
        • "Set up a call for next Monday at 10 AM"
        • "Add lunch with Sarah to my calendar"
        • "Block off time for focus work"

        🔍 CALENDAR CHECKING:
        • "What's on my calendar today?"
        • "Show me this week's schedule"
        • "Do I have anything tomorrow morning?"
        • "When's my next meeting?"
        • "Am I free at 3 PM?"

        👥 INVITATIONS & ATTENDEES:
        • "Invite Alex to the team meeting"
        • "Add Sarah to lunch on Friday"
        • "Include the marketing team in the review"
        • "Remove John from the presentation"

        🛠️ CALENDAR MANAGEMENT:
        • "Move my 2 PM meeting to 3 PM"
        • "Reschedule lunch to tomorrow"
        • "Extend the meeting by 30 minutes"
        • "Make my Monday 9 AM meeting weekly"
        • "Cancel my afternoon appointments"
        • "Clear my schedule for Friday"

        📊 SUMMARIES & ANALYSIS:
        • "How busy am I this week?"
        • "Summarize my schedule"
        • "What's my workload like?"
        • "Show me today's agenda"
        • "Find me a 30-minute slot"

        💡 TIPS:
        • Speak naturally - I understand many variations
        • Include times, dates, and people in your requests
        • Say "help" anytime to see this list again
        • Try phrases like "schedule", "book", "find time", "check calendar"

        🎤 Just speak your command and I'll handle the rest!
        """

        print("❓ \(helpMessage)")
        postNotificationMessage(helpMessage)
    }
}

// MARK: - Calendar Extensions

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }

    func endOfMonth(for date: Date) -> Date? {
        guard let startOfMonth = startOfMonth(for: date) else { return nil }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
    }
}