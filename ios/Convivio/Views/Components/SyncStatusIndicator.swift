import SwiftUI

// MARK: - Sync Status Indicator

/// Compact indicator showing CloudKit sync status
struct SyncStatusIndicator: View {
    @ObservedObject var cloudKit = CloudKitService.shared

    var showLabel: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            if showLabel {
                statusLabel
            }
        }
        .font(.caption)
        .foregroundColor(cloudKit.syncStatus.color)
        .animation(.easeInOut(duration: 0.3), value: cloudKit.syncStatus)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch cloudKit.syncStatus {
        case .syncing:
            Image(systemName: cloudKit.syncStatus.icon)
                .symbolEffect(.rotate, options: .repeating)
        default:
            Image(systemName: cloudKit.syncStatus.icon)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        Text(cloudKit.syncStatus.displayName)
            .lineLimit(1)
    }
}

// MARK: - Sync Status Badge

/// Badge version for toolbar or navigation bar
struct SyncStatusBadge: View {
    @ObservedObject var cloudKit = CloudKitService.shared

    var body: some View {
        Button {
            Task {
                await cloudKit.triggerSync()
            }
        } label: {
            SyncStatusIndicator()
        }
        .buttonStyle(.plain)
        .help("Tocca per sincronizzare")
    }
}

// MARK: - Sync Status Detail View

/// Detailed sync status for settings or debug
struct SyncStatusDetailView: View {
    @ObservedObject var cloudKit = CloudKitService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack {
                Image(systemName: cloudKit.syncStatus.icon)
                    .foregroundColor(cloudKit.syncStatus.color)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stato Sincronizzazione")
                        .font(.headline)
                    Text(cloudKit.syncStatus.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if cloudKit.syncStatus != .syncing {
                    Button {
                        Task {
                            await cloudKit.triggerSync()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // iCloud account status
            HStack {
                Image(systemName: cloudKit.iCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(cloudKit.iCloudAvailable ? .green : .red)

                Text("Account iCloud")
                    .font(.subheadline)

                Spacer()

                Text(cloudKit.iCloudAvailable ? "Connesso" : "Non disponibile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // User info
            if let userName = cloudKit.currentUserName {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.secondary)

                    Text("Utente")
                        .font(.subheadline)

                    Spacer()

                    Text(userName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Last sync
            if let lastSync = cloudKit.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)

                    Text("Ultima sincronizzazione")
                        .font(.subheadline)

                    Spacer()

                    Text(lastSync, style: .relative)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Indicator") {
    VStack(spacing: 20) {
        SyncStatusIndicator()
        SyncStatusIndicator(showLabel: true)
        SyncStatusBadge()
    }
    .padding()
}

#Preview("Detail") {
    SyncStatusDetailView()
        .padding()
}
