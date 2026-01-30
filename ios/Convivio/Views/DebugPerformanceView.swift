import SwiftUI

// MARK: - Debug Performance View

/// View showing performance metrics for debugging
struct DebugPerformanceView: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared
    @ObservedObject private var cacheService = APICacheService.shared

    var body: some View {
        List {
            // Memory Section
            Section {
                MetricRow(
                    label: "Memoria attuale",
                    value: monitor.formattedMemoryUsage,
                    warning: monitor.isMemoryWarning
                )

                MetricRow(
                    label: "Picco memoria",
                    value: monitor.formattedPeakMemory
                )

                if monitor.isMemoryWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Utilizzo memoria elevato")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            } header: {
                Label("Memoria", systemImage: "memorychip")
            }

            // API Performance Section
            Section {
                MetricRow(
                    label: "Tempo medio",
                    value: String(format: "%.2fs", monitor.averageAPITime)
                )

                MetricRow(
                    label: "Chiamate lente",
                    value: "\(monitor.slowAPICount)",
                    warning: monitor.slowAPICount > 3
                )

                MetricRow(
                    label: "Tasso successo",
                    value: String(format: "%.1f%%", monitor.successRate * 100)
                )

                MetricRow(
                    label: "Chiamate totali",
                    value: "\(monitor.apiTimings.count)"
                )
            } header: {
                Label("API Performance", systemImage: "network")
            }

            // Cache Section
            Section {
                MetricRow(
                    label: "Entries in cache",
                    value: "\(cacheService.cacheStats.entries)"
                )

                MetricRow(
                    label: "Cache hits",
                    value: "\(cacheService.cacheStats.hits)"
                )

                MetricRow(
                    label: "Cache misses",
                    value: "\(cacheService.cacheStats.misses)"
                )

                MetricRow(
                    label: "Hit rate",
                    value: String(format: "%.1f%%", cacheService.cacheStats.hitRate * 100)
                )

                Button("Pulisci cache") {
                    cacheService.clearAll()
                }
                .foregroundColor(.red)
            } header: {
                Label("API Cache", systemImage: "archivebox")
            }

            // Recent API Calls Section
            Section {
                if monitor.apiTimings.isEmpty {
                    Text("Nessuna chiamata registrata")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(monitor.apiTimings.prefix(15)) { timing in
                        APITimingRow(timing: timing)
                    }
                }
            } header: {
                Label("Chiamate recenti", systemImage: "clock")
            }

            // Actions Section
            Section {
                Button("Reset statistiche") {
                    monitor.resetStats()
                }

                Button("Copia report") {
                    UIPasteboard.general.string = monitor.getDebugReport()
                }
            } header: {
                Label("Azioni", systemImage: "wrench")
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Metric Row

private struct MetricRow: View {
    let label: String
    let value: String
    var warning: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(warning ? .orange : .primary)

            if warning {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
}

// MARK: - API Timing Row

private struct APITimingRow: View {
    let timing: PerformanceMonitor.APITiming

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: timing.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(timing.success ? .green : .red)
                    .font(.caption)

                Text(timing.identifier)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Text(timing.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(timing.isSlow ? .orange : .secondary)

                if timing.isSlow {
                    Text("SLOW")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            HStack {
                if let model = timing.model {
                    Text(model)
                        .font(.caption2)
                        .foregroundColor(.purple)
                }

                Text(timing.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Memory Indicator (for status bar)

struct MemoryIndicatorView: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: monitor.isMemoryWarning ? "memorychip.fill" : "memorychip")
                .foregroundColor(monitor.isMemoryWarning ? .orange : .secondary)
                .font(.caption2)

            Text(monitor.formattedMemoryUsage)
                .font(.caption2.monospacedDigit())
                .foregroundColor(monitor.isMemoryWarning ? .orange : .secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DebugPerformanceView()
    }
}
