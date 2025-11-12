import Foundation
import Combine
import CloudKit
import Network
import UIKit

class CrossDeviceSyncManager: ObservableObject {
    static let shared = CrossDeviceSyncManager()

    @Published var isCloudKitAvailable = false
    @Published var syncStatus: CrossDeviceSyncStatus = .idle
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var lastCrossDeviceSync: Date?

    private let container: CKContainer
    private let database: CKDatabase
    private let coreDataManager = CoreDataManager.shared
    private var subscriptions = Set<AnyCancellable>()
    private let monitor = NWPathMonitor()

    private init() {
        container = CKContainer(identifier: "iCloud.ai.heucalendar.app")
        database = container.privateCloudDatabase

        setupNetworkMonitoring()
        checkCloudKitAvailability()
        setupCloudKitSubscriptions()
    }

    // MARK: - CloudKit Setup

    private func checkCloudKitAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isCloudKitAvailable = true
                    print("✅ CloudKit available for cross-device sync")
                case .noAccount:
                    print("⚠️ No iCloud account - cross-device sync disabled")
                case .restricted, .temporarilyUnavailable:
                    print("⚠️ CloudKit temporarily unavailable")
                case .couldNotDetermine:
                    print("❌ Could not determine CloudKit status")
                @unknown default:
                    print("❓ Unknown CloudKit status")
                }

                if let error = error {
                    print("❌ CloudKit error: \(error)")
                }
            }
        }
    }

    private func setupCloudKitSubscriptions() {
        guard isCloudKitAvailable else { return }

        // Subscribe to changes in calendar events
        let subscription = CKQuerySubscription(
            recordType: "CalendarEvent",
            predicate: NSPredicate(value: true),
            subscriptionID: "CalendarEventChanges",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        database.save(subscription) { [weak self] subscription, error in
            if let error = error {
                print("❌ Failed to setup CloudKit subscription: \(error)")
            } else {
                print("✅ CloudKit subscription setup successful")
                self?.enableRemoteNotifications()
            }
        }
    }

    private func enableRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Cross-Device Sync

    func syncToCloud(_ events: [UnifiedEvent]) async {
        guard isCloudKitAvailable else {
            print("⚠️ CloudKit not available for sync")
            return
        }

        await MainActor.run {
            syncStatus = .syncing
        }

        print("☁️ Starting cross-device sync to CloudKit")

        do {
            let records = events.map { createCloudKitRecord(from: $0) }

            // Use batch operations for better performance
            try await withThrowingTaskGroup(of: Void.self) { group in
                let batches = records.chunked(into: 100) // CloudKit batch limit

                for batch in batches {
                    group.addTask {
                        try await self.saveBatch(batch)
                    }
                }

                try await group.waitForAll()
            }

            await MainActor.run {
                self.syncStatus = .completed
                self.lastCrossDeviceSync = Date()
            }

            print("✅ Cross-device sync to CloudKit completed")

        } catch {
            print("❌ Cross-device sync failed: \(error)")
            await MainActor.run {
                self.syncStatus = .failed(error)
            }
        }
    }

    func syncFromCloud() async -> [UnifiedEvent] {
        guard isCloudKitAvailable else {
            print("⚠️ CloudKit not available for sync")
            return []
        }

        await MainActor.run {
            syncStatus = .syncing
        }

        print("☁️ Starting cross-device sync from CloudKit")

        do {
            let query = CKQuery(recordType: "CalendarEvent", predicate: NSPredicate(value: true))
            let records = try await fetchAllRecords(query: query)

            let events = records.compactMap { convertFromCloudKitRecord($0) }

            await MainActor.run {
                self.syncStatus = .completed
                self.lastCrossDeviceSync = Date()
            }

            print("✅ Fetched \(events.count) events from CloudKit")
            return events

        } catch {
            print("❌ Failed to sync from CloudKit: \(error)")
            await MainActor.run {
                self.syncStatus = .failed(error)
            }
            return []
        }
    }

    // MARK: - CloudKit Record Operations

    private func createCloudKitRecord(from event: UnifiedEvent) -> CKRecord {
        let record = CKRecord(recordType: "CalendarEvent", recordID: CKRecord.ID(recordName: event.id))

        record["title"] = event.title
        record["startDate"] = event.startDate
        record["endDate"] = event.endDate
        record["location"] = event.location
        record["eventDescription"] = event.description
        record["isAllDay"] = event.isAllDay
        record["source"] = event.source.rawValue
        record["organizer"] = event.organizer
        record["deviceId"] = UIDevice.current.identifierForVendor?.uuidString
        record["lastModified"] = Date()

        return record
    }

    private func convertFromCloudKitRecord(_ record: CKRecord) -> UnifiedEvent? {
        guard let title = record["title"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let sourceString = record["source"] as? String,
              let source = CalendarSource(rawValue: sourceString) else {
            print("⚠️ Invalid CloudKit record format")
            return nil
        }

        return UnifiedEvent(
            id: record.recordID.recordName,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: record["location"] as? String,
            description: record["eventDescription"] as? String,
            isAllDay: record["isAllDay"] as? Bool ?? false,
            source: source,
            organizer: record["organizer"] as? String,
            originalEvent: record,
            calendarId: nil,
            calendarName: nil,
            calendarColor: nil
        )
    }

    private func saveBatch(_ records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .ifServerRecordUnchanged

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func fetchAllRecords(query: CKQuery) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }

            let (records, nextCursor) = try await withCheckedThrowingContinuation { continuation in
                var fetchedRecords: [CKRecord] = []

                operation.recordMatchedBlock = { _, result in
                    switch result {
                    case .success(let record):
                        fetchedRecords.append(record)
                    case .failure(let error):
                        print("⚠️ Failed to fetch record: \(error)")
                    }
                }

                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        continuation.resume(returning: (fetchedRecords, cursor))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                database.add(operation)
            }

            allRecords.append(contentsOf: records)
            cursor = nextCursor

        } while cursor != nil

        return allRecords
    }

    // MARK: - Device Discovery & Sync

    func discoverConnectedDevices() {
        print("🔍 Discovering connected devices...")

        let query = CKQuery(recordType: "DeviceInfo", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)

        var devices: [ConnectedDevice] = []

        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                if let device = self.createConnectedDevice(from: record) {
                    devices.append(device)
                }
            case .failure(let error):
                print("⚠️ Failed to fetch device record: \(error)")
            }
        }

        operation.queryResultBlock = { result in
            DispatchQueue.main.async {
                self.connectedDevices = devices.filter { $0.isOnline }
                print("📱 Found \(self.connectedDevices.count) connected devices")
            }
        }

        database.add(operation)
    }

    private func createConnectedDevice(from record: CKRecord) -> ConnectedDevice? {
        guard let deviceName = record["deviceName"] as? String,
              let deviceId = record["deviceId"] as? String,
              let lastSeen = record["lastSeen"] as? Date else {
            return nil
        }

        return ConnectedDevice(
            id: deviceId,
            name: deviceName,
            lastSeen: lastSeen,
            isOnline: Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
        )
    }

    func registerCurrentDevice() {
        guard isCloudKitAvailable else { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let record = CKRecord(recordType: "DeviceInfo", recordID: CKRecord.ID(recordName: deviceId))

        record["deviceName"] = UIDevice.current.name
        record["deviceId"] = deviceId
        record["lastSeen"] = Date()
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        database.save(record) { _, error in
            if let error = error {
                print("❌ Failed to register device: \(error)")
            } else {
                print("✅ Device registered for cross-device sync")
            }
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("📶 Network available for cross-device sync")
                    self?.registerCurrentDevice()
                } else {
                    print("📶 Network unavailable - cross-device sync paused")
                }
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    // MARK: - Conflict Resolution for Cross-Device

    func resolveCloudKitConflicts(_ serverRecord: CKRecord, clientRecord: CKRecord) -> CKRecord {
        // Implement last-writer-wins with timestamp comparison
        let serverModified = serverRecord["lastModified"] as? Date ?? Date.distantPast
        let clientModified = clientRecord["lastModified"] as? Date ?? Date.distantPast

        if clientModified > serverModified {
            print("🔧 Using client version (newer)")
            return clientRecord
        } else {
            print("🔧 Using server version (newer)")
            return serverRecord
        }
    }

    // MARK: - Push Notifications

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              let queryNotification = notification as? CKQueryNotification else {
            return
        }

        print("📬 Received CloudKit notification: \(queryNotification.notificationType)")

        Task {
            let events = await syncFromCloud()
            if !events.isEmpty {
                // Merge with local data
                for event in events {
                    coreDataManager.saveEvent(event, syncStatus: .synced)
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: .crossDeviceSyncCompleted, object: events)
                }
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Supporting Types

enum CrossDeviceSyncStatus {
    case idle
    case syncing
    case completed
    case failed(Error)
}

struct ConnectedDevice: Identifiable {
    let id: String
    let name: String
    let lastSeen: Date
    let isOnline: Bool
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Notification.Name {
    static let crossDeviceSyncCompleted = Notification.Name("CrossDeviceSyncCompleted")
}

// MARK: - CloudKit Integration with SyncManager (Disabled for now)

// TODO: Re-enable cross-device sync in a future update
/*
extension SyncManager {
    func enableCrossDeviceSync() {
        let crossDeviceManager = CrossDeviceSyncManager.shared

        // Register for remote notifications
        NotificationCenter.default.addObserver(
            forName: .crossDeviceSyncCompleted,
            object: nil,
            queue: .main
        ) { notification in
            if let events = notification.object as? [UnifiedEvent] {
                print("🔄 Received \(events.count) events from cross-device sync")
                Task {
                    await self.performIncrementalSync()
                }
            }
        }

        // Register current device
        crossDeviceManager.registerCurrentDevice()

        print("🌐 Cross-device sync enabled")
    }

    func syncToConnectedDevices() async {
        let crossDeviceManager = CrossDeviceSyncManager.shared

        // Get all local events
        let allEvents = self.coreDataManager.fetchEvents()

        // Sync to CloudKit
        await crossDeviceManager.syncToCloud(allEvents)

        print("☁️ Synced \(allEvents.count) events to connected devices")
    }
}
*/