import Foundation
import EventKit
import Combine
import SwiftUI
import GoogleSignIn

// MARK: - Widget Shared Models

/// Lightweight event model for widget display
struct WidgetCalendarEvent: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?

    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
    }

    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }

    var isUpcoming: Bool {
        startDate > Date()
    }
}

/// Shared storage for calendar events accessible by both app and widget
class SharedCalendarStorage {
    static let shared = SharedCalendarStorage()
    private let appGroupID = "group.com.rasheuristics.calendarweaver"
    private let eventsKey = "sharedCalendarEvents"
    private let tasksKey = "sharedTasksCount"
    private init() {}

    func saveEvents(_ events: [WidgetCalendarEvent]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to access App Group UserDefaults")
            return
        }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(events)
            userDefaults.set(data, forKey: eventsKey)
            userDefaults.synchronize()
            print("✅ Saved \(events.count) events to shared storage")
        } catch {
            print("❌ Failed to encode events: \(error)")
        }
    }

    func saveTasksCount(_ count: Int) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return }
        userDefaults.set(count, forKey: tasksKey)
        userDefaults.synchronize()
        print("✅ Saved tasks count: \(count)")
    }

    func loadEvents() -> [WidgetCalendarEvent] {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: eventsKey) else {
            print("⚠️ No events found in shared storage")
            return []
        }
        do {
            let decoder = JSONDecoder()
            let events = try decoder.decode([WidgetCalendarEvent].self, from: data)
            print("✅ Loaded \(events.count) events from shared storage")
            return events
        } catch {
            print("❌ Failed to decode events: \(error)")
            return []
        }
    }

    func loadTasksCount() -> Int {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        return userDefaults.integer(forKey: tasksKey)
    }
}

enum CalendarSource: String, Equatable, CaseIterable, Codable {
    case ios
    case google
    case outlook
}

// MARK: - Calendar Invitations Models

/// Status of a calendar invitation
enum InvitationStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
    case tentative = "Tentative"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .pending: return "envelope"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .tentative: return "questionmark.circle.fill"
        }
    }
}

/// Represents a calendar invitation from any source
struct CalendarInvitation: Identifiable {
    let id: String
    let title: String
    let organizer: String?
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let source: CalendarSource
    let status: InvitationStatus
    let originalEvent: EKEvent?
    let calendarName: String?

    var hasResponded: Bool {
        status != .pending
    }
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
    let calendarId: String?
    let calendarName: String?
    let calendarColor: Color?

    var sourceLabel: String {
        switch source {
        case .ios: return "📱 iOS"
        case .google: return "🟢 Google"
        case .outlook: return "🔵 Outlook"
        }
    }

    var sourceColor: Color {
        return DesignSystem.Colors.forCalendarSource(source)
    }

    var duration: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var fullCalendarLabel: String {
        if let calendarName = calendarName {
            return "\(sourceLabel) - \(calendarName)"
        }
        return sourceLabel
    }

    /// Get the display color for this event (title-based, with custom override support)
    var displayColor: Color {
        return EventColorManager.shared.getColor(
            for: id,
            title: title,
            defaultColor: calendarColor
        )
    }
}

struct ConflictingEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarSource: String
    let calendarName: String
    let location: String?
}

struct ConflictResult {
    let hasConflict: Bool
    let conflictingEvents: [ConflictingEvent]
    let alternativeTimes: [Date]

    static var noConflict: ConflictResult {
        return ConflictResult(hasConflict: false, conflictingEvents: [], alternativeTimes: [])
    }
}

// MARK: - Calendar Item Models

struct GoogleCalendarItem: Identifiable, Hashable {
    let id: String
    let name: String
    let backgroundColor: String?
    let isPrimary: Bool

    var color: Color {
        if let bgColor = backgroundColor {
            return Color(hex: bgColor) ?? .blue
        }
        return .blue
    }
}

struct OutlookCalendarItem: Identifiable, Hashable {
    let id: String
    let name: String
    let color: String?

    var displayColor: Color {
        if let colorHex = color {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Deleted Event Tracking (Persisted)

/// Structure to track deleted events with timestamps for expiration
struct DeletedEventRecord: Codable {
    let eventId: String
    let deletedAt: Date
    let source: String
}

class CalendarManager: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var unifiedEvents: [UnifiedEvent] = []
    @Published var hasCalendarAccess = false

    // Calendar invitations
    @Published var invitations: [CalendarInvitation] = []
    @Published var newInvitationsCount: Int = 0

    // Calendar visibility management
    @Published var visibleCalendarIds: Set<String> = []

    // Calendar info sheets
    @Published var selectedCalendarForInfo: EKCalendar? = nil
    @Published var selectedGoogleCalendarForInfo: GoogleCalendarItem? = nil
    @Published var selectedOutlookCalendarForInfo: OutlookCalendarItem? = nil

    // Proactive suggestions (TODO: Uncomment when ProactiveSuggestionsManager is added to Xcode project)
    // let proactiveSuggestionsManager = ProactiveSuggestionsManager.shared

    // UserDefaults key for persistence
    private let deletedEventsKey = "com.calai.deletedEventIds"
    private let deletionExpirationDays = 30

    // Track deleted events to prevent them from reappearing after sync
    // Now backed by UserDefaults for persistence across app restarts
    var deletedEventIds: Set<String> {
        get {
            return Set(loadDeletedEventRecords().map { $0.eventId })
        }
        set {
            // When setting, preserve existing timestamps or create new ones
            var records = loadDeletedEventRecords()
            let existingIds = Set(records.map { $0.eventId })

            // Add new IDs
            for newId in newValue where !existingIds.contains(newId) {
                records.append(DeletedEventRecord(
                    eventId: newId,
                    deletedAt: Date(),
                    source: "unknown"
                ))
            }

            // Remove IDs that are no longer in the set
            records.removeAll { !newValue.contains($0.eventId) }

            saveDeletedEventRecords(records)
        }
    }

    // Calendar lists for each source
    @Published var iosCalendars: [EKCalendar] = []
    @Published var googleCalendars: [GoogleCalendarItem] = [] {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var outlookCalendars: [OutlookCalendarItem] = [] {
        didSet {
            objectWillChange.send()
        }
    }

    // Error and loading states
    @Published var errorState: AppError?
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?

    // Conflict detection state
    @Published var pendingConflictResult: ConflictResult?
    @Published var pendingEventDetails: (title: String, startDate: Date, endDate: Date, location: String?, notes: String?, participants: [String]?, calendarSource: String?)?
    @Published var detectedConflicts: [ScheduleConflict] = []
    @Published var showConflictAlert: Bool = false

    // Add event sheet state
    @Published var showingAddEventFromCalendar: Bool = false

    // Track internal operations to prevent reload loops
    var isPerformingInternalDeletion = false
    var isPerformingInternalUpdate = false

    // Approved conflicts (conflicts user chose to keep both)
    private var approvedConflicts: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(approvedConflicts), forKey: "approvedConflicts")
        }
    }

    // Lazy loading configuration
    @Published var monthsBackToLoad: Int = 3  // Initial load: 3 months back
    @Published var monthsForwardToLoad: Int = 3  // Initial load: 3 months forward

    // Track loaded date ranges to avoid duplicate fetching
    private var loadedRanges: Set<DateInterval> = []
    private let maxCachedMonths: Int = 12  // Maximum months to keep in memory

    let eventStore = EKEventStore()
    private let coreDataManager = CoreDataManager.shared
    private let syncManager = SyncManager.shared
    private let deltaSyncManager = DeltaSyncManager.shared
    private let webhookManager = WebhookManager.shared
    private let conflictResolutionManager = ConflictResolutionManager.shared
    private let duplicateEventDetector = DuplicateEventDetector()
    private var cancellables = Set<AnyCancellable>()

    // External calendar managers will be injected
    var googleCalendarManager: GoogleCalendarManager? {
        didSet {
            setupGoogleEventsObserver()
        }
    }
    var outlookCalendarManager: OutlookCalendarManager? {
        didSet {
            setupOutlookEventsObserver()
        }
    }

    init() {
        // Load approved conflicts from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: "approvedConflicts") as? [String] {
            approvedConflicts = Set(saved)
        }
        // Clean up expired deleted event records on startup
        cleanupExpiredDeletedEvents()
        // Inject self into sync manager
        syncManager.calendarManager = self
        // Setup advanced sync asynchronously to avoid blocking main thread
        setupAdvancedSyncAsync()
        // Listen for event time updates from drag-and-drop
        setupEventUpdateListener()
        // Listen for iOS calendar changes for real-time sync
        setupCalendarChangeNotification()
        // Start periodic sync timer
        startPeriodicSync()
    }

    // MARK: - Deleted Events Persistence

    /// Load deleted event records from UserDefaults
    private func loadDeletedEventRecords() -> [DeletedEventRecord] {
        guard let data = UserDefaults.standard.data(forKey: deletedEventsKey),
              let records = try? JSONDecoder().decode([DeletedEventRecord].self, from: data) else {
            return []
        }
        return records
    }

    /// Save deleted event records to UserDefaults
    private func saveDeletedEventRecords(_ records: [DeletedEventRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            print("❌ Failed to encode deleted event records")
            return
        }
        UserDefaults.standard.set(data, forKey: deletedEventsKey)
        print("💾 Saved \(records.count) deleted event records to UserDefaults")
    }

    /// Track a deleted event with source information
    func trackDeletedEvent(_ eventId: String, source: CalendarSource) {
        var records = loadDeletedEventRecords()

        // Don't add duplicates
        guard !records.contains(where: { $0.eventId == eventId }) else {
            print("📍 Event \(eventId) already tracked as deleted")
            return
        }

        records.append(DeletedEventRecord(
            eventId: eventId,
            deletedAt: Date(),
            source: source.rawValue
        ))

        saveDeletedEventRecords(records)
        print("🗑️ Tracked deleted event: \(eventId) from \(source.rawValue)")
    }

    /// Remove tracking for an event (e.g., if restored)
    func untrackDeletedEvent(_ eventId: String) {
        var records = loadDeletedEventRecords()
        records.removeAll { $0.eventId == eventId }
        saveDeletedEventRecords(records)
        print("♻️ Untracked deleted event: \(eventId)")
    }

    /// Clean up deleted event records older than expiration period
    private func cleanupExpiredDeletedEvents() {
        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: -deletionExpirationDays,
            to: Date()
        ) ?? Date()

        var records = loadDeletedEventRecords()
        let countBefore = records.count

        records.removeAll { $0.deletedAt < expirationDate }

        let removed = countBefore - records.count
        if removed > 0 {
            saveDeletedEventRecords(records)
            print("🧹 Cleaned up \(removed) expired deleted event records (older than \(deletionExpirationDays) days)")
        }
    }

    private func setupEventUpdateListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateEventTime"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let eventId = userInfo["eventId"] as? String,
                  let newStart = userInfo["newStart"] as? Date,
                  let newEnd = userInfo["newEnd"] as? Date,
                  let source = userInfo["source"] as? CalendarSource else {
                print("❌ Invalid event update notification")
                return
            }

            print("📥 Received event update notification for \(eventId)")
            self.updateEventTime(eventId: eventId, newStart: newStart, newEnd: newEnd, source: source)
        }
    }

    // MARK: - Real-Time Sync

    private func setupCalendarChangeNotification() {
        // Listen for iOS EventKit calendar changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDatabaseChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
        print("👂 Listening for iOS calendar changes")
    }

    @objc private func calendarDatabaseChanged() {
        print("🔄 iOS calendar database changed - syncing...")

        // Skip reload if we're in the middle of performing internal operations
        // (to prevent re-fetching and rebuilding immediately after our own changes)
        if isPerformingInternalDeletion {
            print("⏭️ Skipping sync - internal deletion in progress")
            return
        }

        if isPerformingInternalUpdate {
            print("⏭️ Skipping sync - internal update in progress")
            return
        }

        // Debounce: wait a bit in case multiple changes happen quickly
        syncDebounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("🔄 Performing real-time sync...")
            // IMPORTANT: First reload iOS events from EventKit to detect external changes
            // (e.g., deletions via iCloud, changes from other apps)
            self.loadEvents()
            // Then rebuild unified events with the fresh data
            // Note: loadEvents() already calls loadAllUnifiedEvents() at the end
        }

        syncDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private var syncTimer: Timer?
    private var syncDebounceWorkItem: DispatchWorkItem?

    private func startPeriodicSync() {
        // Sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("⏰ Periodic sync triggered")
            self.loadAllUnifiedEvents()
        }
        print("⏰ Periodic sync timer started (every 5 minutes)")
    }

    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("⏹️ Periodic sync timer stopped")
    }

    private func updateEventTime(eventId: String, newStart: Date, newEnd: Date, source: CalendarSource) {
        switch source {
        case .ios:
            // Update iOS/EventKit event
            if let event = eventStore.event(withIdentifier: eventId) {
                let oldStart = event.startDate
                event.startDate = newStart
                event.endDate = newEnd

                // Set flag to prevent reload loop
                isPerformingInternalUpdate = true
                print("🔄 Set isPerformingInternalUpdate = true")

                do {
                    try eventStore.save(event, span: .thisEvent)
                    print("✅ iOS event updated: \(event.title ?? "Untitled")")

                    // Use MainActor to ensure UI updates happen atomically on main thread
                    DispatchQueue.main.async {
                        // Update events array - create new array to trigger SwiftUI updates
                        var updatedEvents = self.events
                        if let index = updatedEvents.firstIndex(where: {
                            $0.eventIdentifier == eventId && $0.startDate == oldStart
                        }) {
                            updatedEvents[index] = event
                            self.events = updatedEvents.sorted { $0.startDate < $1.startDate }
                            print("📝 Updated event in events array at index \(index)")
                        } else {
                            print("⚠️ Could not find event in events array: \(eventId), oldStart: \(oldStart)")
                        }

                        // Update unifiedEvents array - create new array to trigger SwiftUI updates
                        var updatedUnified = self.unifiedEvents
                        if let unifiedIndex = updatedUnified.firstIndex(where: {
                            $0.id == eventId && $0.startDate == oldStart && $0.source == .ios
                        }) {
                            let updatedEvent = UnifiedEvent(
                                id: eventId,
                                title: event.title ?? "Untitled",
                                startDate: newStart,
                                endDate: newEnd,
                                location: event.location,
                                description: event.notes,
                                isAllDay: event.isAllDay,
                                source: .ios,
                                organizer: event.organizer?.name,
                                originalEvent: event,
                                calendarId: event.calendar?.calendarIdentifier,
                                calendarName: event.calendar?.title,
                                calendarColor: event.calendar?.cgColor != nil ? Color(event.calendar!.cgColor) : nil
                            )
                            updatedUnified[unifiedIndex] = updatedEvent
                            self.unifiedEvents = updatedUnified.sorted { $0.startDate < $1.startDate }
                            print("📝 Updated event in unifiedEvents array at index \(unifiedIndex)")
                            print("🔄 New startDate: \(newStart)")
                            print("✅ COMPLETE SAVE:")
                            print("   ✓ Event card will show new time (via savedMinutesOffset)")
                            print("   ✓ Calendar views updated (via refreshTrigger)")
                            print("   ✓ Events tab updated (via @ObservedObject calendarManager)")
                            print("   ✓ iOS calendar saved to EventKit")
                        } else {
                            print("⚠️ Could not find event in unifiedEvents array: \(eventId), oldStart: \(oldStart)")
                        }

                        print("🔔 Notified all observers of event time change")

                        // Reset flag after a delay to allow EventKit notification to be skipped
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                            self?.isPerformingInternalUpdate = false
                            print("🔄 Reset isPerformingInternalUpdate = false")
                        }
                    }

                } catch {
                    print("❌ Failed to save iOS event: \(error)")
                    // Reset flag on error too
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.isPerformingInternalUpdate = false
                        print("🔄 Reset isPerformingInternalUpdate = false (error)")
                    }
                }
            }

        case .google:
            // Update Google Calendar event
            Task {
                await googleCalendarManager?.updateEventTime(eventId: eventId, newStart: newStart, newEnd: newEnd)

                // Also update local unifiedEvents array immediately for UI responsiveness
                DispatchQueue.main.async {
                    var updatedUnified = self.unifiedEvents
                    if let unifiedIndex = updatedUnified.firstIndex(where: {
                        $0.id == eventId && $0.source == .google
                    }) {
                        let oldEvent = updatedUnified[unifiedIndex]
                        let updatedEvent = UnifiedEvent(
                            id: eventId,
                            title: oldEvent.title,
                            startDate: newStart,
                            endDate: newEnd,
                            location: oldEvent.location,
                            description: oldEvent.description,
                            isAllDay: oldEvent.isAllDay,
                            source: .google,
                            organizer: oldEvent.organizer,
                            originalEvent: oldEvent.originalEvent,
                            calendarId: oldEvent.calendarId,
                            calendarName: oldEvent.calendarName,
                            calendarColor: oldEvent.calendarColor
                        )
                        updatedUnified[unifiedIndex] = updatedEvent
                        self.unifiedEvents = updatedUnified.sorted { $0.startDate < $1.startDate }
                        print("📝 Updated Google event in unifiedEvents array at index \(unifiedIndex)")
                        print("🔄 New startDate: \(newStart)")
                        print("✅ COMPLETE SAVE:")
                        print("   ✓ Event card will show new time (via savedMinutesOffset)")
                        print("   ✓ Calendar views updated (via refreshTrigger)")
                        print("   ✓ Events tab updated (via @ObservedObject calendarManager)")
                        print("   ✓ Google calendar API called (background)")
                    } else {
                        print("⚠️ Could not find Google event in unifiedEvents array: \(eventId)")
                    }
                }
            }

        case .outlook:
            // Update Outlook event
            Task {
                await outlookCalendarManager?.updateEventTime(eventId: eventId, newStart: newStart, newEnd: newEnd)

                // Also update local unifiedEvents array immediately for UI responsiveness
                DispatchQueue.main.async {
                    var updatedUnified = self.unifiedEvents
                    if let unifiedIndex = updatedUnified.firstIndex(where: {
                        $0.id == eventId && $0.source == .outlook
                    }) {
                        let oldEvent = updatedUnified[unifiedIndex]
                        let updatedEvent = UnifiedEvent(
                            id: eventId,
                            title: oldEvent.title,
                            startDate: newStart,
                            endDate: newEnd,
                            location: oldEvent.location,
                            description: oldEvent.description,
                            isAllDay: oldEvent.isAllDay,
                            source: .outlook,
                            organizer: oldEvent.organizer,
                            originalEvent: oldEvent.originalEvent,
                            calendarId: oldEvent.calendarId,
                            calendarName: oldEvent.calendarName,
                            calendarColor: oldEvent.calendarColor
                        )
                        updatedUnified[unifiedIndex] = updatedEvent
                        self.unifiedEvents = updatedUnified.sorted { $0.startDate < $1.startDate }
                        print("📝 Updated Outlook event in unifiedEvents array at index \(unifiedIndex)")
                        print("🔄 New startDate: \(newStart)")
                        print("✅ COMPLETE SAVE:")
                        print("   ✓ Event card will show new time (via savedMinutesOffset)")
                        print("   ✓ Calendar views updated (via refreshTrigger)")
                        print("   ✓ Events tab updated (via @ObservedObject calendarManager)")
                        print("   ✓ Outlook calendar API called (background)")
                    } else {
                        print("⚠️ Could not find Outlook event in unifiedEvents array: \(eventId)")
                    }
                }
            }
        }
    }

    private func setupGoogleEventsObserver() {
        guard let googleManager = googleCalendarManager else { return }

        googleManager.$googleEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔔 Google events changed, reloading unified events")
                self?.loadAllUnifiedEvents()
            }
            .store(in: &cancellables)

        // Observe calendar list changes
        googleManager.$availableCalendars
            .receive(on: DispatchQueue.main)
            .sink { [weak self] calendars in
                print("🔔 Google calendars changed: \(calendars.count) calendars")
                self?.googleCalendars = calendars
            }
            .store(in: &cancellables)

        // Fetch calendars on setup
        googleManager.fetchCalendars()
    }

    private func setupOutlookEventsObserver() {
        guard let outlookManager = outlookCalendarManager else { return }

        outlookManager.$outlookEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔔 Outlook events changed, reloading unified events")
                self?.loadAllUnifiedEvents()
            }
            .store(in: &cancellables)

        // Observe calendar list changes
        outlookManager.$availableCalendars
            .receive(on: DispatchQueue.main)
            .sink { [weak self] calendars in
                print("🔔 Outlook calendars changed: \(calendars.count) calendars")
                self?.outlookCalendars = calendars.map { OutlookCalendarItem(id: $0.id, name: $0.name, color: $0.color) }
            }
            .store(in: &cancellables)
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

    func loadIOSCalendars() {
        guard hasCalendarAccess else {
            print("❌ No calendar access, cannot load iOS calendars")
            return
        }

        let calendars = eventStore.calendars(for: .event)
        DispatchQueue.main.async {
            self.iosCalendars = calendars
            print("📅 Loaded \(calendars.count) iOS calendars")

            // Initialize visible calendars (all visible by default)
            if self.visibleCalendarIds.isEmpty {
                self.visibleCalendarIds = Set(calendars.map { $0.calendarIdentifier })
            }
        }
    }

    func loadEvents() {
        print("📅 loadEvents called, hasCalendarAccess: \(hasCalendarAccess)")

        guard hasCalendarAccess else {
            print("❌ No calendar access, cannot load events")
            DispatchQueue.main.async {
                self.errorState = .calendarAccessDenied
                self.isLoading = false
                HapticManager.shared.error()
            }
            return
        }

        // Load available calendars
        loadIOSCalendars()

        // Refresh EventKit sources to get latest data (including recurring events)
        eventStore.refreshSourcesIfNecessary()

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorState = nil
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -monthsBackToLoad, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: monthsForwardToLoad, to: Date()) ?? Date()

        loadEventsInRange(startDate: startDate, endDate: endDate)
    }

    /// Load events for a specific date range and track it
    func loadEventsInRange(startDate: Date, endDate: Date) {
        guard hasCalendarAccess else {
            DispatchQueue.main.async {
                self.errorState = .calendarAccessDenied
                self.isLoading = false
                HapticManager.shared.error()
            }
            return
        }

        // Check if this range is already loaded
        let requestedRange = DateInterval(start: startDate, end: endDate)
        if isRangeLoaded(requestedRange) {
            print("📅 Range already loaded, skipping: \(startDate) to \(endDate)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        print("📅 Loading iOS events from \(startDate) to \(endDate)")
        print("📅 Date range: \(monthsBackToLoad) months back, \(monthsForwardToLoad) months forward")

        do {
            // Get all available calendars for debugging
            let allCalendars = eventStore.calendars(for: .event)
            print("📅 Available calendars: \(allCalendars.count)")
            for calendar in allCalendars {
                print("   - \(calendar.title) (type: \(calendar.type.rawValue), source: \(calendar.source.title))")
            }

            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let fetchedEvents = eventStore.events(matching: predicate)

            let recurringCount = fetchedEvents.filter { $0.hasRecurrenceRules }.count
            print("📅 Found \(fetchedEvents.count) iOS Calendar events in range (\(recurringCount) recurring)")

            // Debug: Show sample of fetched events
            if !fetchedEvents.isEmpty {
                print("📅 Sample events:")
                for event in fetchedEvents.prefix(5) {
                    print("   - \(event.title ?? "No title") | \(event.startDate) | Calendar: \(event.calendar?.title ?? "Unknown")")
                }
            }

            DispatchQueue.main.async {
                // Mark range as loaded
                self.loadedRanges.insert(requestedRange)

                // Merge new events with existing ones (avoid duplicates)
                // For recurring events, check both eventIdentifier AND startDate
                let newEvents = fetchedEvents.filter { newEvent in
                    // Filter out deleted events
                    if let eventId = newEvent.eventIdentifier, self.deletedEventIds.contains(eventId) {
                        return false
                    }
                    // Filter out duplicates
                    return !self.events.contains { existingEvent in
                        existingEvent.eventIdentifier == newEvent.eventIdentifier &&
                        existingEvent.startDate == newEvent.startDate
                    }
                }

                self.events.append(contentsOf: newEvents)
                self.events.sort { $0.startDate < $1.startDate }

                print("📅 Added \(newEvents.count) new events (filtered deleted), total: \(self.events.count)")

                // Perform cache eviction if needed
                self.evictOldEventsIfNeeded()

                // Reload unified events
                self.loadAllUnifiedEvents()

                // Update success state
                self.lastSyncDate = Date()
                self.isLoading = false
                self.errorState = nil
            }
        } catch {
            print("❌ Error loading events: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorState = .failedToLoadEvents(error)
                self.isLoading = false
                HapticManager.shared.error()
            }
        }
    }

    /// Check if a date range is already loaded
    private func isRangeLoaded(_ range: DateInterval) -> Bool {
        // Check if the requested range overlaps significantly with any loaded range
        for loadedRange in loadedRanges {
            if loadedRange.contains(range.start) && loadedRange.contains(range.end) {
                return true
            }
        }
        return false
    }

    /// Load additional months when user navigates to dates outside current range
    func loadAdditionalMonthsIfNeeded(for date: Date) {
        let calendar = Calendar.current

        // Calculate the currently loaded date range
        guard let currentStart = calendar.date(byAdding: .month, value: -monthsBackToLoad, to: Date()),
              let currentEnd = calendar.date(byAdding: .month, value: monthsForwardToLoad, to: Date()) else {
            return
        }

        // Check if the requested date is near the boundaries
        let threshold: TimeInterval = 7 * 24 * 60 * 60 // 1 week threshold

        if date < currentStart.addingTimeInterval(threshold) {
            // User is near the past boundary - load 3 more months back
            print("📅 Loading additional months in the past")
            if let newStart = calendar.date(byAdding: .month, value: -3, to: currentStart) {
                loadEventsInRange(startDate: newStart, endDate: currentStart)
            }
        } else if date > currentEnd.addingTimeInterval(-threshold) {
            // User is near the future boundary - load 3 more months forward
            print("📅 Loading additional months in the future")
            if let newEnd = calendar.date(byAdding: .month, value: 3, to: currentEnd) {
                loadEventsInRange(startDate: currentEnd, endDate: newEnd)
            }
        }
    }

    /// Retry the last failed operation
    func retryLastOperation() {
        print("🔄 Retrying last failed operation")
        errorState = nil
        loadEvents()
    }

    /// Clear error state
    func dismissError() {
        errorState = nil
    }

    /// Evict old events from memory if cache exceeds maximum size
    private func evictOldEventsIfNeeded() {
        guard loadedRanges.count > maxCachedMonths else { return }

        print("🗑️ Cache exceeds \(maxCachedMonths) months, evicting old events")

        let calendar = Calendar.current
        let now = Date()

        // Calculate the retention window (keep events within maxCachedMonths/2 on each side of today)
        let halfWindow = maxCachedMonths / 2
        guard let retentionStart = calendar.date(byAdding: .month, value: -halfWindow, to: now),
              let retentionEnd = calendar.date(byAdding: .month, value: halfWindow, to: now) else {
            return
        }

        // Remove events outside retention window
        let evictedCount = events.count
        events = events.filter { event in
            event.startDate >= retentionStart && event.startDate <= retentionEnd
        }

        print("🗑️ Evicted \(evictedCount - events.count) old events, \(events.count) remaining")

        // Clean up loaded ranges outside retention window
        loadedRanges = loadedRanges.filter { range in
            range.end >= retentionStart && range.start <= retentionEnd
        }

        print("🗑️ Cleaned up loaded ranges, \(loadedRanges.count) ranges remaining")
    }

    func loadAllUnifiedEvents() {
        print("📅 loadAllUnifiedEvents called")
        var allEvents: [UnifiedEvent] = []

        // Load cached events from Core Data as fallback
        let cachedEvents = coreDataManager.fetchEvents()
        print("💾 Loaded \(cachedEvents.count) cached events from Core Data")

        // Add iOS events (these are FRESH and should take priority)
        print("📅 Converting \(events.count) iOS events to unified events")
        print("📍 deletedEventIds contains: \(deletedEventIds.count) events: \(Array(deletedEventIds).prefix(5))")

        let iosEvents = events
            .filter { event in
                // Filter out deleted iOS events
                if let eventId = event.eventIdentifier, deletedEventIds.contains(eventId) {
                    print("🗑️ Filtering out deleted event: \(event.title ?? "Untitled") (ID: \(eventId))")
                    return false
                }
                return true
            }
            .map { event in
                // Extract and set video meeting URL if not already set
                self.ensureVideoURLIsSet(for: event)

                return UnifiedEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    description: event.notes,
                    isAllDay: event.isAllDay,
                    source: .ios,
                    organizer: event.organizer?.name,
                    originalEvent: event,
                    calendarId: event.calendar?.calendarIdentifier,
                    calendarName: event.calendar?.title,
                    calendarColor: event.calendar?.cgColor != nil ? Color(event.calendar!.cgColor) : nil
                )
            }

        // Cache iOS events to Core Data (only non-deleted events)
        coreDataManager.saveEvents(iosEvents, syncStatus: .synced)

        // Add fresh iOS events directly
        allEvents.append(contentsOf: iosEvents)
        print("📱 Added \(iosEvents.count) iOS events to unified list (after filtering deleted)")

        // Add Google events (FRESH, take priority over cached)
        if let googleManager = googleCalendarManager {
            print("📅 Processing \(googleManager.googleEvents.count) Google events")
            print("📍 CalendarManager deletedEventIds contains: \(deletedEventIds.count) events: \(Array(deletedEventIds).prefix(5))")

            let googleEvents = googleManager.googleEvents
                .filter { event in
                    // Filter out deleted events
                    if deletedEventIds.contains(event.id) {
                        print("🗑️ Filtering out deleted Google event: \(event.title) (ID: \(event.id))")
                        return false
                    }
                    return true
                }
                .map { event in
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
                        originalEvent: event,
                        calendarId: nil, // TODO: Add calendar ID from Google event
                        calendarName: nil, // TODO: Add calendar name from Google event
                        calendarColor: nil
                    )
                }

            // Cache Google events to Core Data
            coreDataManager.saveEvents(googleEvents, syncStatus: .synced)

            // Add fresh Google events directly
            allEvents.append(contentsOf: googleEvents)
            print("🟢 Added \(googleEvents.count) Google events to unified list")
        }

        // Add Outlook events (FRESH, take priority over cached)
        if let outlookManager = outlookCalendarManager {
            let outlookEvents = outlookManager.outlookEvents
                .filter { !deletedEventIds.contains($0.id) } // Filter out deleted events
                .map { event in
                    UnifiedEvent(
                        id: event.id,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        location: event.location,
                        description: event.description,
                        isAllDay: event.isAllDay, // Use actual isAllDay value from Outlook
                        source: .outlook,
                        organizer: event.organizer,
                        originalEvent: event,
                        calendarId: event.calendarId,
                        calendarName: nil, // TODO: Add calendar name from Outlook event
                        calendarColor: nil
                    )
                }

            // Cache Outlook events to Core Data
            coreDataManager.saveEvents(outlookEvents, syncStatus: .synced)

            // Add fresh Outlook events directly
            allEvents.append(contentsOf: outlookEvents)
            print("🔵 Added \(outlookEvents.count) Outlook events to unified list")
        }

        // Add cached events ONLY if they don't already exist in fresh events
        // This handles offline scenarios where fresh events aren't available
        let beforeCachedCount = allEvents.count
        for cachedEvent in cachedEvents {
            if !allEvents.contains(where: {
                $0.id == cachedEvent.id &&
                $0.source == cachedEvent.source &&
                $0.startDate == cachedEvent.startDate
            }) {
                allEvents.append(cachedEvent)
            }
        }
        let addedCachedCount = allEvents.count - beforeCachedCount
        print("💾 Added \(addedCachedCount) cached events as fallback")

        // Sort all events by start date
        allEvents = allEvents.sorted { $0.startDate < $1.startDate }

        // Detect and filter duplicate events
        let duplicateGroups = duplicateEventDetector.detectDuplicates(in: allEvents)
        if !duplicateGroups.isEmpty {
            print("🔍 Detected \(duplicateGroups.count) duplicate event groups")
            for group in duplicateGroups {
                print("   - \(group.events.count) duplicates with confidence \(group.confidence): \(group.primaryEvent.title)")
            }

            // Filter out duplicates with confidence > 0.7
            allEvents = duplicateEventDetector.filterDuplicates(from: allEvents)
            print("✨ Filtered duplicates, \(allEvents.count) unique events remaining")
        }

        unifiedEvents = allEvents
        print("✅ Loaded \(unifiedEvents.count) unified events from all sources")

        // Save events to shared storage for widget access
        saveEventsToSharedStorage(unifiedEvents)

        // Schedule smart notifications for all upcoming events
        scheduleSmartNotificationsForEvents(unifiedEvents)

        // Detect conflicts across all events
        detectAllConflicts()
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
            // Generate proactive suggestions after events are loaded
            // TODO: Uncomment when ProactiveSuggestionsManager is added to Xcode project
            // self.generateProactiveSuggestions()
        }
    }

    /// Generate proactive suggestions based on current calendar state
    // TODO: Uncomment when ProactiveSuggestionsManager is added to Xcode project
    /*
    func generateProactiveSuggestions() {
        print("🤖 Triggering proactive suggestions analysis...")
        proactiveSuggestionsManager.analyzeCalendarAndGenerateSuggestions(
            events: unifiedEvents,
            travelTimeManager: travelTimeManager
        )
    }
    */

    func loadOfflineEvents() {
        print("📱 Loading offline events from cache...")

        let cachedEvents = coreDataManager.fetchEvents()

        DispatchQueue.main.async {
            // Filter out deleted events to prevent them from reappearing in offline mode
            let filteredEvents = cachedEvents.filter { event in
                !self.deletedEventIds.contains(event.id)
            }

            let removedCount = cachedEvents.count - filteredEvents.count
            if removedCount > 0 {
                print("🗑️ Filtered out \(removedCount) deleted events from offline cache")
            }

            self.unifiedEvents = filteredEvents.sorted { $0.startDate < $1.startDate }
            print("💾 Loaded \(filteredEvents.count) offline events from Core Data")
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

    var syncErrors: [CalendarSyncError] {
        syncManager.syncErrors
    }

    // MARK: - Widget Data Sharing

    /// Save events to shared storage for widget access
    private func saveEventsToSharedStorage(_ events: [UnifiedEvent]) {
        // Convert UnifiedEvents to WidgetCalendarEvents (lightweight model)
        let widgetEvents = events
            .filter { event in
                // Only include today's and upcoming events (next 7 days)
                let calendar = Calendar.current
                let now = Date()
                let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now

                return event.startDate >= calendar.startOfDay(for: now) && event.startDate <= sevenDaysFromNow
            }
            .map { event in
                WidgetCalendarEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }

        SharedCalendarStorage.shared.saveEvents(widgetEvents)
        print("📲 Saved \(widgetEvents.count) events to shared storage for widget")
    }

    /// Save tasks count to shared storage for widget access
    func saveTasksCountToSharedStorage(_ count: Int) {
        SharedCalendarStorage.shared.saveTasksCount(count)
        print("📲 Saved tasks count (\(count)) to shared storage for widget")
    }

    // MARK: - Calendar Invitations

    /// Fetch pending invitations from all calendar sources
    func fetchInvitations() {
        var allInvitations: [CalendarInvitation] = []

        // 1. Fetch iOS Calendar invitations
        if hasCalendarAccess {
            let calendars = eventStore.calendars(for: .event)
            for calendar in calendars {
                // Get events with pending invitations
                let predicate = eventStore.predicateForEvents(
                    withStart: Date(),
                    end: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                    calendars: [calendar]
                )
                let events = eventStore.events(matching: predicate)

                for event in events {
                    // Check if this is an invitation
                    if event.hasAttendees,
                       let attendees = event.attendees,
                       let currentUser = attendees.first(where: { $0.isCurrentUser }) {

                        let status: InvitationStatus
                        switch currentUser.participantStatus {
                        case .pending: status = .pending
                        case .accepted: status = .accepted
                        case .declined: status = .declined
                        case .tentative: status = .tentative
                        default: status = .pending
                        }

                        let invitation = CalendarInvitation(
                            id: event.eventIdentifier ?? UUID().uuidString,
                            title: event.title ?? "Untitled",
                            organizer: event.organizer?.name,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            location: event.location,
                            notes: event.notes,
                            source: .ios,
                            status: status,
                            originalEvent: event,
                            calendarName: calendar.title
                        )
                        allInvitations.append(invitation)
                    }
                }
            }
            print("📱 Fetched \(allInvitations.count) iOS Calendar invitations")
        }

        // 2. Fetch Google Calendar invitations
        if let googleManager = googleCalendarManager, googleManager.isSignedIn {
            // Iterate through Google events to find invitations
            let googleEvents = googleManager.googleEvents
            for googleEvent in googleEvents {
                // Check if this is an invitation (has attendees and user is an attendee)
                // Note: Google Calendar API provides attendee info in the event
                // For now, we'll check if the event has attendees as a simple heuristic
                // In a full implementation, you'd check GoogleEvent.attendees array

                // Placeholder: Treat all Google events with location as potential invitations
                // In production, you'd check the attendees array from Google Calendar API
                if let _ = googleEvent.location {
                    let invitation = CalendarInvitation(
                        id: googleEvent.id,
                        title: googleEvent.title,
                        organizer: nil, // Would come from Google event organizer
                        startDate: googleEvent.startDate,
                        endDate: googleEvent.endDate,
                        location: googleEvent.location,
                        notes: googleEvent.description,
                        source: .google,
                        status: .pending, // Would check attendee response status
                        originalEvent: nil,
                        calendarName: "Google Calendar"
                    )
                    // Only add if not already in the list (avoid duplicates)
                    if !allInvitations.contains(where: { $0.id == invitation.id }) {
                        // Note: In production, filter by actual invitation status from API
                        // allInvitations.append(invitation)
                    }
                }
            }
            print("🟢 Google Calendar invitations check complete")
        }

        // 3. Fetch Outlook Calendar invitations
        if let outlookManager = outlookCalendarManager, outlookManager.isSignedIn {
            // Iterate through Outlook events to find invitations
            let outlookEvents = outlookManager.outlookEvents
            for outlookEvent in outlookEvents {
                // Check if this is an invitation
                // Note: Microsoft Graph API provides responseStatus in the event
                // For now, we'll use a simple heuristic

                // Placeholder: Check if event has attendees
                if let _ = outlookEvent.location {
                    let invitation = CalendarInvitation(
                        id: outlookEvent.id,
                        title: outlookEvent.title,
                        organizer: outlookEvent.organizer,
                        startDate: outlookEvent.startDate,
                        endDate: outlookEvent.endDate,
                        location: outlookEvent.location,
                        notes: outlookEvent.description,
                        source: .outlook,
                        status: .pending, // Would check responseStatus from API
                        originalEvent: nil,
                        calendarName: "Outlook Calendar"
                    )
                    // Only add if not already in the list (avoid duplicates)
                    if !allInvitations.contains(where: { $0.id == invitation.id }) {
                        // Note: In production, filter by actual invitation status from API
                        // allInvitations.append(invitation)
                    }
                }
            }
            print("📧 Outlook Calendar invitations check complete")
        }

        // Update published properties
        DispatchQueue.main.async {
            self.invitations = allInvitations.sorted { $0.startDate < $1.startDate }
            self.newInvitationsCount = allInvitations.filter { $0.status == .pending }.count
            print("📨 Total invitations fetched: \(allInvitations.count) (\(self.newInvitationsCount) pending)")
            print("   - iOS: \(allInvitations.filter { $0.source == .ios }.count)")
            print("   - Google: \(allInvitations.filter { $0.source == .google }.count)")
            print("   - Outlook: \(allInvitations.filter { $0.source == .outlook }.count)")
        }
    }

    /// Respond to a calendar invitation from any source
    func respondToInvitation(_ invitation: CalendarInvitation, response: InvitationStatus) {
        print("📨 Responding to \(invitation.source.rawValue) invitation: \(invitation.title) - \(response.displayName)")

        switch invitation.source {
        case .ios:
            respondToIOSInvitation(invitation, response: response)
        case .google:
            respondToGoogleInvitation(invitation, response: response)
        case .outlook:
            respondToOutlookInvitation(invitation, response: response)
        }
    }

    /// Respond to iOS Calendar invitation
    private func respondToIOSInvitation(_ invitation: CalendarInvitation, response: InvitationStatus) {
        guard let event = invitation.originalEvent else {
            print("❌ No original event found for iOS invitation")
            return
        }

        // Find the current user as attendee
        guard let attendees = event.attendees,
              let _ = attendees.first(where: { $0.isCurrentUser }) else {
            print("❌ Current user not found in iOS event attendees")
            return
        }

        // Update the event (iOS handles the response automatically)
        do {
            // Note: EKParticipant status is read-only, so we just save the event
            // iOS Calendar will send the response to the organizer
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("✅ iOS invitation response sent: \(response.displayName)")

            // Refresh invitations
            fetchInvitations()

            HapticManager.shared.success()
        } catch {
            print("❌ Failed to respond to iOS invitation: \(error)")
            HapticManager.shared.error()
        }
    }

    /// Respond to Google Calendar invitation
    private func respondToGoogleInvitation(_ invitation: CalendarInvitation, response: InvitationStatus) {
        print("🟢 Responding to Google Calendar invitation: \(invitation.title) with \(response.displayName)")

        guard let googleManager = googleCalendarManager else {
            print("❌ Google Calendar Manager not available")
            HapticManager.shared.error()
            return
        }

        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No Google user signed in")
            HapticManager.shared.error()
            return
        }

        let accessToken = user.accessToken.tokenString
        let calendarId = invitation.calendarName ?? "primary"

        // Convert invitation status to Google Calendar responseStatus
        let responseStatus: String
        switch response {
        case .accepted: responseStatus = "accepted"
        case .declined: responseStatus = "declined"
        case .tentative: responseStatus = "tentative"
        case .pending: responseStatus = "needsAction"
        }

        // Make Google Calendar API PATCH request
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(invitation.id)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Google invitation response")
            HapticManager.shared.error()
            return
        }

        // Create PATCH request body with attendee response
        // Note: We need to update the attendee's responseStatus
        let requestBody: [String: Any] = [
            "attendees": [
                [
                    "email": user.profile?.email ?? "",
                    "responseStatus": responseStatus
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize JSON for Google invitation response")
            HapticManager.shared.error()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        Task {
            do {
                let (data, httpResponse) = try await URLSession.shared.data(for: request)

                if let response = httpResponse as? HTTPURLResponse {
                    if response.statusCode == 200 {
                        print("✅ Google Calendar invitation response successful")

                        // Refresh invitations to update local state
                        await MainActor.run {
                            self.fetchInvitations()
                            HapticManager.shared.success()
                        }
                    } else {
                        print("❌ Google Calendar API returned status \(response.statusCode)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        await MainActor.run {
                            HapticManager.shared.error()
                        }
                    }
                }
            } catch {
                print("❌ Network error responding to Google invitation: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }

    /// Respond to Outlook Calendar invitation
    private func respondToOutlookInvitation(_ invitation: CalendarInvitation, response: InvitationStatus) {
        print("📧 Responding to Outlook Calendar invitation: \(invitation.title) with \(response.displayName)")

        guard let outlookManager = outlookCalendarManager else {
            print("❌ Outlook Calendar Manager not available")
            HapticManager.shared.error()
            return
        }

        guard let accessToken = outlookManager.currentAccessToken else {
            print("❌ No Outlook access token available")
            HapticManager.shared.error()
            return
        }

        // Determine the Microsoft Graph API endpoint based on response type
        let endpoint: String
        switch response {
        case .accepted:
            endpoint = "accept"
        case .declined:
            endpoint = "decline"
        case .tentative:
            endpoint = "tentativelyAccept"
        case .pending:
            print("⚠️ Cannot set invitation back to pending status")
            HapticManager.shared.warning()
            return
        }

        // Make Microsoft Graph API POST request
        guard let encodedEventId = invitation.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            print("❌ Failed to encode event ID")
            HapticManager.shared.error()
            return
        }

        let urlString = "https://graph.microsoft.com/v1.0/me/events/\(encodedEventId)/\(endpoint)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Outlook invitation response")
            HapticManager.shared.error()
            return
        }

        // Create POST request body (optional: can include a comment)
        let requestBody: [String: Any] = [
            "comment": "Response sent from CalAI"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize JSON for Outlook invitation response")
            HapticManager.shared.error()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        Task {
            do {
                let (data, httpResponse) = try await URLSession.shared.data(for: request)

                if let response = httpResponse as? HTTPURLResponse {
                    if response.statusCode == 202 || response.statusCode == 200 {
                        print("✅ Outlook Calendar invitation response successful (status: \(response.statusCode))")

                        // Refresh invitations to update local state
                        await MainActor.run {
                            self.fetchInvitations()
                            HapticManager.shared.success()
                        }
                    } else {
                        print("❌ Microsoft Graph API returned status \(response.statusCode)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        await MainActor.run {
                            HapticManager.shared.error()
                        }
                    }
                }
            } catch {
                print("❌ Network error responding to Outlook invitation: \(error)")
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }

    // MARK: - Calendar Visibility Management

    /// Check if a calendar is visible
    func isCalendarVisible(_ calendarId: String) -> Bool {
        return visibleCalendarIds.contains(calendarId)
    }

    /// Toggle calendar visibility
    func toggleCalendarVisibility(_ calendarId: String) {
        if visibleCalendarIds.contains(calendarId) {
            visibleCalendarIds.remove(calendarId)
        } else {
            visibleCalendarIds.insert(calendarId)
        }
        // Trigger a refresh of the UI
        objectWillChange.send()
    }

    /// Show all calendars
    func showAllCalendars() {
        visibleCalendarIds = Set(iosCalendars.map { $0.calendarIdentifier })
        objectWillChange.send()
    }

    /// Hide all calendars
    func hideAllCalendars() {
        visibleCalendarIds.removeAll()
        objectWillChange.send()
    }

    /// Get event count for a specific calendar
    func getEventCount(for calendarId: String) -> Int {
        return unifiedEvents.filter { $0.calendarId == calendarId }.count
    }

    // MARK: - Event Modification Methods

    /// Update a unified event with new details
    func updateEvent(_ event: UnifiedEvent) {
        print("📝 Updating event: \(event.title)")

        switch event.source {
        case .ios:
            updateIOSEvent(event)
        case .google:
            updateGoogleEvent(event)
        case .outlook:
            updateOutlookEvent(event)
        }

        // Update in Core Data
        coreDataManager.saveEvent(event, syncStatus: .pending)

        // Refresh unified events
        DispatchQueue.main.async {
            self.loadAllUnifiedEvents()
        }
    }

    /// Delete a unified event
    func deleteEvent(_ event: UnifiedEvent, refreshUnifiedEvents: Bool = true) {
        print("🗑️ Deleting event: \(event.title)")

        switch event.source {
        case .ios:
            deleteIOSEventById(event.id)
        case .google:
            deleteGoogleEvent(event)
        case .outlook:
            deleteOutlookEvent(event)
        }

        // Delete from Core Data
        coreDataManager.permanentlyDeleteEvent(eventId: event.id, source: event.source)

        // Note: For Google/Outlook, the async deletion tasks handle removing from unifiedEvents
        // For iOS, we need to manually remove and refresh
        if event.source == .ios && refreshUnifiedEvents {
            DispatchQueue.main.async {
                // Remove from unified events immediately
                self.unifiedEvents.removeAll { $0.id == event.id && $0.source == .ios }

                // Track deletion
                self.trackDeletedEvent(event.id, source: .ios)

                // Trigger UI refresh
                self.objectWillChange.send()
                print("✅ iOS event deleted and UI refreshed")
            }
        }
    }

    // MARK: - Private Update Helpers

    private func updateIOSEvent(_ event: UnifiedEvent) {
        guard hasCalendarAccess else {
            print("❌ No calendar access for iOS event update")
            return
        }

        // Find the existing event
        guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
            print("❌ iOS event not found: \(event.id)")
            return
        }

        // Update properties
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.location = event.location
        ekEvent.notes = event.description
        ekEvent.isAllDay = event.isAllDay

        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
            print("✅ iOS event updated successfully")
        } catch {
            print("❌ Failed to update iOS event: \(error)")
        }
    }

    private func updateGoogleEvent(_ event: UnifiedEvent) {
        // Google Calendar update would go through Google Calendar API
        // For now, just update in Core Data
        print("⚠️ Google Calendar API update not yet implemented")
        coreDataManager.saveEvent(event, syncStatus: .pending)
    }

    private func updateOutlookEvent(_ event: UnifiedEvent) {
        // Outlook update would go through Outlook API
        // For now, just update in Core Data
        print("⚠️ Outlook API update not yet implemented")
        coreDataManager.saveEvent(event, syncStatus: .pending)
    }

    private func deleteIOSEventById(_ eventId: String) {
        guard hasCalendarAccess else {
            print("❌ No calendar access for iOS event deletion")
            return
        }

        guard let ekEvent = eventStore.event(withIdentifier: eventId) else {
            print("❌ iOS event not found: \(eventId)")
            return
        }

        deleteEvent(ekEvent)
    }

    private func deleteGoogleEvent(_ event: UnifiedEvent) {
        guard let googleManager = googleCalendarManager else {
            print("❌ Google Calendar not connected")
            return
        }

        // Add to deleted events tracking
        trackDeletedEvent(event.id, source: .google)

        Task {
            print("🗑️ Deleting Google event via API: \(event.title)")
            let success = await googleManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                // This ensures the event is removed locally even if server delete fails
                coreDataManager.permanentlyDeleteEvent(eventId: event.id, source: .google)

                // Remove from unified events array immediately
                let beforeCount = self.unifiedEvents.count
                self.unifiedEvents.removeAll {
                    $0.id == event.id && $0.source == .google
                }
                let afterCount = self.unifiedEvents.count
                print("✅ Removed from unified events: \(beforeCount) -> \(afterCount)")

                // Verify event is completely removed
                let stillExists = self.unifiedEvents.contains {
                    $0.id == event.id && $0.source == .google
                }

                if stillExists {
                    print("⚠️ WARNING: Event still exists in unified events after deletion!")
                } else {
                    print("✅ VERIFIED: Event completely removed from all arrays")
                }

                // Force UI refresh by triggering objectWillChange
                self.objectWillChange.send()
                print("🔄 Triggered UI refresh via objectWillChange")

                if success {
                    print("✅ Google event deleted successfully from server and cache")
                } else {
                    print("⚠️ Failed to delete from Google server, but removed from local cache")
                }
            }
        }
    }

    private func deleteOutlookEvent(_ event: UnifiedEvent) {
        guard let outlookManager = outlookCalendarManager else {
            print("❌ Outlook Calendar not connected")
            return
        }

        // Add to deleted events tracking
        trackDeletedEvent(event.id, source: .outlook)

        Task {
            print("🗑️ Deleting Outlook event via API: \(event.title)")
            let success = await outlookManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                // This ensures the event is removed locally even if server delete fails
                coreDataManager.permanentlyDeleteEvent(eventId: event.id, source: .outlook)

                // Remove from unified events array immediately
                let beforeCount = self.unifiedEvents.count
                self.unifiedEvents.removeAll {
                    $0.id == event.id && $0.source == .outlook
                }
                let afterCount = self.unifiedEvents.count
                print("✅ Removed from unified events: \(beforeCount) -> \(afterCount)")

                // Verify event is completely removed
                let stillExists = self.unifiedEvents.contains {
                    $0.id == event.id && $0.source == .outlook
                }

                if stillExists {
                    print("⚠️ WARNING: Event still exists in unified events after deletion!")
                } else {
                    print("✅ VERIFIED: Event completely removed from all arrays")
                }

                // Force UI refresh by triggering objectWillChange
                self.objectWillChange.send()
                print("🔄 Triggered UI refresh via objectWillChange")

                if success {
                    print("✅ Outlook event deleted successfully from server and cache")
                } else {
                    print("⚠️ Failed to delete from Outlook server, but removed from local cache")
                }
            }
        }
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

    func createEvent(title: String, startDate: Date, endDate: Date? = nil, location: String? = nil, notes: String? = nil, participants: [String]? = nil, calendarSource: String? = nil, skipConflictCheck: Bool = false, onConflict: ((ConflictResult) -> Void)? = nil) {
        print("📝 Creating calendar event: \(title) in \(calendarSource ?? "default") calendar")

        let actualEndDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate

        // Check for conflicts BEFORE creating the event (unless explicitly skipped)
        if !skipConflictCheck {
            let conflictResult = checkConflicts(startDate: startDate, endDate: actualEndDate)

            if conflictResult.hasConflict {
                print("🚨 Conflict detected! Not creating event automatically.")
                onConflict?(conflictResult)
                return
            }
        }

        // Route to appropriate calendar based on source
        if let source = calendarSource {
            switch source.lowercased() {
            case "google":
                print("⚠️ Google Calendar event creation not yet implemented via voice, using iOS calendar")
                // TODO: Implement Google Calendar event creation
                // Fall through to iOS calendar
                break
            case "outlook":
                print("⚠️ Outlook Calendar event creation not yet implemented via voice, using iOS calendar")
                // TODO: Implement Outlook Calendar event creation
                // Fall through to iOS calendar
                break
            case "ios":
                // Continue to iOS calendar creation below
                break
            default:
                print("⚠️ Unknown calendar source: \(source), using iOS calendar")
            }
        }

        // iOS calendar creation
        guard hasCalendarAccess else {
            print("❌ No calendar access for event creation")
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = actualEndDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        if let location = location {
            event.location = location

            // Extract and set URL if location contains a video meeting link
            if let videoURL = extractVideoMeetingURL(from: location) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in location: \(videoURL.absoluteString)")
            }
        }

        if let notes = notes {
            event.notes = notes

            // Extract and set URL if notes contain a video meeting link (only if not already set)
            if event.url == nil, let videoURL = extractVideoMeetingURL(from: notes) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in notes: \(videoURL.absoluteString)")
            }
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

            // Learn from this event creation for contextual memory
            // TODO: Uncomment when ContextualMemoryManager is added to Xcode project
            /*
            let unifiedEvent = UnifiedEvent(
                id: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                source: .iOS,
                color: event.calendar.cgColor,
                attendees: [],
                isAllDay: event.isAllDay
            )
            ContextualMemoryManager.shared.observeEventPattern(from: unifiedEvent)
            */
        } catch {
            print("❌ Error creating event: \(error)")
        }
    }

    // Create event in a specific calendar
    @discardableResult
    func createEventInCalendar(calendar: EKCalendar, title: String, startDate: Date, endDate: Date, location: String? = nil, notes: String? = nil, isAllDay: Bool = false) -> EKEvent? {
        print("📝 Creating event in specific calendar: \(calendar.title)")

        guard hasCalendarAccess else {
            print("❌ No calendar access for event creation")
            return nil
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.isAllDay = isAllDay

        if let location = location {
            event.location = location

            // Extract and set URL if location contains a video meeting link
            if let videoURL = extractVideoMeetingURL(from: location) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in location: \(videoURL.absoluteString)")
            }
        }

        if let notes = notes {
            event.notes = notes

            // Extract and set URL if notes contain a video meeting link (only if not already set)
            if event.url == nil, let videoURL = extractVideoMeetingURL(from: notes) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in notes: \(videoURL.absoluteString)")
            }
        }

        print("📅 Event details: \(title) from \(startDate) to \(endDate) in \(calendar.title)")

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event saved successfully to \(calendar.title)")
            HapticManager.shared.success()
            loadEvents()
            return event
        } catch {
            print("❌ Error creating event: \(error)")
            HapticManager.shared.error()
            return nil
        }
    }

    private func createAttendee(for participant: String, in event: EKEvent) -> EKParticipant? {
        // This is a simplified approach since EKParticipant creation is complex
        // In a real implementation, you'd need to handle contact resolution
        return nil
    }

    func deleteEvent(_ event: EKEvent) {
        print("🗑️ Deleting iOS event: \(event.title ?? "Untitled")")
        print("📍 Event ID: \(event.eventIdentifier ?? "nil")")
        print("📍 Event calendar: \(event.calendar?.title ?? "nil")")

        guard hasCalendarAccess else {
            print("❌ No calendar access for event deletion")
            return
        }

        // Set flag to prevent reload triggered by EventKit change notification
        isPerformingInternalDeletion = true
        print("🚫 Set isPerformingInternalDeletion = true")

        let eventId = event.eventIdentifier

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            print("✅ iOS event deleted successfully from iOS Calendar")

            // Track deletion to prevent reappearance
            if let eventId = eventId {
                print("📍 Tracking deletion for event ID: \(eventId)")
                trackDeletedEvent(eventId, source: .ios)
                print("📍 deletedEventIds now contains: \(deletedEventIds.count) events")

                // Delete from Core Data cache
                coreDataManager.permanentlyDeleteEvent(eventId: eventId, source: .ios)
                print("✅ Deleted from Core Data cache and tracked in deletedEventIds")

                // Remove from iOS events array immediately
                let countBefore = events.count
                events.removeAll { $0.eventIdentifier == eventId }
                let countAfter = events.count
                print("🗑️ Removed from iOS events array: \(countBefore) -> \(countAfter) (removed \(countBefore - countAfter) events)")
            } else {
                print("⚠️ Event has no eventIdentifier, cannot track deletion!")
            }

            // Remove from unified events immediately
            let unifiedBefore = unifiedEvents.count
            unifiedEvents.removeAll { $0.id == eventId && $0.source == .ios }
            let unifiedAfter = unifiedEvents.count
            print("🗑️ Removed from unified events: \(unifiedBefore) -> \(unifiedAfter) (removed \(unifiedBefore - unifiedAfter) events)")

            // Verify event is completely removed
            let stillExists = unifiedEvents.contains { $0.id == eventId && $0.source == .ios }
            if stillExists {
                print("⚠️ WARNING: Event still exists in unified events after deletion!")
            } else {
                print("✅ VERIFIED: Event completely removed from all arrays")
            }

            // Force UI refresh by triggering objectWillChange
            objectWillChange.send()
            print("🔄 Triggered UI refresh via objectWillChange")

            // Clear the deletion flag after a short delay to allow EventKit notification to fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isPerformingInternalDeletion = false
                print("✅ Cleared isPerformingInternalDeletion flag")
            }
        } catch {
            print("❌ Error deleting iOS event: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // Clear the deletion flag even on error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isPerformingInternalDeletion = false
                print("✅ Cleared isPerformingInternalDeletion flag (after error)")
            }
        }
    }

    func findBestTimeSlot(durationMinutes: Int, startDate: Date, endDate: Date) -> Date? {
        print("🔍 Finding best time slot: \(durationMinutes) minutes between \(startDate) and \(endDate)")

        let calendar = Calendar.current
        let duration = TimeInterval(durationMinutes * 60)

        // Get all events in the date range
        let eventsInRange = unifiedEvents.filter { event in
            event.startDate >= startDate && event.endDate <= endDate
        }.sorted { $0.startDate < $1.startDate }

        print("📅 Found \(eventsInRange.count) events in range")

        // Define work hours (9 AM - 5 PM)
        let workStartHour = 9
        let workEndHour = 17
        let lunchStartHour = 12
        let lunchEndHour = 13

        var currentDate = calendar.startOfDay(for: startDate)
        let endOfRange = calendar.startOfDay(for: endDate).addingTimeInterval(24 * 60 * 60)

        var bestSlots: [(date: Date, score: Int)] = []

        while currentDate < endOfRange {
            // Skip weekends
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }

            // Check each 30-minute slot during work hours
            var workStart = calendar.date(bySettingHour: workStartHour, minute: 0, second: 0, of: currentDate)!
            let workEnd = calendar.date(bySettingHour: workEndHour, minute: 0, second: 0, of: currentDate)!

            while workStart.addingTimeInterval(duration) <= workEnd {
                let slotEnd = workStart.addingTimeInterval(duration)

                // Check if slot conflicts with existing events
                let hasConflict = eventsInRange.contains { event in
                    (workStart >= event.startDate && workStart < event.endDate) ||
                    (slotEnd > event.startDate && slotEnd <= event.endDate) ||
                    (workStart <= event.startDate && slotEnd >= event.endDate)
                }

                if !hasConflict {
                    // Score the slot (higher is better)
                    var score = 100

                    let hour = calendar.component(.hour, from: workStart)

                    // Prefer morning slots (9-11 AM)
                    if hour >= 9 && hour < 11 {
                        score += 30
                    }
                    // Afternoon slots (2-4 PM)
                    else if hour >= 14 && hour < 16 {
                        score += 20
                    }
                    // Late morning (11 AM - 12 PM)
                    else if hour >= 11 && hour < 12 {
                        score += 10
                    }

                    // Avoid lunch hour (12-1 PM)
                    if hour >= lunchStartHour && hour < lunchEndHour {
                        score -= 50
                    }

                    // Prefer earlier in the week
                    let dayOfWeek = calendar.component(.weekday, from: workStart)
                    if dayOfWeek == 2 { // Monday
                        score += 5
                    } else if dayOfWeek == 3 { // Tuesday
                        score += 10
                    } else if dayOfWeek == 4 { // Wednesday
                        score += 8
                    }

                    bestSlots.append((date: workStart, score: score))
                }

                // Move to next 30-minute slot
                workStart = workStart.addingTimeInterval(30 * 60)
            }

            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Sort by score and return best slot
        let bestSlot = bestSlots.sorted { $0.score > $1.score }.first

        if let best = bestSlot {
            print("✅ Best time slot found: \(best.date) with score \(best.score)")
            return best.date
        } else {
            print("❌ No available time slots found")
            return nil
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
                print("✅ Creating event: \(title) at \(startDate) in \(command.calendarSource ?? "default") calendar")
                let endDate = command.endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!

                // Voice-created events skip conflict check since the AI already warned the user
                createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: command.endDate,
                    location: command.location,
                    notes: command.notes,
                    participants: command.participants,
                    calendarSource: command.calendarSource,
                    skipConflictCheck: true  // ← ADDED: Skip conflicts for voice commands
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

        case .findBestTime:
            print("🎯 Find best time: \(command.durationMinutes ?? 15) minutes")
            let duration = command.durationMinutes ?? 15
            let calendar = Calendar.current
            let now = Date()

            // Determine search range
            let searchStart: Date
            let searchEnd: Date

            if let queryStart = command.queryStartDate, let queryEnd = command.queryEndDate {
                searchStart = queryStart
                searchEnd = queryEnd
            } else {
                // Default to next week
                searchStart = calendar.date(byAdding: .day, value: 1, to: now)!
                searchEnd = calendar.date(byAdding: .day, value: 7, to: searchStart)!
            }

            if let bestTime = findBestTimeSlot(durationMinutes: duration, startDate: searchStart, endDate: searchEnd) {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                formatter.timeStyle = .short

                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEEE"

                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short

                let message = "The best time is \(dayFormatter.string(from: bestTime)) at \(timeFormatter.string(from: bestTime))"
                print("✅ Best time found: \(message)")

                // Send notification with result
                NotificationCenter.default.post(
                    name: NSNotification.Name("AvailabilityResult"),
                    object: nil,
                    userInfo: ["message": message]
                )
            } else {
                let message = "No available time slots found in the specified range"
                print("❌ \(message)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("AvailabilityResult"),
                    object: nil,
                    userInfo: ["message": message]
                )
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
            print("📝 Update event: \(command.searchQuery ?? command.title ?? "event")")
            if let searchQuery = command.searchQuery ?? command.title {
                updateEvent(
                    searchQuery: searchQuery,
                    newTitle: command.newTitle,
                    newStartDate: command.newStartDate,
                    newEndDate: command.newEndDate,
                    newLocation: command.newLocation,
                    newNotes: command.notes
                )
            } else {
                print("❌ Missing search query for event update")
            }

        case .deleteEvent:
            print("🗑️ Delete event: \(command.searchQuery ?? command.title ?? command.eventId ?? "event")")

            // Try deleting by exact event ID first (from conversational AI)
            if let eventId = command.eventId {
                deleteEventById(eventId: eventId)
            }
            // Fallback to search query
            else if let searchQuery = command.searchQuery ?? command.title {
                deleteEventBySearch(searchQuery: searchQuery)
            } else {
                print("❌ Missing event ID or search query for event deletion")
            }

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
            print("🔄 Set recurring: \(command.searchQuery ?? command.title ?? "event")")
            if let searchQuery = command.searchQuery ?? command.title,
               let pattern = command.recurringPattern {
                setEventRecurring(searchQuery: searchQuery, pattern: pattern)
            } else if let title = command.title,
                      let startDate = command.startDate,
                      let pattern = command.recurringPattern {
                // Create new recurring event
                createRecurringEvent(
                    title: title,
                    startDate: startDate,
                    endDate: command.endDate,
                    pattern: pattern,
                    location: command.location,
                    notes: command.notes
                )
            } else {
                print("❌ Missing required fields for recurring event")
            }

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

        // Search across all calendar sources
        let matchingUnifiedEvents = unifiedEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(searchQuery)
        }

        guard let eventToReschedule = matchingUnifiedEvents.first else {
            postNotificationMessage("❌ Could not find event matching '\(searchQuery)'")
            return
        }

        // Calculate duration if newEndDate not provided
        let originalDuration = eventToReschedule.endDate.timeIntervalSince(eventToReschedule.startDate)
        let calculatedEndDate = newEndDate ?? newStartDate.addingTimeInterval(originalDuration)

        print("📍 Rescheduling '\(eventToReschedule.title)' on \(eventToReschedule.sourceLabel)")

        // Update based on calendar source - use existing updateEvent function
        updateEvent(
            searchQuery: searchQuery,
            newStartDate: newStartDate,
            newEndDate: calculatedEndDate
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let message = "✅ Rescheduled '\(eventToReschedule.title)' to \(formatter.string(from: newStartDate))"
        postNotificationMessage(message)
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

    /// Update an existing event with new details
    private func updateEvent(searchQuery: String, newTitle: String? = nil, newStartDate: Date? = nil, newEndDate: Date? = nil, newLocation: String? = nil, newNotes: String? = nil) {
        print("📝 Updating event matching: '\(searchQuery)'")

        // Search across all calendar sources
        let matchingUnifiedEvents = unifiedEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(searchQuery)
        }

        guard let eventToUpdate = matchingUnifiedEvents.first else {
            let message = "❌ Could not find event matching '\(searchQuery)'"
            postNotificationMessage(message)
            return
        }

        print("📍 Found event: '\(eventToUpdate.title)' on \(eventToUpdate.sourceLabel)")

        // Update based on calendar source
        switch eventToUpdate.source {
        case .ios:
            updateIOSEvent(eventId: eventToUpdate.id, newTitle: newTitle, newStartDate: newStartDate, newEndDate: newEndDate, newLocation: newLocation, newNotes: newNotes)

        case .google:
            updateGoogleEvent(eventId: eventToUpdate.id, newTitle: newTitle, newStartDate: newStartDate, newEndDate: newEndDate, newLocation: newLocation, newNotes: newNotes)

        case .outlook:
            updateOutlookEvent(eventId: eventToUpdate.id, newTitle: newTitle, newStartDate: newStartDate, newEndDate: newEndDate, newLocation: newLocation, newNotes: newNotes)
        }
    }

    private func updateIOSEvent(eventId: String, newTitle: String?, newStartDate: Date?, newEndDate: Date?, newLocation: String?, newNotes: String?) {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            postNotificationMessage("❌ Could not find iOS event")
            return
        }

        var changes: [String] = []

        if let newTitle = newTitle {
            event.title = newTitle
            changes.append("title")
        }

        if let newStartDate = newStartDate {
            event.startDate = newStartDate
            changes.append("start time")
        }

        if let newEndDate = newEndDate {
            event.endDate = newEndDate
            changes.append("end time")
        }

        if let newLocation = newLocation {
            event.location = newLocation
            changes.append("location")
        }

        if let newNotes = newNotes {
            event.notes = newNotes
            changes.append("notes")
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            let changesList = changes.joined(separator: ", ")
            postNotificationMessage("✅ Updated '\(event.title ?? "event")': \(changesList)")
            loadEvents()
        } catch {
            postNotificationMessage("❌ Failed to update event: \(error.localizedDescription)")
        }
    }

    private func updateGoogleEvent(eventId: String, newTitle: String?, newStartDate: Date?, newEndDate: Date?, newLocation: String?, newNotes: String?) {
        guard let googleManager = googleCalendarManager else {
            postNotificationMessage("❌ Google Calendar not connected")
            return
        }

        // TODO: Implement Google Calendar update via API
        postNotificationMessage("⚠️ Google Calendar event update coming soon. Update via Google Calendar app for now.")
    }

    private func updateOutlookEvent(eventId: String, newTitle: String?, newStartDate: Date?, newEndDate: Date?, newLocation: String?, newNotes: String?) {
        guard let outlookManager = outlookCalendarManager else {
            postNotificationMessage("❌ Outlook Calendar not connected")
            return
        }

        // TODO: Implement Outlook Calendar update via API
        postNotificationMessage("⚠️ Outlook Calendar event update coming soon. Update via Outlook app for now.")
    }

    /// Delete an event by search query
    private func deleteEventById(eventId: String) {
        print("🗑️ Deleting event by ID: '\(eventId)'")

        // Find event by exact ID
        guard let eventToDelete = unifiedEvents.first(where: { $0.id == eventId }) else {
            print("❌ Could not find event with ID '\(eventId)'")
            postNotificationMessage("❌ Could not find that event")
            return
        }

        print("📍 Found event: '\(eventToDelete.title)' on \(eventToDelete.sourceLabel)")

        // Delete based on calendar source
        switch eventToDelete.source {
        case .ios:
            if let ekEvent = eventToDelete.originalEvent as? EKEvent {
                deleteEvent(ekEvent)
            } else {
                print("❌ Could not cast to EKEvent")
                postNotificationMessage("❌ Failed to delete event")
            }

        case .google:
            deleteGoogleEventBySearch(eventId: eventToDelete.id)

        case .outlook:
            deleteOutlookEventBySearch(eventId: eventToDelete.id)
        }
    }

    private func deleteEventBySearch(searchQuery: String) {
        print("🗑️ Deleting event matching: '\(searchQuery)'")

        // Search across all calendar sources
        let matchingUnifiedEvents = unifiedEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(searchQuery)
        }

        guard let eventToDelete = matchingUnifiedEvents.first else {
            postNotificationMessage("❌ Could not find event matching '\(searchQuery)'")
            return
        }

        print("📍 Found event: '\(eventToDelete.title)' on \(eventToDelete.sourceLabel)")

        // Delete based on calendar source
        switch eventToDelete.source {
        case .ios:
            if let ekEvent = eventToDelete.originalEvent as? EKEvent {
                deleteEvent(ekEvent)
            }

        case .google:
            deleteGoogleEventBySearch(eventId: eventToDelete.id)

        case .outlook:
            deleteOutlookEventBySearch(eventId: eventToDelete.id)
        }
    }

    private func deleteGoogleEventBySearch(eventId: String) {
        guard let googleManager = googleCalendarManager else {
            postNotificationMessage("❌ Google Calendar not connected")
            return
        }

        Task {
            do {
                try await googleManager.deleteEvent(eventId: eventId)
                await MainActor.run {
                    postNotificationMessage("✅ Deleted event from Google Calendar")
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    postNotificationMessage("❌ Failed to delete Google event: \(error.localizedDescription)")
                }
            }
        }
    }

    private func deleteOutlookEventBySearch(eventId: String) {
        guard let outlookManager = outlookCalendarManager else {
            postNotificationMessage("❌ Outlook Calendar not connected")
            return
        }

        Task {
            do {
                try await outlookManager.deleteEvent(eventId: eventId)
                await MainActor.run {
                    postNotificationMessage("✅ Deleted event from Outlook Calendar")
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    postNotificationMessage("❌ Failed to delete Outlook event: \(error.localizedDescription)")
                }
            }
        }
    }

    private func removeAttendeesFromEvent(searchQuery: String, attendees: [String]) {
        print("👤 Removing attendees from event: \(searchQuery)")

        // Find the event
        let matchingUnifiedEvents = unifiedEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(searchQuery)
        }

        guard let event = matchingUnifiedEvents.first else {
            postNotificationMessage("❌ Could not find event matching '\(searchQuery)'")
            return
        }

        let attendeeList = attendees.joined(separator: ", ")
        postNotificationMessage("ℹ️ Note: '\(attendeeList)' removed from '\(event.title)'. iOS Calendar doesn't support attendee modification via API. Please update manually in Calendar app.")
    }

    /// Create a new recurring event
    private func createRecurringEvent(title: String, startDate: Date, endDate: Date?, pattern: String, location: String?, notes: String?) {
        print("🔄 Creating recurring event: \(title) with pattern: \(pattern)")

        guard hasCalendarAccess else {
            postNotificationMessage("❌ No calendar access")
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        if let location = location {
            event.location = location

            // Extract and set URL if location contains a video meeting link
            if let videoURL = extractVideoMeetingURL(from: location) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in location: \(videoURL.absoluteString)")
            }
        }

        if let notes = notes {
            event.notes = notes

            // Extract and set URL if notes contain a video meeting link (only if not already set)
            if event.url == nil, let videoURL = extractVideoMeetingURL(from: notes) {
                event.url = videoURL
                print("🔗 Detected video meeting URL in notes: \(videoURL.absoluteString)")
            }
        }

        // Parse recurring pattern and create recurrence rule
        if let recurrenceRule = parseRecurrencePattern(pattern) {
            event.recurrenceRules = [recurrenceRule]
        }

        do {
            try eventStore.save(event, span: .futureEvents)
            postNotificationMessage("✅ Created recurring event: '\(title)'")
            loadEvents()
        } catch {
            postNotificationMessage("❌ Failed to create recurring event: \(error.localizedDescription)")
        }
    }

    /// Set an existing event to be recurring
    private func setEventRecurring(searchQuery: String, pattern: String) {
        print("🔄 Setting event '\(searchQuery)' to recurring: \(pattern)")

        // Find matching events (iOS only for now)
        let matchingEvents = events.filter { event in
            return event.title?.localizedCaseInsensitiveContains(searchQuery) == true
        }

        guard let eventToUpdate = matchingEvents.first else {
            postNotificationMessage("❌ Could not find event matching '\(searchQuery)'")
            return
        }

        // Parse recurring pattern and create recurrence rule
        if let recurrenceRule = parseRecurrencePattern(pattern) {
            eventToUpdate.recurrenceRules = [recurrenceRule]

            do {
                try eventStore.save(eventToUpdate, span: .futureEvents)
                postNotificationMessage("✅ Set '\(eventToUpdate.title ?? "event")' to recurring")
                loadEvents()
            } catch {
                postNotificationMessage("❌ Failed to set recurring: \(error.localizedDescription)")
            }
        } else {
            postNotificationMessage("❌ Could not parse recurrence pattern: '\(pattern)'")
        }
    }

    /// Parse natural language recurrence pattern into EKRecurrenceRule
    private func parseRecurrencePattern(_ pattern: String) -> EKRecurrenceRule? {
        let lowercased = pattern.lowercased()

        // Daily
        if lowercased.contains("daily") || lowercased.contains("every day") {
            return EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
        }

        // Weekly
        if lowercased.contains("weekly") || lowercased.contains("every week") {
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        }

        // Bi-weekly
        if lowercased.contains("bi-weekly") || lowercased.contains("every other week") || lowercased.contains("biweekly") {
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 2,
                end: nil
            )
        }

        // Monthly
        if lowercased.contains("monthly") || lowercased.contains("every month") {
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )
        }

        // Specific weekdays
        if lowercased.contains("monday") || lowercased.contains("tuesday") || lowercased.contains("wednesday") ||
           lowercased.contains("thursday") || lowercased.contains("friday") {
            var daysOfWeek: [EKRecurrenceDayOfWeek] = []

            if lowercased.contains("monday") { daysOfWeek.append(EKRecurrenceDayOfWeek(.monday)) }
            if lowercased.contains("tuesday") { daysOfWeek.append(EKRecurrenceDayOfWeek(.tuesday)) }
            if lowercased.contains("wednesday") { daysOfWeek.append(EKRecurrenceDayOfWeek(.wednesday)) }
            if lowercased.contains("thursday") { daysOfWeek.append(EKRecurrenceDayOfWeek(.thursday)) }
            if lowercased.contains("friday") { daysOfWeek.append(EKRecurrenceDayOfWeek(.friday)) }

            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: daysOfWeek,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        }

        // Default to weekly if can't parse
        print("⚠️ Could not parse pattern '\(pattern)', defaulting to weekly")
        return EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )
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

    // MARK: - Conflict Detection

    /// Check for conflicts across all calendars for a given time range
    func checkConflicts(startDate: Date, endDate: Date, excludeEventId: String? = nil) -> ConflictResult {
        print("🔍 Checking for conflicts: \(startDate) - \(endDate)")

        var conflictingEvents: [ConflictingEvent] = []

        // Check all unified events for overlaps
        for event in unifiedEvents {
            // Skip the event we're checking against (for reschedules)
            if let excludeId = excludeEventId, event.id == excludeId {
                continue
            }

            // Check for time overlap
            let hasOverlap = (startDate < event.endDate && endDate > event.startDate)

            if hasOverlap {
                let conflictingEvent = ConflictingEvent(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarSource: event.sourceLabel,
                    calendarName: getCalendarName(for: event),
                    location: event.location
                )
                conflictingEvents.append(conflictingEvent)
                print("⚠️ Conflict found: \(event.title) (\(event.sourceLabel))")
            }
        }

        // If conflicts exist, find alternative times
        let alternatives = conflictingEvents.isEmpty ? [] : findAlternativeTimes(
            duration: endDate.timeIntervalSince(startDate),
            aroundDate: startDate,
            count: 3
        )

        let hasConflict = !conflictingEvents.isEmpty

        if hasConflict {
            print("🚨 Found \(conflictingEvents.count) conflict(s)")
        } else {
            print("✅ No conflicts found")
        }

        return ConflictResult(
            hasConflict: hasConflict,
            conflictingEvents: conflictingEvents,
            alternativeTimes: alternatives
        )
    }

    /// Find alternative available time slots
    func findAlternativeTimes(duration: TimeInterval, aroundDate: Date, count: Int) -> [Date] {
        print("🔎 Finding \(count) alternative times around \(aroundDate)")

        let calendar = Calendar.current
        var alternatives: [Date] = []

        // Search parameters
        let searchStart = calendar.startOfDay(for: aroundDate)
        let searchEnd = calendar.date(byAdding: .day, value: 7, to: searchStart)!
        let workStartHour = 9
        let workEndHour = 17

        var currentDate = searchStart

        while alternatives.count < count && currentDate < searchEnd {
            // Skip weekends
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }

            // Check time slots during work hours
            var slotStart = calendar.date(bySettingHour: workStartHour, minute: 0, second: 0, of: currentDate)!
            let dayEnd = calendar.date(bySettingHour: workEndHour, minute: 0, second: 0, of: currentDate)!

            while slotStart.addingTimeInterval(duration) <= dayEnd {
                let slotEnd = slotStart.addingTimeInterval(duration)

                // Check if this slot conflicts with any events
                let hasConflict = unifiedEvents.contains { event in
                    (slotStart < event.endDate && slotEnd > event.startDate)
                }

                if !hasConflict {
                    alternatives.append(slotStart)
                    print("✅ Alternative found: \(slotStart)")

                    if alternatives.count >= count {
                        break
                    }
                }

                // Move to next 30-minute slot
                slotStart = slotStart.addingTimeInterval(30 * 60)
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return alternatives
    }

    /// Get calendar name for an event
    private func getCalendarName(for event: UnifiedEvent) -> String {
        if let ekEvent = event.originalEvent as? EKEvent {
            return ekEvent.calendar?.title ?? "iOS Calendar"
        }
        return "\(event.sourceLabel) Calendar"
    }

    // MARK: - Attention Analysis

    /// Analyze calendar for items that need user attention
    func analyzeAttentionItems() -> String {
        var issues: [String] = []
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        // Get upcoming events (next 7 days)
        let upcomingEvents = unifiedEvents.filter { event in
            event.startDate > now && event.startDate < calendar.date(byAdding: .day, value: 7, to: now)!
        }.sorted { $0.startDate < $1.startDate }

        // 1. Check for conflicts
        let conflicts = detectedConflicts.filter { !isConflictApproved($0) }
        if !conflicts.isEmpty {
            issues.append("⚠️ \(conflicts.count) scheduling conflict\(conflicts.count > 1 ? "s" : "") detected")
        }

        // 2. Check for preparation needs (presentations, demos, important meetings)
        let preparationKeywords = ["presentation", "demo", "pitch", "interview", "executive", "board meeting", "client meeting"]
        let preparationEvents = upcomingEvents.filter { event in
            let title = event.title.lowercased()
            let description = (event.description ?? "").lowercased()
            return preparationKeywords.contains { title.contains($0) || description.contains($0) }
        }
        if !preparationEvents.isEmpty {
            issues.append("📋 \(preparationEvents.count) event\(preparationEvents.count > 1 ? "s" : "") may need preparation")
        }

        // 3. Check for travel warnings (tight gaps between events at different locations)
        var travelWarnings = 0
        for i in 0..<upcomingEvents.count - 1 {
            let current = upcomingEvents[i]
            let next = upcomingEvents[i + 1]

            // Check if events have different locations
            if let currentLoc = current.location, let nextLoc = next.location,
               !currentLoc.isEmpty, !nextLoc.isEmpty, currentLoc != nextLoc {

                // Check gap between events (< 15 minutes)
                let gap = next.startDate.timeIntervalSince(current.endDate) / 60.0
                if gap < 15 {
                    travelWarnings += 1
                }
            }
        }
        if travelWarnings > 0 {
            issues.append("🚗 \(travelWarnings) tight gap\(travelWarnings > 1 ? "s" : "") between events at different locations")
        }

        // 4. Check for missing information
        var missingInfo = 0
        for event in upcomingEvents.prefix(10) {
            if event.location?.isEmpty ?? true || event.description?.isEmpty ?? true {
                missingInfo += 1
            }
        }
        if missingInfo > 0 {
            issues.append("ℹ️ \(missingInfo) upcoming event\(missingInfo > 1 ? "s" : "") missing location or description")
        }

        // 5. Check for pending invites (if detectable from event status)
        // Note: This would require EKEvent status checking, which might not be available for all sources

        // Build summary
        if issues.isEmpty {
            return "✅ Everything looks good! No issues requiring attention."
        } else {
            let summary = "Here's what needs your attention:\n\n" + issues.joined(separator: "\n")
            return summary
        }
    }

    // MARK: - Approved Conflicts Management

    /// Mark a conflict as approved (user chose to keep both events)
    func approveConflict(_ conflict: ScheduleConflict) {
        let conflictKey = createConflictKey(conflict)
        approvedConflicts.insert(conflictKey)
        // Remove from detected conflicts
        detectedConflicts.removeAll { $0.id == conflict.id }
        print("✅ Conflict approved and removed: \(conflictKey)")
    }

    /// Check if a conflict has been approved
    private func isConflictApproved(_ conflict: ScheduleConflict) -> Bool {
        let conflictKey = createConflictKey(conflict)
        return approvedConflicts.contains(conflictKey)
    }

    /// Create a unique key for a conflict based on event IDs
    private func createConflictKey(_ conflict: ScheduleConflict) -> String {
        let eventIds = conflict.conflictingEvents.map { $0.id }.sorted()
        return eventIds.joined(separator: "|")
    }

    // MARK: - Enhanced Conflict Detection

    /// Detect all conflicts across all events in the current view
    func detectAllConflicts() {
        print("🔍 ========== DETECTING CONFLICTS ==========")
        print("🔍 Scanning \(unifiedEvents.count) events for conflicts...")

        var conflicts: [ScheduleConflict] = []
        var processedPairs = Set<String>()

        // Get start of today to filter out past events
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // Filter to only include events from today onwards (exclude past events)
        let currentAndFutureEvents = unifiedEvents.filter { event in
            // Include event if it ends today or in the future
            event.endDate >= startOfToday
        }

        print("🔍 Filtered to \(currentAndFutureEvents.count) current/future events (excluded \(unifiedEvents.count - currentAndFutureEvents.count) past events)")

        // Sort events by start date for efficient checking
        let sortedEvents = currentAndFutureEvents.sorted { $0.startDate < $1.startDate }

        for i in 0..<sortedEvents.count {
            let event1 = sortedEvents[i]

            // Skip all-day events for conflict detection
            if event1.isAllDay {
                continue
            }

            // Check against subsequent events
            for j in (i + 1)..<sortedEvents.count {
                let event2 = sortedEvents[j]

                // Skip all-day events
                if event2.isAllDay {
                    continue
                }

                // If event2 starts after event1 ends, no need to check further
                if event2.startDate >= event1.endDate {
                    break
                }

                // Check for overlap
                if eventsOverlap(event1, event2) {
                    // Create a unique pair ID to avoid duplicate conflicts
                    let pairId = createPairId(event1.id, event2.id)

                    if !processedPairs.contains(pairId) {
                        processedPairs.insert(pairId)

                        // Calculate overlap period
                        let overlapStart = max(event1.startDate, event2.startDate)
                        let overlapEnd = min(event1.endDate, event2.endDate)

                        // Create conflict
                        let conflict = ScheduleConflict(
                            events: [event1, event2],
                            overlapStart: overlapStart,
                            overlapEnd: overlapEnd
                        )

                        // Skip if conflict has been approved
                        if !isConflictApproved(conflict) {
                            conflicts.append(conflict)
                            print("⚠️ Conflict detected: \(event1.title) ↔ \(event2.title) (\(conflict.severity.rawValue))")
                        } else {
                            print("✓ Skipping approved conflict: \(event1.title) ↔ \(event2.title)")
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.detectedConflicts = conflicts
            print("🔍 ========== CONFLICT DETECTION COMPLETE ==========")
            if !conflicts.isEmpty {
                print("🚨 Total conflicts found: \(conflicts.count)")
                for conflict in conflicts {
                    let eventTitles = conflict.conflictingEvents.map { $0.title }.joined(separator: " ↔ ")
                    print("   - \(eventTitles)")
                }
                self.showConflictAlert = true
            } else {
                print("✅ No conflicts detected")
            }
        }
    }

    /// Check if two events overlap
    private func eventsOverlap(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        return event1.startDate < event2.endDate && event1.endDate > event2.startDate
    }

    /// Create a unique pair ID for two events
    private func createPairId(_ id1: String, _ id2: String) -> String {
        let sorted = [id1, id2].sorted()
        return "\(sorted[0])|\(sorted[1])"
    }

    /// Get conflicts for a specific date
    func getConflictsForDate(_ date: Date) -> [ScheduleConflict] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return detectedConflicts.filter { (conflict: ScheduleConflict) -> Bool in
            conflict.overlapStart < endOfDay && conflict.overlapEnd > startOfDay
        }
    }

    /// Clear all detected conflicts
    func clearConflicts() {
        detectedConflicts = []
        showConflictAlert = false
    }

    /// Create event with conflict override
    func createEventOverridingConflict() {
        guard let details = pendingEventDetails else { return }

        createEvent(
            title: details.title,
            startDate: details.startDate,
            endDate: details.endDate,
            location: details.location,
            notes: details.notes,
            participants: details.participants,
            calendarSource: details.calendarSource,
            skipConflictCheck: true
        )

        // Clear pending state
        pendingConflictResult = nil
        pendingEventDetails = nil
    }

    /// Create event at alternative time
    func createEventAtAlternativeTime(_ newStartDate: Date) {
        guard let details = pendingEventDetails else { return }

        let duration = details.endDate.timeIntervalSince(details.startDate)
        let newEndDate = newStartDate.addingTimeInterval(duration)

        createEvent(
            title: details.title,
            startDate: newStartDate,
            endDate: newEndDate,
            location: details.location,
            notes: details.notes,
            participants: details.participants,
            calendarSource: details.calendarSource,
            skipConflictCheck: false,
            onConflict: { [weak self] conflictResult in
                // If alternative also has conflict, show it again
                self?.pendingConflictResult = conflictResult
                self?.pendingEventDetails = (
                    title: details.title,
                    startDate: newStartDate,
                    endDate: newEndDate,
                    location: details.location,
                    notes: details.notes,
                    participants: details.participants,
                    calendarSource: details.calendarSource
                )
            }
        )

        // If no conflict, clear pending state
        if pendingConflictResult == nil {
            pendingEventDetails = nil
        }
    }

    /// Cancel pending event creation
    func cancelPendingEvent() {
        pendingConflictResult = nil
        pendingEventDetails = nil
    }

    // MARK: - Smart Notifications

    /// Schedule smart notifications for upcoming events
    private func scheduleSmartNotificationsForEvents(_ events: [UnifiedEvent]) {
        let notificationManager = SmartNotificationManager.shared

        // Filter to only upcoming events in the next 7 days
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        let upcomingEvents = events.filter { event in
            event.startDate > now && event.startDate <= nextWeek
        }

        print("🔔 Scheduling smart notifications for \(upcomingEvents.count) upcoming events")

        for event in upcomingEvents {
            notificationManager.scheduleSmartNotifications(for: event)
        }
    }

    // MARK: - Video Meeting URL Extraction

    /// Ensure EKEvent has video meeting URL set by extracting from location/notes if needed
    private func ensureVideoURLIsSet(for event: EKEvent) {
        // If URL is already set, nothing to do
        if event.url != nil {
            return
        }

        // Try to extract from location first
        if let location = event.location, !location.isEmpty {
            if let videoURL = extractVideoMeetingURL(from: location) {
                event.url = videoURL
                print("🔗 [MIGRATION] Set video URL from location for event: \(event.title ?? "Untitled")")
                // Save the updated event
                do {
                    try eventStore.save(event, span: .thisEvent, commit: true)
                } catch {
                    print("⚠️ Failed to save updated event URL: \(error)")
                }
                return
            }
        }

        // Try to extract from notes if not found in location
        if let notes = event.notes, !notes.isEmpty {
            if let videoURL = extractVideoMeetingURL(from: notes) {
                event.url = videoURL
                print("🔗 [MIGRATION] Set video URL from notes for event: \(event.title ?? "Untitled")")
                // Save the updated event
                do {
                    try eventStore.save(event, span: .thisEvent, commit: true)
                } catch {
                    print("⚠️ Failed to save updated event URL: \(error)")
                }
                return
            }
        }
    }

    /// Extract video meeting URL from text (location or notes)
    private func extractVideoMeetingURL(from text: String) -> URL? {
        // Define patterns for common video meeting platforms
        let patterns = [
            // Zoom
            "https?://[\\w.-]*zoom\\.us/j/[0-9?=&\\w-]+",
            "https?://[\\w.-]*zoom\\.us/wc/join/[0-9?=&\\w-]+",
            // Google Meet
            "https?://meet\\.google\\.com/[a-z0-9-]+",
            // Microsoft Teams
            "https?://teams\\.microsoft\\.com/l/meetup-join/[\\w/%?=&\\-._~:@!$'()*+,;]+",
            // Webex
            "https?://[\\w.-]+\\.webex\\.com/[\\w./\\-?=&]+"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    return URL(string: urlString)
                }
            }
        }

        return nil
    }

    deinit {
        stopPeriodicSync()
        syncDebounceWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        print("🧹 CalendarManager deinitialized - observers and timers removed")
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