import Foundation
import CryptoKit

// MARK: - API Cache Service

/// Service for caching API responses to reduce redundant calls
@MainActor
class APICacheService: ObservableObject {
    static let shared = APICacheService()

    // MARK: - Cache Entry

    struct CacheEntry: Codable {
        let response: String
        let timestamp: Date
        let ttl: TimeInterval
        let promptHash: String

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var remainingTTL: TimeInterval {
            max(0, ttl - Date().timeIntervalSince(timestamp))
        }
    }

    // MARK: - Configuration

    struct CacheConfig {
        static let maxEntries = 50
        static let defaultTTL: TimeInterval = 3600 // 1 hour
        static let sommelierTTL: TimeInterval = 86400 // 24 hours
        static let regenerationTTL: TimeInterval = 1800 // 30 minutes
        static let menuTTL: TimeInterval = 3600 // 1 hour
    }

    // MARK: - Properties

    private var cache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "it.mikesoft.convivio.cache")

    @Published private(set) var cacheStats: CacheStats = CacheStats()

    struct CacheStats {
        var hits: Int = 0
        var misses: Int = 0
        var entries: Int = 0

        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0
        }
    }

    // MARK: - Initialization

    private init() {
        loadFromDisk()
        scheduleCleanup()
    }

    // MARK: - Public API

    /// Get cached response if available and not expired
    func getCached(for prompt: String, identifier: PromptIdentifier) -> String? {
        let key = cacheKey(for: prompt, identifier: identifier)

        guard let entry = cache[key], !entry.isExpired else {
            cacheStats.misses += 1
            return nil
        }

        cacheStats.hits += 1
        return entry.response
    }

    /// Store response in cache
    func cache(response: String, for prompt: String, identifier: PromptIdentifier) {
        let key = cacheKey(for: prompt, identifier: identifier)
        let ttl = getTTL(for: identifier)

        let entry = CacheEntry(
            response: response,
            timestamp: Date(),
            ttl: ttl,
            promptHash: key
        )

        cache[key] = entry
        cacheStats.entries = cache.count

        // Evict if over limit
        evictIfNeeded()

        // Save to disk periodically
        saveToDisk()
    }

    /// Check if a cached response exists (without retrieving)
    func hasCached(for prompt: String, identifier: PromptIdentifier) -> Bool {
        let key = cacheKey(for: prompt, identifier: identifier)
        guard let entry = cache[key] else { return false }
        return !entry.isExpired
    }

    /// Invalidate cache for a specific prompt
    func invalidate(for prompt: String, identifier: PromptIdentifier) {
        let key = cacheKey(for: prompt, identifier: identifier)
        cache.removeValue(forKey: key)
        cacheStats.entries = cache.count
        saveToDisk()
    }

    /// Clear all cache entries
    func clearAll() {
        cache.removeAll()
        cacheStats = CacheStats()
        saveToDisk()
    }

    /// Remove expired entries
    func removeExpired() {
        let beforeCount = cache.count
        cache = cache.filter { !$0.value.isExpired }
        let removedCount = beforeCount - cache.count
        cacheStats.entries = cache.count

        if removedCount > 0 {
            print("🗑️ APICacheService: Removed \(removedCount) expired entries")
            saveToDisk()
        }
    }

    // MARK: - Cache Key Generation

    private func cacheKey(for prompt: String, identifier: PromptIdentifier) -> String {
        // Create a hash of the prompt and identifier for the cache key
        let combined = "\(identifier.rawValue):\(prompt)"
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - TTL Configuration

    private func getTTL(for identifier: PromptIdentifier) -> TimeInterval {
        switch identifier {
        case .sommelierChat:
            return CacheConfig.sommelierTTL
        case .dishRegeneration, .wineRegeneration:
            return CacheConfig.regenerationTTL
        case .menuGeneration, .detailedMenu:
            return CacheConfig.menuTTL
        case .inviteGeneration:
            return CacheConfig.defaultTTL
        }
    }

    // MARK: - LRU Eviction

    private func evictIfNeeded() {
        guard cache.count > CacheConfig.maxEntries else { return }

        // Sort by timestamp (oldest first) and remove until under limit
        let sortedKeys = cache.keys.sorted { key1, key2 in
            let entry1 = cache[key1]!
            let entry2 = cache[key2]!
            return entry1.timestamp < entry2.timestamp
        }

        let toRemove = cache.count - CacheConfig.maxEntries
        for key in sortedKeys.prefix(toRemove) {
            cache.removeValue(forKey: key)
        }

        cacheStats.entries = cache.count
        print("🗑️ APICacheService: Evicted \(toRemove) entries (LRU)")
    }

    // MARK: - Persistence

    private var cacheFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("api_cache.json")
    }

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            print("⚠️ APICacheService: Failed to save cache: \(error)")
        }
    }

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cache = try decoder.decode([String: CacheEntry].self, from: data)

            // Remove expired entries on load
            cache = cache.filter { !$0.value.isExpired }
            cacheStats.entries = cache.count

            print("✅ APICacheService: Loaded \(cache.count) cached entries")
        } catch {
            // File doesn't exist or is corrupted, start fresh
            cache = [:]
        }
    }

    // MARK: - Cleanup Scheduling

    private func scheduleCleanup() {
        // Clean up expired entries every hour
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 3600_000_000_000) // 1 hour
                removeExpired()
            }
        }
    }
}

// MARK: - OpenAI Service Extension

extension OpenAIService {
    /// Generate menu with optional caching
    func generateMenuWithCaching(
        prompt: String,
        model: OpenAIModel = .gpt4o,
        identifier: PromptIdentifier,
        forceRefresh: Bool = false
    ) async throws -> String {
        let cacheService = await APICacheService.shared

        // Check cache first (unless force refresh)
        if !forceRefresh {
            if let cached = await cacheService.getCached(for: prompt, identifier: identifier) {
                print("✅ Cache hit for \(identifier.displayName)")
                return cached
            }
        }

        // Make API call
        let response = try await generateMenuWithGPT(prompt: prompt, model: model)

        // Cache the response
        await cacheService.cache(response: response, for: prompt, identifier: identifier)

        return response
    }
}
