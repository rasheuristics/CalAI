import Foundation
import UIKit
import BackgroundTasks

/// Optimizes app launch time and background refresh
class AppLaunchOptimizer {
    static let shared = AppLaunchOptimizer()

    private let backgroundTaskIdentifier = "com.calai.refresh"
    private var launchStartTime: CFAbsoluteTime = 0

    private init() {}

    // MARK: - Launch Optimization

    /// Start measuring launch time
    func beginLaunchMeasurement() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
        print("🚀 App launch started")
    }

    /// Complete launch measurement
    func completeLaunchMeasurement() {
        let launchTime = CFAbsoluteTimeGetCurrent() - launchStartTime
        print("✅ App launched in \(String(format: "%.3f", launchTime))s")

        // Log slow launches
        if launchTime > 2.0 {
            print("⚠️ Slow launch detected: \(String(format: "%.3f", launchTime))s")
        }
    }

    /// Initialize critical components on launch
    func initializeCriticalComponents(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        // Initialize Core Data (high priority)
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CoreDataManager.shared
            group.leave()
        }

        // Preload assets (medium priority)
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            AssetPreloader.preloadSFSymbols()
            group.leave()
        }

        // Warm up cache (low priority)
        group.enter()
        DispatchQueue.global(qos: .background).async {
            // Warmup will happen after other critical tasks
            group.leave()
        }

        group.notify(queue: .main) {
            completion()
            print("✅ Critical components initialized")
        }
    }

    /// Defer non-critical initialization
    func initializeNonCriticalComponents() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            // Analytics setup
            self.setupAnalytics()

            // Clear old cache
            CacheManager.shared.clearExpired()

            // Clean old events
            self.cleanOldEvents()

            print("✅ Non-critical components initialized")
        }
    }

    private func setupAnalytics() {
        // Setup analytics SDK here
        print("📊 Analytics initialized")
    }

    private func cleanOldEvents() {
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        CoreDataPerformanceOptimizer.batchDeleteOldEvents(
            olderThan: threeMonthsAgo,
            context: CoreDataManager.shared.backgroundContext
        )
    }

    // MARK: - Background Refresh

    /// Register background refresh tasks
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        print("✅ Background tasks registered")
    }

    /// Schedule next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

        // Schedule for earliest convenient time (15 minutes from now)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Background refresh scheduled")
        } catch {
            print("❌ Failed to schedule background refresh: \(error)")
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundRefresh()

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let refreshOperation = BlockOperation {
            // Sync calendar data
            self.syncCalendarData()
        }

        task.expirationHandler = {
            // Clean up when task expires
            queue.cancelAllOperations()
            print("⏰ Background refresh expired")
        }

        refreshOperation.completionBlock = {
            task.setTaskCompleted(success: !refreshOperation.isCancelled)
        }

        queue.addOperation(refreshOperation)
    }

    private func syncCalendarData() {
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            CalendarManager.shared.loadEvents()
            semaphore.signal()
        }

        semaphore.wait()
        print("✅ Background calendar sync completed")
    }

    // MARK: - Performance Monitoring

    /// Monitor app performance metrics
    func monitorPerformance() -> PerformanceMetrics {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()

        return PerformanceMetrics(
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            cacheStats: CacheManager.shared.getCacheStats()
        )
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func getCPUUsage() -> Double {
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        guard threadsResult == KERN_SUCCESS, let threads = threadsList else {
            return 0
        }

        var totalCPU: Double = 0

        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let result = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(
                        threads[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        $0,
                        &threadInfoCount
                    )
                }
            }

            if result == KERN_SUCCESS {
                if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }

        vm_deallocate(
            mach_task_self_,
            vm_address_t(bitPattern: threads),
            vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride)
        )

        return totalCPU
    }
}

// MARK: - Supporting Types

struct PerformanceMetrics {
    let memoryUsage: UInt64
    let cpuUsage: Double
    let cacheStats: CacheStats

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }

    var formattedCPU: String {
        String(format: "%.1f%%", cpuUsage)
    }

    func printReport() {
        print("""
        📊 Performance Metrics:
        - Memory: \(formattedMemory)
        - CPU: \(formattedCPU)
        - Disk Cache: \(cacheStats.formattedDiskSize)
        """)
    }
}

// MARK: - Startup Sequence

class AppStartupSequence {
    static func execute(completion: @escaping () -> Void) {
        let optimizer = AppLaunchOptimizer.shared

        // Phase 1: Critical (blocking)
        optimizer.beginLaunchMeasurement()

        // Phase 2: High priority (async but quick)
        optimizer.initializeCriticalComponents {
            // Phase 3: UI Ready
            completion()

            // Phase 4: Non-critical (deferred)
            optimizer.initializeNonCriticalComponents()

            // Phase 5: Background setup
            optimizer.registerBackgroundTasks()
            optimizer.scheduleBackgroundRefresh()

            optimizer.completeLaunchMeasurement()
        }
    }
}
