import Foundation
import os.log

// MARK: - Performance Monitor

/// Service for monitoring app performance metrics
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "it.mikesoft.convivio", category: "Performance")

    // MARK: - Configuration

    struct Config {
        static let memoryWarningThreshold: UInt64 = 200 * 1024 * 1024 // 200 MB
        static let slowAPIThreshold: TimeInterval = 10 // seconds
        static let maxAPITimings: Int = 100
    }

    // MARK: - Published Properties

    @Published private(set) var currentMemoryUsage: UInt64 = 0
    @Published private(set) var peakMemoryUsage: UInt64 = 0
    @Published private(set) var apiTimings: [APITiming] = []
    @Published private(set) var isMemoryWarning: Bool = false

    // MARK: - API Timing

    struct APITiming: Identifiable {
        let id = UUID()
        let endpoint: String
        let identifier: String
        let duration: TimeInterval
        let timestamp: Date
        let success: Bool
        let model: String?

        var formattedDuration: String {
            String(format: "%.2fs", duration)
        }

        var isSlow: Bool {
            duration > Config.slowAPIThreshold
        }
    }

    // MARK: - Statistics

    var averageAPITime: TimeInterval {
        guard !apiTimings.isEmpty else { return 0 }
        let total = apiTimings.reduce(0) { $0 + $1.duration }
        return total / Double(apiTimings.count)
    }

    var slowAPICount: Int {
        apiTimings.filter { $0.isSlow }.count
    }

    var successRate: Double {
        guard !apiTimings.isEmpty else { return 1.0 }
        let successful = apiTimings.filter { $0.success }.count
        return Double(successful) / Double(apiTimings.count)
    }

    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(currentMemoryUsage), countStyle: .memory)
    }

    var formattedPeakMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(peakMemoryUsage), countStyle: .memory)
    }

    // MARK: - Initialization

    private init() {
        startMemoryMonitoring()
    }

    // MARK: - Memory Monitoring

    private func startMemoryMonitoring() {
        // Update memory usage every 5 seconds
        Task {
            while true {
                updateMemoryUsage()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            currentMemoryUsage = info.resident_size

            if currentMemoryUsage > peakMemoryUsage {
                peakMemoryUsage = currentMemoryUsage
            }

            // Check for memory warning
            let wasWarning = isMemoryWarning
            isMemoryWarning = currentMemoryUsage > Config.memoryWarningThreshold

            if isMemoryWarning && !wasWarning {
                logger.warning("⚠️ Memory usage exceeded threshold: \(self.formattedMemoryUsage)")
            }
        }
    }

    // MARK: - API Timing

    func recordAPICall(
        endpoint: String,
        identifier: String,
        duration: TimeInterval,
        success: Bool,
        model: String? = nil
    ) {
        let timing = APITiming(
            endpoint: endpoint,
            identifier: identifier,
            duration: duration,
            timestamp: Date(),
            success: success,
            model: model
        )

        apiTimings.insert(timing, at: 0)

        // Keep only recent timings
        if apiTimings.count > Config.maxAPITimings {
            apiTimings = Array(apiTimings.prefix(Config.maxAPITimings))
        }

        // Log slow calls
        if timing.isSlow {
            logger.warning("🐢 Slow API call: \(endpoint) took \(timing.formattedDuration)")
        }

        // Console output
        let icon = success ? "✅" : "❌"
        let slowTag = timing.isSlow ? " [SLOW]" : ""
        print("\(icon) API: \(identifier) - \(timing.formattedDuration)\(slowTag)")
    }

    /// Start timing an API call and return a completion handler
    func startAPITiming(
        endpoint: String,
        identifier: String,
        model: String? = nil
    ) -> (Bool) -> Void {
        let startTime = Date()

        return { [weak self] success in
            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                self?.recordAPICall(
                    endpoint: endpoint,
                    identifier: identifier,
                    duration: duration,
                    success: success,
                    model: model
                )
            }
        }
    }

    // MARK: - Debug Info

    func getDebugReport() -> String {
        """
        === Performance Report ===

        MEMORY
        Current: \(formattedMemoryUsage)
        Peak: \(formattedPeakMemory)
        Warning: \(isMemoryWarning ? "YES" : "No")

        API CALLS (last \(apiTimings.count))
        Average time: \(String(format: "%.2fs", averageAPITime))
        Slow calls: \(slowAPICount)
        Success rate: \(String(format: "%.1f%%", successRate * 100))

        RECENT CALLS:
        \(apiTimings.prefix(10).map { "- \($0.identifier): \($0.formattedDuration) \($0.isSlow ? "[SLOW]" : "")" }.joined(separator: "\n"))
        """
    }

    // MARK: - Reset

    func resetStats() {
        apiTimings.removeAll()
        peakMemoryUsage = currentMemoryUsage
    }
}

// MARK: - Debug Panel Integration

#if DEBUG
extension PerformanceMonitor {
    /// Get summary for debug panel
    var debugSummary: String {
        "Mem: \(formattedMemoryUsage) | API avg: \(String(format: "%.1fs", averageAPITime))"
    }
}
#endif
