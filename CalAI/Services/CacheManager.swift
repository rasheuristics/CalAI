import Foundation

/// Multi-level cache manager for optimizing data access
class CacheManager {
    static let shared = CacheManager()

    // MARK: - Memory Cache

    private var memoryCache = NSCache<NSString, CacheEntry>()
    private let cacheQueue = DispatchQueue(label: "com.calai.cache", attributes: .concurrent)

    // MARK: - Disk Cache

    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100 // Max 100 entries
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Setup disk cache
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("CalAICache")

        createDiskCacheIfNeeded()
        cleanExpiredCache()
    }

    // MARK: - Cache Operations

    /// Store data in cache
    func set<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval = 3600) {
        let entry = CacheEntry(value: value, expiresAt: Date().addingTimeInterval(ttl))

        // Memory cache
        cacheQueue.async(flags: .barrier) {
            let cost = MemoryLayout<T>.size
            self.memoryCache.setObject(entry, forKey: key as NSString, cost: cost)
        }

        // Disk cache (async)
        DispatchQueue.global(qos: .utility).async {
            self.saveToDisk(entry, forKey: key)
        }
    }

    /// Retrieve data from cache
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Try memory cache first
        if let entry = memoryCache.object(forKey: key as NSString) {
            if entry.isValid {
                return entry.value as? T
            } else {
                // Expired, remove it
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // Try disk cache
        if let entry = loadFromDisk(forKey: key, type: CacheEntry.self) {
            if entry.isValid {
                // Restore to memory cache
                memoryCache.setObject(entry, forKey: key as NSString)
                return entry.value as? T
            } else {
                // Expired, remove from disk
                removeDiskCache(forKey: key)
            }
        }

        return nil
    }

    /// Remove specific cache entry
    func remove(forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeObject(forKey: key as NSString)
        }

        DispatchQueue.global(qos: .utility).async {
            self.removeDiskCache(forKey: key)
        }
    }

    /// Clear all cache
    func clearAll() {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeAllObjects()
        }

        DispatchQueue.global(qos: .utility).async {
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            self.createDiskCacheIfNeeded()
        }

        print("🧹 All cache cleared")
    }

    /// Clear expired entries
    func clearExpired() {
        // Clear expired disk cache
        DispatchQueue.global(qos: .utility).async {
            self.cleanExpiredCache()
        }
    }

    // MARK: - Specialized Cache Keys

    /// Generate cache key for events in date range
    static func eventsKey(start: Date, end: Date, source: CalendarSource?) -> String {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        let sourceStr = source?.rawValue ?? "all"
        return "events_\(sourceStr)_\(startStr)_\(endStr)"
    }

    /// Generate cache key for day events
    static func dayEventsKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "day_events_\(formatter.string(from: date))"
    }

    /// Generate cache key for analytics
    static func analyticsKey(period: String) -> String {
        return "analytics_\(period)"
    }

    // MARK: - Disk Cache Implementation

    private func createDiskCacheIfNeeded() {
        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    private func saveToDisk<T: Codable>(_ entry: T, forKey key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key.toBase64())

        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save to disk cache: \(error)")
        }
    }

    private func loadFromDisk<T: Codable>(forKey key: String, type: T.Type) -> T? {
        let fileURL = diskCacheURL.appendingPathComponent(key.toBase64())

        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Failed to load from disk cache: \(error)")
            return nil
        }
    }

    private func removeDiskCache(forKey key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key.toBase64())
        try? fileManager.removeItem(at: fileURL)
    }

    private func cleanExpiredCache() {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in files {
            if let entry = loadFromDisk(forKey: fileURL.lastPathComponent, type: CacheEntry.self) {
                if !entry.isValid {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }

        print("🧹 Expired disk cache cleaned")
    }

    // MARK: - Cache Statistics

    func getCacheStats() -> CacheStats {
        var memoryCacheSize = 0
        var diskCacheSize: Int64 = 0

        // Calculate disk cache size
        if let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for fileURL in files {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    diskCacheSize += Int64(size)
                }
            }
        }

        return CacheStats(
            memoryCacheCount: memoryCache.name.count,
            diskCacheSize: diskCacheSize,
            diskCacheURL: diskCacheURL
        )
    }
}

// MARK: - Supporting Types

class CacheEntry: NSObject, Codable {
    let value: Any
    let expiresAt: Date

    var isValid: Bool {
        return Date() < expiresAt
    }

    init<T: Codable>(value: T, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case value, expiresAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)

        // Decode value as Data
        let valueData = try container.decode(Data.self, forKey: .value)
        self.value = try JSONDecoder().decode([UnifiedEvent].self, from: valueData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expiresAt, forKey: .expiresAt)

        // Encode value as Data
        if let codableValue = value as? Codable {
            let valueData = try JSONEncoder().encode(codableValue)
            try container.encode(valueData, forKey: .value)
        }
    }
}

struct CacheStats {
    let memoryCacheCount: Int
    let diskCacheSize: Int64
    let diskCacheURL: URL

    var formattedDiskSize: String {
        ByteCountFormatter.string(fromByteCount: diskCacheSize, countStyle: .file)
    }
}

// MARK: - String Extension

extension String {
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}

// MARK: - Cache Warming Strategy

extension CacheManager {
    /// Warm up cache with frequently accessed data
    func warmupCommonData(events: [UnifiedEvent]) {
        let today = Calendar.current.startOfDay(for: Date())

        // Cache today's events
        let todayEvents = events.filter { Calendar.current.isDateInToday($0.startDate) }
        let todayKey = CacheManager.dayEventsKey(date: today)
        set(todayEvents, forKey: todayKey, ttl: 1800) // 30 min TTL

        // Cache this week's events
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        let weekEvents = events.filter { $0.startDate >= weekStart && $0.startDate <= weekEnd }
        let weekKey = CacheManager.eventsKey(start: weekStart, end: weekEnd, source: nil)
        set(weekEvents, forKey: weekKey, ttl: 3600) // 1 hour TTL

        print("🔥 Cache warmed with \(todayEvents.count) today's events and \(weekEvents.count) this week's events")
    }
}
