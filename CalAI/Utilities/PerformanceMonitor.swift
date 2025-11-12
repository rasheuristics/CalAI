import Foundation
import SwiftUI
import os.log

/// Performance monitoring utility to track app responsiveness and identify bottlenecks
class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "com.rasheuristics.calai", category: "Performance")
    private var metrics: [String: PerformanceMetric] = [:]

    struct PerformanceMetric {
        let name: String
        var startTime: CFAbsoluteTime
        var endTime: CFAbsoluteTime?
        var duration: TimeInterval? {
            guard let end = endTime else { return nil }
            return end - startTime
        }
        var isWarning: Bool {
            guard let duration = duration else { return false }
            return duration > 0.1 // More than 100ms is concerning
        }
        var isCritical: Bool {
            guard let duration = duration else { return false }
            return duration > 0.5 // More than 500ms is critical
        }
    }

    private init() {}

    // MARK: - Public API

    /// Start measuring a performance metric
    func startMeasuring(_ name: String) {
        let metric = PerformanceMetric(name: name, startTime: CFAbsoluteTimeGetCurrent(), endTime: nil)
        metrics[name] = metric
        logger.info("🔵 Started: \(name)")
    }

    /// Stop measuring and log results
    func stopMeasuring(_ name: String) {
        guard var metric = metrics[name] else {
            logger.warning("⚠️ No metric found for: \(name)")
            return
        }

        metric.endTime = CFAbsoluteTimeGetCurrent()

        if let duration = metric.duration {
            let durationMs = duration * 1000

            if metric.isCritical {
                logger.error("🔴 CRITICAL: \(name) took \(String(format: "%.2f", durationMs))ms")
            } else if metric.isWarning {
                logger.warning("🟡 WARNING: \(name) took \(String(format: "%.2f", durationMs))ms")
            } else {
                logger.info("✅ \(name) took \(String(format: "%.2f", durationMs))ms")
            }
        }

        metrics[name] = metric
    }

    /// Measure a block of code
    func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        startMeasuring(name)
        defer { stopMeasuring(name) }
        return try block()
    }

    /// Measure an async block of code
    func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        startMeasuring(name)
        defer { stopMeasuring(name) }
        return try await block()
    }

    /// Get all recorded metrics
    func getAllMetrics() -> [PerformanceMetric] {
        return Array(metrics.values).sorted { $0.startTime > $1.startTime }
    }

    /// Get summary of slow operations
    func getSlowOperations() -> [PerformanceMetric] {
        return metrics.values.filter { $0.isWarning || $0.isCritical }
            .sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
    }

    /// Clear all metrics
    func clearMetrics() {
        metrics.removeAll()
        logger.info("🧹 Cleared all performance metrics")
    }

    /// Print summary report
    func printSummary() {
        logger.info("📊 Performance Summary")
        logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let completed = metrics.values.filter { $0.duration != nil }
        let slow = getSlowOperations()

        logger.info("Total Operations: \(completed.count)")
        logger.info("Slow Operations: \(slow.count)")

        if !slow.isEmpty {
            logger.info("\n⚠️ Slowest Operations:")
            for (index, metric) in slow.prefix(5).enumerated() {
                let durationMs = (metric.duration ?? 0) * 1000
                let emoji = metric.isCritical ? "🔴" : "🟡"
                logger.info("\(index + 1). \(emoji) \(metric.name): \(String(format: "%.2f", durationMs))ms")
            }
        }

        logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Measure view appearance time
    func measureAppearance(_ name: String) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.startMeasuring("\(name) - View Appearance")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                PerformanceMonitor.shared.stopMeasuring("\(name) - View Appearance")
            }
        }
    }
}

// MARK: - Frame Rate Monitor

class FrameRateMonitor: ObservableObject {
    @Published var currentFPS: Double = 60.0
    @Published var droppedFrames: Int = 0
    @Published var isPerformingWell: Bool = true

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private let updateInterval: TimeInterval = 1.0

    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func update(displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= updateInterval {
            DispatchQueue.main.async {
                self.currentFPS = Double(self.frameCount) / elapsed
                self.isPerformingWell = self.currentFPS >= 55.0 // Allow some margin

                if self.currentFPS < 60.0 {
                    self.droppedFrames += Int(60.0 - self.currentFPS)
                }

                // Log if performance is poor (disabled during build/inactive states)
                // Only log if FPS is actually measurable (> 1.0) to avoid build-time noise
                if self.currentFPS > 1.0 {
                    if self.currentFPS < 30.0 {
                        print("🔴 CRITICAL: Low FPS detected: \(String(format: "%.1f", self.currentFPS))")
                    } else if self.currentFPS < 55.0 {
                        print("🟡 WARNING: Dropped frames detected: \(String(format: "%.1f", self.currentFPS)) FPS")
                    }
                }
            }

            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Performance Overlay View

struct PerformanceOverlay: View {
    @StateObject private var frameMonitor = FrameRateMonitor()
    @State private var isExpanded = false

    var body: some View {
        VStack {
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // FPS indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(frameMonitor.isPerformingWell ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text("\(Int(frameMonitor.currentFPS)) FPS")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .onTapGesture {
                        isExpanded.toggle()
                    }

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dropped: \(frameMonitor.droppedFrames)")
                            Button("Clear Metrics") {
                                PerformanceMonitor.shared.clearMetrics()
                                frameMonitor.droppedFrames = 0
                            }
                            .font(.caption)
                            Button("Print Summary") {
                                PerformanceMonitor.shared.printSummary()
                            }
                            .font(.caption)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
            }

            Spacer()
        }
        .allowsHitTesting(true)
        .onAppear {
            frameMonitor.startMonitoring()
        }
        .onDisappear {
            frameMonitor.stopMonitoring()
        }
    }
}

// MARK: - Memory Monitor

class MemoryMonitor {
    static func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return (0, 0)
        }

        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0

        return (usedMB, totalMB)
    }

    static func logMemoryUsage(context: String = "") {
        let (used, total) = getMemoryUsage()
        let percentage = (used / total) * 100.0

        let contextStr = context.isEmpty ? "" : " [\(context)]"

        if percentage > 80.0 {
            print("🔴 HIGH MEMORY\(contextStr): \(String(format: "%.1f", used))MB / \(String(format: "%.1f", total))MB (\(String(format: "%.1f", percentage))%)")
        } else if percentage > 50.0 {
            print("🟡 MEMORY\(contextStr): \(String(format: "%.1f", used))MB (\(String(format: "%.1f", percentage))%)")
        } else {
            print("✅ MEMORY\(contextStr): \(String(format: "%.1f", used))MB (\(String(format: "%.1f", percentage))%)")
        }
    }
}
