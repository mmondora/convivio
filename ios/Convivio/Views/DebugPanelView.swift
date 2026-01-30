import SwiftUI
import SwiftData
import UserNotifications

struct DebugPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \DinnerEvent.date, order: .reverse) private var dinners: [DinnerEvent]

    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var isLoadingNotifications = false

    private var currentSettings: AppSettings? { settings.first }

    var body: some View {
        List {
            // Debug mode toggle
            Section {
                Toggle(isOn: Binding(
                    get: { currentSettings?.debugModeEnabled ?? false },
                    set: { newValue in
                        if let settings = currentSettings {
                            settings.debugModeEnabled = newValue
                            settings.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Modalità Debug")
                        Text("Mostra pulsanti di test nell'app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Impostazioni Debug")
            }

            // Performance monitoring
            Section {
                NavigationLink {
                    DebugPerformanceView()
                } label: {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.purple)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text("Performance Monitor")
                            MemoryIndicatorView()
                        }
                    }
                }
            } header: {
                Text("Performance")
            }

            // Scheduled notifications
            Section {
                if isLoadingNotifications {
                    HStack {
                        ProgressView()
                        Text("Caricamento...")
                            .foregroundColor(.secondary)
                    }
                } else if pendingNotifications.isEmpty {
                    Text("Nessuna notifica programmata")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pendingNotifications.sorted {
                        getTriggerDate($0) ?? .distantFuture < getTriggerDate($1) ?? .distantFuture
                    }, id: \.identifier) { notification in
                        NotificationRow(notification: notification)
                    }
                }

                Button {
                    Task { await loadNotifications() }
                } label: {
                    Label("Aggiorna", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Notifiche Programmate (\(pendingNotifications.count))")
            }

            // Bottle unload log
            Section {
                let completedDinners = dinners.filter { $0.status == .completed && !$0.confirmedWines.isEmpty }
                if completedDinners.isEmpty {
                    Text("Nessuna bottiglia scaricata")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(completedDinners) { dinner in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(dinner.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(formatDate(dinner.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            ForEach(dinner.confirmedWines, id: \.id) { wine in
                                HStack {
                                    Text("• \(wine.wineName)")
                                        .font(.caption)
                                    Spacer()
                                    Text("×\(wine.quantity)")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Log Bottiglie Scaricate")
            }

            // App info
            Section {
                HStack {
                    Text("Versione")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Info App")
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        isLoadingNotifications = true
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        await MainActor.run {
            pendingNotifications = requests
            isLoadingNotifications = false
        }
    }

    private func getTriggerDate(_ request: UNNotificationRequest) -> Date? {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: UNNotificationRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(notification.content.title)
                .font(.subheadline.bold())

            // Body
            if !notification.content.body.isEmpty {
                Text(notification.content.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Trigger date
            if let triggerDate = getTriggerDate() {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDateTime(triggerDate))
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            // Identifier (for debugging)
            Text(notification.identifier)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func getTriggerDate() -> Date? {
        if let trigger = notification.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        } else if let trigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DebugPanelView()
    }
}
