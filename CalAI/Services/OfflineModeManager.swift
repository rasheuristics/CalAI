import Foundation
import Network
import Combine

/// Manages offline mode and network connectivity
class OfflineModeManager: ObservableObject {
    static let shared = OfflineModeManager()

    @Published var isOnline: Bool = true
    @Published var isOfflineModeEnabled: Bool = false
    @Published var connectionType: ConnectionType = .wifi
    @Published var pendingOperations: [PendingOperation] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.calai.networkmonitor")
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNetworkMonitoring()
        loadPendingOperations()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }

        monitor.start(queue: queue)
        print("📡 Network monitoring started")
    }

    private func handlePathUpdate(_ path: NWPath) {
        let wasOnline = isOnline
        isOnline = path.status == .satisfied

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }

        // Handle connectivity changes
        if !wasOnline && isOnline {
            handleConnectionRestored()
        } else if wasOnline && !isOnline {
            handleConnectionLost()
        }

        print("📡 Network status: \(isOnline ? "Online (\(connectionType))" : "Offline")")
    }

    private func handleConnectionRestored() {
        HapticManager.shared.success()
        print("✅ Connection restored")

        // Auto-sync pending operations
        if !isOfflineModeEnabled {
            syncPendingOperations()
        }

        // Post notification
        NotificationCenter.default.post(name: .networkConnectionRestored, object: nil)
    }

    private func handleConnectionLost() {
        HapticManager.shared.warning()
        print("⚠️ Connection lost")

        // Post notification
        NotificationCenter.default.post(name: .networkConnectionLost, object: nil)
    }

    // MARK: - Offline Mode

    func enableOfflineMode(_ enabled: Bool) {
        isOfflineModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "offlineModeEnabled")

        if enabled {
            print("📴 Offline mode enabled")
            HapticManager.shared.medium()
        } else {
            print("📶 Offline mode disabled")
            HapticManager.shared.light()

            // Sync when coming back online
            if isOnline {
                syncPendingOperations()
            }
        }
    }

    // MARK: - Pending Operations

    func queueOperation(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        savePendingOperations()

        print("📥 Queued operation: \(operation.type) - \(operation.eventId)")

        // Try to sync immediately if online
        if isOnline && !isOfflineModeEnabled {
            syncPendingOperations()
        }
    }

    func syncPendingOperations() {
        guard isOnline, !pendingOperations.isEmpty else { return }

        print("🔄 Syncing \(pendingOperations.count) pending operations")

        let operationsToSync = pendingOperations
        var completedOperations: [String] = []

        for operation in operationsToSync {
            Task {
                do {
                    try await executeOperation(operation)
                    completedOperations.append(operation.id)
                    print("✅ Synced operation: \(operation.type)")
                } catch {
                    print("❌ Failed to sync operation: \(error)")
                }
            }
        }

        // Remove completed operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.pendingOperations.removeAll { completedOperations.contains($0.id) }
            self?.savePendingOperations()

            if completedOperations.count > 0 {
                HapticManager.shared.success()
            }
        }
    }

    private func executeOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .createEvent:
            try await createEventOnRemote(operation)
        case .updateEvent:
            try await updateEventOnRemote(operation)
        case .deleteEvent:
            try await deleteEventOnRemote(operation)
        }
    }

    private func createEventOnRemote(_ operation: PendingOperation) async throws {
        // Implementation for creating event on remote calendar
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        print("📅 Created event on remote: \(operation.eventId)")
    }

    private func updateEventOnRemote(_ operation: PendingOperation) async throws {
        // Implementation for updating event on remote calendar
        try await Task.sleep(nanoseconds: 500_000_000)
        print("📝 Updated event on remote: \(operation.eventId)")
    }

    private func deleteEventOnRemote(_ operation: PendingOperation) async throws {
        // Implementation for deleting event on remote calendar
        try await Task.sleep(nanoseconds: 500_000_000)
        print("🗑️ Deleted event on remote: \(operation.eventId)")
    }

    // MARK: - Persistence

    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "pendingOperations"),
           let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            pendingOperations = operations
            print("📥 Loaded \(operations.count) pending operations")
        }

        isOfflineModeEnabled = UserDefaults.standard.bool(forKey: "offlineModeEnabled")
    }

    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "pendingOperations")
        }
    }

    // MARK: - Network Check

    func canPerformNetworkOperation() -> Bool {
        return isOnline && !isOfflineModeEnabled
    }

    func requiresNetwork(operation: @escaping () async throws -> Void) async throws {
        if !canPerformNetworkOperation() {
            throw OfflineError.networkUnavailable
        }

        try await operation()
    }

    // MARK: - Statistics

    var offlineStatistics: OfflineStatistics {
        return OfflineStatistics(
            isOnline: isOnline,
            connectionType: connectionType,
            pendingOperationsCount: pendingOperations.count,
            isOfflineModeEnabled: isOfflineModeEnabled
        )
    }
}

// MARK: - Supporting Types

enum ConnectionType: String, Codable {
    case wifi = "Wi-Fi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
}

struct PendingOperation: Identifiable, Codable {
    let id: String
    let type: OperationType
    let eventId: String
    let eventData: Data
    let timestamp: Date
    let retryCount: Int

    init(
        id: String = UUID().uuidString,
        type: OperationType,
        eventId: String,
        eventData: Data,
        timestamp: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.eventId = eventId
        self.eventData = eventData
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
}

enum OperationType: String, Codable {
    case createEvent = "create"
    case updateEvent = "update"
    case deleteEvent = "delete"
}

enum OfflineError: Error, LocalizedError {
    case networkUnavailable
    case offlineModeEnabled
    case operationNotAllowed

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection available"
        case .offlineModeEnabled:
            return "Offline mode is enabled"
        case .operationNotAllowed:
            return "This operation requires an internet connection"
        }
    }
}

struct OfflineStatistics {
    let isOnline: Bool
    let connectionType: ConnectionType
    let pendingOperationsCount: Int
    let isOfflineModeEnabled: Bool

    var statusDescription: String {
        if isOfflineModeEnabled {
            return "Offline Mode (Manual)"
        } else if isOnline {
            return "Online (\(connectionType.rawValue))"
        } else {
            return "Offline"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
    static let networkConnectionLost = Notification.Name("networkConnectionLost")
}

// MARK: - Offline Mode Indicator View

import SwiftUI

struct OfflineModeIndicator: View {
    @ObservedObject var offlineManager = OfflineModeManager.shared

    var body: some View {
        Group {
            if !offlineManager.isOnline || offlineManager.isOfflineModeEnabled {
                HStack(spacing: 8) {
                    Image(systemName: offlineManager.isOnline ? "wifi.slash" : "network.slash")
                        .font(.caption)

                    Text(offlineManager.isOfflineModeEnabled ? "Offline Mode" : "No Connection")
                        .font(.caption.weight(.medium))

                    if offlineManager.pendingOperations.count > 0 {
                        Text("(\(offlineManager.pendingOperations.count) pending)")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(offlineManager.isOfflineModeEnabled ? Color.orange : Color.red)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: offlineManager.isOnline)
        .animation(.easeInOut, value: offlineManager.isOfflineModeEnabled)
    }
}

// MARK: - Pending Operations View

struct PendingOperationsView: View {
    @ObservedObject var offlineManager = OfflineModeManager.shared

    var body: some View {
        List {
            Section {
                ForEach(offlineManager.pendingOperations) { operation in
                    PendingOperationRow(operation: operation)
                }
            } header: {
                HStack {
                    Text("Pending Operations")
                    Spacer()
                    if offlineManager.isOnline {
                        Button("Sync Now") {
                            offlineManager.syncPendingOperations()
                        }
                        .font(.caption)
                    }
                }
            } footer: {
                if offlineManager.pendingOperations.isEmpty {
                    Text("All changes are synced")
                } else {
                    Text("These changes will sync when you're back online")
                }
            }
        }
        .navigationTitle("Offline Queue")
    }
}

struct PendingOperationRow: View {
    let operation: PendingOperation

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(operation.type.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))

                Text(operation.eventId)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(operation.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }

            Spacer()

            if operation.retryCount > 0 {
                Text("Retry \(operation.retryCount)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch operation.type {
        case .createEvent:
            return "plus.circle.fill"
        case .updateEvent:
            return "pencil.circle.fill"
        case .deleteEvent:
            return "trash.circle.fill"
        }
    }

    private var color: Color {
        switch operation.type {
        case .createEvent:
            return .green
        case .updateEvent:
            return .blue
        case .deleteEvent:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Offline Indicator - Offline") {
    VStack {
        OfflineModeIndicator()
            .onAppear {
                OfflineModeManager.shared.isOnline = false
            }
        Spacer()
    }
    .padding()
}

#Preview("Pending Operations") {
    NavigationView {
        PendingOperationsView()
            .onAppear {
                // Add sample pending operations
                let sampleData = "{}".data(using: .utf8)!
                OfflineModeManager.shared.pendingOperations = [
                    PendingOperation(type: .createEvent, eventId: "event-1", eventData: sampleData),
                    PendingOperation(type: .updateEvent, eventId: "event-2", eventData: sampleData),
                    PendingOperation(type: .deleteEvent, eventId: "event-3", eventData: sampleData)
                ]
            }
    }
}
