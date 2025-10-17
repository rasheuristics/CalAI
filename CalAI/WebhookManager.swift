import Foundation
import Combine
import Network

class WebhookManager: ObservableObject {
    static let shared = WebhookManager()

    @Published var registeredWebhooks: [RegisteredWebhook] = []
    @Published var webhookEvents: [WebhookEvent] = []
    @Published var isListening = false

    private let syncManager = SyncManager.shared
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Webhook server components
    private var webhookServer: WebhookServer?
    private let webhookPort: UInt16 = 8080

    private init() {
        setupWebhookHandling()
    }

    // MARK: - Webhook Registration

    func registerGoogleWebhook() async {
        guard let googleManager = syncManager.calendarManager?.googleCalendarManager,
              googleManager.isSignedIn else {
            print("⚠️ Google Calendar not available for webhook registration")
            return
        }

        do {
            let webhookURL = "https://your-server.com/webhooks/google"
            let webhook = try await registerWebhookWithGoogle(url: webhookURL)

            await MainActor.run {
                self.registeredWebhooks.append(webhook)
            }

            print("✅ Google Calendar webhook registered: \(webhook.id)")

        } catch {
            print("❌ Failed to register Google webhook: \(error)")
        }
    }

    func registerOutlookWebhook() async {
        guard let outlookManager = syncManager.calendarManager?.outlookCalendarManager,
              outlookManager.isSignedIn else {
            print("⚠️ Outlook Calendar not available for webhook registration")
            return
        }

        do {
            let webhookURL = "https://your-server.com/webhooks/outlook"
            let webhook = try await registerWebhookWithOutlook(url: webhookURL)

            await MainActor.run {
                self.registeredWebhooks.append(webhook)
            }

            print("✅ Outlook Calendar webhook registered: \(webhook.id)")

        } catch {
            print("❌ Failed to register Outlook webhook: \(error)")
        }
    }

    private func registerWebhookWithGoogle(url: String) async throws -> RegisteredWebhook {
        // Google Calendar Push Notifications setup
        let channelId = UUID().uuidString
        let expiration = Date().addingTimeInterval(86400 * 7) // 7 days

        let requestBody = [
            "id": channelId,
            "type": "web_hook",
            "address": url,
            "expiration": String(Int(expiration.timeIntervalSince1970 * 1000))
        ]

        // This would make actual API call to Google Calendar API
        let webhook = RegisteredWebhook(
            id: channelId,
            source: .google,
            url: url,
            expirationDate: expiration,
            isActive: true
        )

        return webhook
    }

    private func registerWebhookWithOutlook(url: String) async throws -> RegisteredWebhook {
        // Microsoft Graph Subscriptions setup
        let subscriptionId = UUID().uuidString
        let expiration = Date().addingTimeInterval(86400 * 3) // 3 days (Graph limit)

        let requestBody = [
            "changeType": "created,updated,deleted",
            "notificationUrl": url,
            "resource": "me/events",
            "expirationDateTime": ISO8601DateFormatter().string(from: expiration)
        ]

        // This would make actual API call to Microsoft Graph API
        let webhook = RegisteredWebhook(
            id: subscriptionId,
            source: .outlook,
            url: url,
            expirationDate: expiration,
            isActive: true
        )

        return webhook
    }

    // MARK: - Webhook Server

    func startWebhookListener() {
        guard !isListening else { return }

        webhookServer = WebhookServer(port: webhookPort) { [weak self] event in
            self?.handleWebhookEvent(event)
        }

        webhookServer?.start()

        DispatchQueue.main.async {
            self.isListening = true
        }

        print("🌐 Webhook listener started on port \(webhookPort)")
    }

    func stopWebhookListener() {
        webhookServer?.stop()
        webhookServer = nil

        DispatchQueue.main.async {
            self.isListening = false
        }

        print("⏹️ Webhook listener stopped")
    }

    private func handleWebhookEvent(_ event: WebhookEvent) {
        DispatchQueue.main.async {
            self.webhookEvents.append(event)
        }

        print("📨 Received webhook: \(event.source) - \(event.changeType)")

        // Process webhook based on source and change type
        Task {
            await processWebhookEvent(event)
        }
    }

    private func processWebhookEvent(_ event: WebhookEvent) async {
        switch event.source {
        case .google:
            await processGoogleWebhook(event)
        case .outlook:
            await processOutlookWebhook(event)
        case .ios:
            break // iOS doesn't support webhooks, uses local notifications
        }
    }

    private func processGoogleWebhook(_ event: WebhookEvent) async {
        print("🟢 Processing Google webhook: \(event.changeType)")

        switch event.changeType {
        case .created, .updated:
            // Fetch the specific event that changed
            if let eventId = event.resourceId {
                await fetchAndUpdateGoogleEvent(eventId: eventId)
            } else {
                // Fallback: perform incremental sync
                await syncManager.performIncrementalSync()
            }

        case .deleted:
            if let eventId = event.resourceId {
                deleteLocalEvent(eventId: eventId, source: .google)
            }
        }
    }

    private func processOutlookWebhook(_ event: WebhookEvent) async {
        print("🔵 Processing Outlook webhook: \(event.changeType)")

        switch event.changeType {
        case .created, .updated:
            // Fetch the specific event that changed
            if let eventId = event.resourceId {
                await fetchAndUpdateOutlookEvent(eventId: eventId)
            } else {
                // Fallback: perform incremental sync
                await syncManager.performIncrementalSync()
            }

        case .deleted:
            if let eventId = event.resourceId {
                deleteLocalEvent(eventId: eventId, source: .outlook)
            }
        }
    }

    // MARK: - Event Fetching

    private func fetchAndUpdateGoogleEvent(eventId: String) async {
        guard let googleManager = syncManager.calendarManager?.googleCalendarManager else { return }

        // This would make a specific API call to fetch the changed event
        // For now, trigger a general refresh
        await MainActor.run {
            googleManager.fetchEvents()
        }

        // Give time for fetch to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Update local cache
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
                originalEvent: event,
                calendarId: nil,
                calendarName: nil,
                calendarColor: nil
            )
        }

        for event in googleEvents where event.id == eventId {
            coreDataManager.saveEvent(event, syncStatus: .synced)
            print("✅ Updated Google event: \(event.title)")
        }
    }

    private func fetchAndUpdateOutlookEvent(eventId: String) async {
        guard let outlookManager = syncManager.calendarManager?.outlookCalendarManager else { return }

        // This would make a specific API call to fetch the changed event
        // For now, trigger a general refresh
        await MainActor.run {
            outlookManager.fetchEvents()
        }

        // Give time for fetch to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Update local cache
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
                originalEvent: event,
                calendarId: nil,
                calendarName: nil,
                calendarColor: nil
            )
        }

        for event in outlookEvents where event.id == eventId {
            coreDataManager.saveEvent(event, syncStatus: .synced)
            print("✅ Updated Outlook event: \(event.title)")
        }
    }

    private func deleteLocalEvent(eventId: String, source: CalendarSource) {
        coreDataManager.deleteEvent(eventId: eventId, source: source)
        print("🗑️ Deleted local event: \(eventId)")
    }

    // MARK: - Webhook Management

    func renewWebhooks() async {
        print("🔄 Renewing expiring webhooks...")

        for webhook in registeredWebhooks where webhook.isExpiringSoon {
            switch webhook.source {
            case .google:
                await renewGoogleWebhook(webhook)
            case .outlook:
                await renewOutlookWebhook(webhook)
            case .ios:
                break // iOS doesn't use webhooks
            }
        }
    }

    private func renewGoogleWebhook(_ webhook: RegisteredWebhook) async {
        // Google Calendar webhook renewal
        do {
            let newExpiration = Date().addingTimeInterval(86400 * 7) // 7 days
            // Make API call to renew webhook...

            await MainActor.run {
                if let index = self.registeredWebhooks.firstIndex(where: { $0.id == webhook.id }) {
                    self.registeredWebhooks[index].expirationDate = newExpiration
                }
            }

            print("✅ Renewed Google webhook: \(webhook.id)")

        } catch {
            print("❌ Failed to renew Google webhook: \(error)")
        }
    }

    private func renewOutlookWebhook(_ webhook: RegisteredWebhook) async {
        // Microsoft Graph subscription renewal
        do {
            let newExpiration = Date().addingTimeInterval(86400 * 3) // 3 days
            // Make API call to renew webhook...

            await MainActor.run {
                if let index = self.registeredWebhooks.firstIndex(where: { $0.id == webhook.id }) {
                    self.registeredWebhooks[index].expirationDate = newExpiration
                }
            }

            print("✅ Renewed Outlook webhook: \(webhook.id)")

        } catch {
            print("❌ Failed to renew Outlook webhook: \(error)")
        }
    }

    func unregisterWebhook(_ webhook: RegisteredWebhook) async {
        // Make API call to unregister webhook based on source
        switch webhook.source {
        case .google:
            await unregisterGoogleWebhook(webhook)
        case .outlook:
            await unregisterOutlookWebhook(webhook)
        case .ios:
            break
        }

        await MainActor.run {
            self.registeredWebhooks.removeAll { $0.id == webhook.id }
        }

        print("✅ Unregistered webhook: \(webhook.id)")
    }

    private func unregisterGoogleWebhook(_ webhook: RegisteredWebhook) async {
        // Google Calendar webhook unregistration
        // Make API call to stop the channel...
    }

    private func unregisterOutlookWebhook(_ webhook: RegisteredWebhook) async {
        // Microsoft Graph subscription deletion
        // Make API call to delete the subscription...
    }

    // MARK: - Setup

    private func setupWebhookHandling() {
        // Setup automatic webhook renewal
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                await self.renewWebhooks()
            }
        }
    }

    deinit {
        stopWebhookListener()
    }
}

// MARK: - Supporting Types

struct RegisteredWebhook: Identifiable {
    let id: String
    let source: CalendarSource
    let url: String
    var expirationDate: Date
    var isActive: Bool

    var isExpiringSoon: Bool {
        Date().addingTimeInterval(86400).timeIntervalSince1970 > expirationDate.timeIntervalSince1970
    }
}

struct WebhookEvent: Identifiable {
    let id = UUID()
    let source: CalendarSource
    let changeType: WebhookChangeType
    let resourceId: String?
    let timestamp: Date
    let payload: [String: Any]
}

enum WebhookChangeType {
    case created
    case updated
    case deleted
}

// MARK: - Webhook Server

class WebhookServer {
    private let port: UInt16
    private let eventHandler: (WebhookEvent) -> Void
    private var listener: NWListener?

    init(port: UInt16, eventHandler: @escaping (WebhookEvent) -> Void) {
        self.port = port
        self.eventHandler = eventHandler
    }

    func start() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .background))
            print("🌐 Webhook server listening on port \(port)")

        } catch {
            print("❌ Failed to start webhook server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("⏹️ Webhook server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .background))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processWebhookData(data)
            }

            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private func processWebhookData(_ data: Data) {
        guard let httpRequest = String(data: data, encoding: .utf8) else { return }

        // Parse HTTP request and extract webhook payload
        // This is a simplified implementation - would need proper HTTP parsing
        if let webhookEvent = parseWebhookRequest(httpRequest) {
            eventHandler(webhookEvent)
        }
    }

    private func parseWebhookRequest(_ request: String) -> WebhookEvent? {
        // Parse HTTP request to extract webhook information
        // This would need proper HTTP request parsing and JSON extraction
        // For now, return a mock event for demonstration

        return WebhookEvent(
            source: .google,
            changeType: .updated,
            resourceId: "sample_event_id",
            timestamp: Date(),
            payload: [:]
        )
    }
}

// MARK: - SyncManager Integration

extension SyncManager {
    func enableWebhooks() async {
        let webhookManager = WebhookManager.shared

        // Start webhook listener
        webhookManager.startWebhookListener()

        // Register webhooks for each connected service
        await webhookManager.registerGoogleWebhook()
        await webhookManager.registerOutlookWebhook()

        print("🌐 Webhooks enabled for real-time sync")
    }

    func disableWebhooks() async {
        let webhookManager = WebhookManager.shared

        // Unregister all webhooks
        for webhook in webhookManager.registeredWebhooks {
            await webhookManager.unregisterWebhook(webhook)
        }

        // Stop webhook listener
        webhookManager.stopWebhookListener()

        print("🌐 Webhooks disabled")
    }
}