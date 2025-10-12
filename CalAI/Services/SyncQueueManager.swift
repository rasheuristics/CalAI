import Foundation
import Combine

/// Advanced sync queue with exponential backoff and retry logic
class SyncQueueManager: ObservableObject {
    static let shared = SyncQueueManager()

    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncError] = []

    private var syncQueue: [SyncTask] = []
    private var activeTasks: Set<String> = []
    private let maxConcurrentTasks = 3
    private let maxRetries = 5
    private let queue = DispatchQueue(label: "com.calai.syncqueue", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSyncQueue()
        setupAutoSync()
    }

    // MARK: - Queue Management

    func enqueue(_ task: SyncTask) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Avoid duplicate tasks
            if !self.syncQueue.contains(where: { $0.id == task.id }) {
                self.syncQueue.append(task)
                self.saveSyncQueue()

                DispatchQueue.main.async {
                    print("📥 Enqueued task: \(task.type) - \(task.eventId)")
                }

                // Start processing if not already syncing
                if !self.isSyncing {
                    self.processSyncQueue()
                }
            }
        }
    }

    func processSyncQueue() {
        guard !isSyncing, !syncQueue.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            self?.isSyncing = true
            self?.syncProgress = 0.0
        }

        print("🔄 Processing sync queue with \(syncQueue.count) tasks")

        queue.async { [weak self] in
            self?.processNextBatch()
        }
    }

    private func processNextBatch() {
        let tasksToProcess = queue.sync { [weak self] () -> [SyncTask] in
            guard let self = self else { return [] }

            // Get tasks that aren't currently running
            let available = self.syncQueue.filter { !self.activeTasks.contains($0.id) }

            // Take up to maxConcurrentTasks
            return Array(available.prefix(self.maxConcurrentTasks))
        }

        guard !tasksToProcess.isEmpty else {
            completeSyncIfDone()
            return
        }

        // Process tasks concurrently
        let group = DispatchGroup()

        for task in tasksToProcess {
            group.enter()
            activeTasks.insert(task.id)

            Task {
                await self.processTask(task)
                group.leave()
            }
        }

        group.notify(queue: queue) { [weak self] in
            self?.processNextBatch()
        }
    }

    private func processTask(_ task: SyncTask) async {
        let delay = calculateBackoff(attemptCount: task.attemptCount)

        if delay > 0 {
            print("⏱️ Backing off \(delay)s before retry attempt \(task.attemptCount + 1)")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        do {
            try await executeTask(task)
            taskCompleted(task)
        } catch {
            taskFailed(task, error: error)
        }
    }

    private func executeTask(_ task: SyncTask) async throws {
        print("🔄 Executing task: \(task.type) - \(task.eventId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...2_000_000_000))

        // Simulate occasional failures for retry testing
        if task.attemptCount > 0 && Bool.random() {
            throw SyncTaskError.networkError
        }

        // Execute the actual sync operation
        switch task.type {
        case .createEvent:
            try await syncCreateEvent(task)
        case .updateEvent:
            try await syncUpdateEvent(task)
        case .deleteEvent:
            try await syncDeleteEvent(task)
        case .fullSync:
            try await performFullSync(task)
        }
    }

    private func syncCreateEvent(_ task: SyncTask) async throws {
        print("📅 Creating event: \(task.eventId)")
        // Implementation for creating event
    }

    private func syncUpdateEvent(_ task: SyncTask) async throws {
        print("📝 Updating event: \(task.eventId)")
        // Implementation for updating event
    }

    private func syncDeleteEvent(_ task: SyncTask) async throws {
        print("🗑️ Deleting event: \(task.eventId)")
        // Implementation for deleting event
    }

    private func performFullSync(_ task: SyncTask) async throws {
        print("🔄 Performing full sync")
        // Implementation for full calendar sync
    }

    // MARK: - Task Completion

    private func taskCompleted(_ task: SyncTask) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.syncQueue.removeAll { $0.id == task.id }
            self.activeTasks.remove(task.id)
            self.saveSyncQueue()

            DispatchQueue.main.async {
                print("✅ Task completed: \(task.type) - \(task.eventId)")
                self.updateProgress()
                HapticManager.shared.light()
            }
        }
    }

    private func taskFailed(_ task: SyncTask, error: Error) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.activeTasks.remove(task.id)

            if task.attemptCount < self.maxRetries {
                // Increment attempt count and retry
                if let index = self.syncQueue.firstIndex(where: { $0.id == task.id }) {
                    var updatedTask = task
                    updatedTask.attemptCount += 1
                    updatedTask.lastAttempt = Date()
                    self.syncQueue[index] = updatedTask
                    self.saveSyncQueue()

                    DispatchQueue.main.async {
                        print("⚠️ Task failed (attempt \(task.attemptCount + 1)/\(self.maxRetries)): \(error.localizedDescription)")
                    }
                }
            } else {
                // Max retries exceeded, move to failed
                self.syncQueue.removeAll { $0.id == task.id }

                let syncError = SyncError(
                    taskId: task.id,
                    eventId: task.eventId,
                    type: task.type,
                    error: error,
                    timestamp: Date()
                )

                DispatchQueue.main.async {
                    self.syncErrors.append(syncError)
                    print("❌ Task failed permanently after \(self.maxRetries) attempts: \(error.localizedDescription)")
                    HapticManager.shared.error()
                }

                self.saveSyncQueue()
            }

            DispatchQueue.main.async {
                self.updateProgress()
            }
        }
    }

    private func completeSyncIfDone() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if self.syncQueue.isEmpty && self.activeTasks.isEmpty {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncProgress = 1.0
                    self.lastSyncDate = Date()
                    print("✅ Sync completed successfully")
                    HapticManager.shared.success()

                    // Post notification
                    NotificationCenter.default.post(name: .syncCompleted, object: nil)
                }
            }
        }
    }

    // MARK: - Exponential Backoff

    private func calculateBackoff(attemptCount: Int) -> TimeInterval {
        guard attemptCount > 0 else { return 0 }

        // Exponential backoff: 2^attempt seconds with jitter
        let baseDelay = pow(2.0, Double(attemptCount))
        let maxDelay: TimeInterval = 60.0 // Cap at 60 seconds
        let jitter = Double.random(in: 0...1.0)

        return min(baseDelay + jitter, maxDelay)
    }

    // MARK: - Progress Tracking

    private func updateProgress() {
        let totalTasks = syncQueue.count + syncErrors.count
        let completedTasks = syncErrors.count

        if totalTasks > 0 {
            syncProgress = Double(completedTasks) / Double(totalTasks)
        } else {
            syncProgress = 1.0
        }
    }

    // MARK: - Auto Sync

    private func setupAutoSync() {
        // Auto-sync every 15 minutes
        Timer.publish(every: 15 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.triggerAutoSync()
            }
            .store(in: &cancellables)

        // Sync when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.triggerAutoSync()
            }
            .store(in: &cancellables)

        // Sync when network is restored
        NotificationCenter.default.publisher(for: .networkConnectionRestored)
            .sink { [weak self] _ in
                self?.triggerAutoSync()
            }
            .store(in: &cancellables)
    }

    private func triggerAutoSync() {
        guard OfflineModeManager.shared.canPerformNetworkOperation() else { return }

        print("🔄 Auto-sync triggered")
        processSyncQueue()
    }

    // MARK: - Persistence

    private func loadSyncQueue() {
        if let data = UserDefaults.standard.data(forKey: "syncQueue"),
           let tasks = try? JSONDecoder().decode([SyncTask].self, from: data) {
            syncQueue = tasks
            print("📥 Loaded \(tasks.count) sync tasks")
        }

        if let data = UserDefaults.standard.data(forKey: "syncErrors"),
           let errors = try? JSONDecoder().decode([SyncError].self, from: data) {
            syncErrors = errors
        }

        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveSyncQueue() {
        if let data = try? JSONEncoder().encode(syncQueue) {
            UserDefaults.standard.set(data, forKey: "syncQueue")
        }

        if let data = try? JSONEncoder().encode(syncErrors) {
            UserDefaults.standard.set(data, forKey: "syncErrors")
        }

        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        }
    }

    // MARK: - Manual Controls

    func cancelTask(_ taskId: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.syncQueue.removeAll { $0.id == taskId }
            self?.activeTasks.remove(taskId)
            self?.saveSyncQueue()

            DispatchQueue.main.async {
                print("🚫 Cancelled task: \(taskId)")
            }
        }
    }

    func retryFailedTasks() {
        let failedTasks = syncErrors.map { error in
            SyncTask(
                id: UUID().uuidString,
                type: error.type,
                eventId: error.eventId,
                eventData: Data(),
                priority: .normal,
                createdAt: Date(),
                attemptCount: 0
            )
        }

        syncErrors.removeAll()

        for task in failedTasks {
            enqueue(task)
        }

        HapticManager.shared.light()
    }

    func clearErrorHistory() {
        syncErrors.removeAll()
        saveSyncQueue()
        HapticManager.shared.light()
    }

    // MARK: - Statistics

    var syncStatistics: SyncStatistics {
        return SyncStatistics(
            queuedTasks: syncQueue.count,
            activeTasks: activeTasks.count,
            failedTasks: syncErrors.count,
            lastSync: lastSyncDate,
            isSyncing: isSyncing
        )
    }
}

// MARK: - Supporting Types

struct SyncTask: Identifiable, Codable {
    let id: String
    let type: SyncTaskType
    let eventId: String
    let eventData: Data
    let priority: SyncPriority
    let createdAt: Date
    var attemptCount: Int
    var lastAttempt: Date?

    init(
        id: String = UUID().uuidString,
        type: SyncTaskType,
        eventId: String,
        eventData: Data,
        priority: SyncPriority = .normal,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        lastAttempt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.eventId = eventId
        self.eventData = eventData
        self.priority = priority
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastAttempt = lastAttempt
    }
}

enum SyncTaskType: String, Codable {
    case createEvent = "create"
    case updateEvent = "update"
    case deleteEvent = "delete"
    case fullSync = "fullSync"
}

enum SyncPriority: Int, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

struct SyncError: Identifiable, Codable {
    let id: String
    let taskId: String
    let eventId: String
    let type: SyncTaskType
    let errorMessage: String
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        taskId: String,
        eventId: String,
        type: SyncTaskType,
        error: Error,
        timestamp: Date
    ) {
        self.id = id
        self.taskId = taskId
        self.eventId = eventId
        self.type = type
        self.errorMessage = error.localizedDescription
        self.timestamp = timestamp
    }
}

enum SyncTaskError: Error, LocalizedError {
    case networkError
    case authenticationError
    case conflictDetected
    case dataCorrupted

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .authenticationError:
            return "Authentication failed"
        case .conflictDetected:
            return "Conflict detected"
        case .dataCorrupted:
            return "Data corrupted"
        }
    }
}

struct SyncStatistics {
    let queuedTasks: Int
    let activeTasks: Int
    let failedTasks: Int
    let lastSync: Date?
    let isSyncing: Bool

    var statusDescription: String {
        if isSyncing {
            return "Syncing... (\(activeTasks) active)"
        } else if queuedTasks > 0 {
            return "\(queuedTasks) pending"
        } else if let lastSync = lastSync {
            return "Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))"
        } else {
            return "Never synced"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncFailed = Notification.Name("syncFailed")
}

// MARK: - Sync Queue View

import SwiftUI

struct SyncQueueView: View {
    @ObservedObject var syncManager = SyncQueueManager.shared

    var body: some View {
        List {
            // Sync Status
            Section("Status") {
                HStack {
                    if syncManager.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(syncManager.syncStatistics.statusDescription)
                            .font(.subheadline.weight(.medium))

                        if syncManager.isSyncing {
                            ProgressView(value: syncManager.syncProgress)
                                .tint(.blue)
                        }
                    }

                    Spacer()

                    if !syncManager.isSyncing {
                        Button("Sync Now") {
                            syncManager.processSyncQueue()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // Failed Tasks
            if !syncManager.syncErrors.isEmpty {
                Section {
                    ForEach(syncManager.syncErrors) { error in
                        SyncErrorRow(error: error)
                    }
                } header: {
                    HStack {
                        Text("Failed Tasks")
                        Spacer()
                        Button("Retry All") {
                            syncManager.retryFailedTasks()
                        }
                        .font(.caption)
                    }
                } footer: {
                    Button("Clear History") {
                        syncManager.clearErrorHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Sync Queue")
    }
}

struct SyncErrorRow: View {
    let error: SyncError

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)

                Text(error.type.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))
            }

            Text(error.errorMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(error.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SyncQueueView()
            .onAppear {
                SyncQueueManager.shared.isSyncing = true
                SyncQueueManager.shared.syncProgress = 0.6
            }
    }
}
