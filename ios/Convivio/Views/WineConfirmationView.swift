import SwiftUI
import SwiftData
import UserNotifications

struct WineConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var dinner: DinnerEvent

    @State private var confirmedWines: [ConfirmedWine] = []
    @State private var isScheduling = false
    @State private var showPermissionAlert = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

    // Max width for content on iPad
    private var maxContentWidth: CGFloat? {
        horizontalSizeClass == .regular ? 600 : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header info
                    headerSection

                    // Wine list
                    if confirmedWines.isEmpty {
                        emptyStateView
                    } else {
                        wineListSection
                    }

                    // Schedule summary (only for wines with quantity > 0)
                    if activeWinesCount > 0 {
                        scheduleSummarySection
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Success message
                    if showSuccessMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Notifiche programmate con successo!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Action buttons
                    actionButtonsSection
                }
                .padding()
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Conferma Vini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onAppear {
                loadWinesFromMenu()
            }
            .alert("Notifiche non autorizzate", isPresented: $showPermissionAlert) {
                Button("Apri Impostazioni") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Per ricevere promemoria sulla temperatura dei vini, abilita le notifiche nelle Impostazioni.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Temperatura di Servizio")
                    .font(.headline)
            }

            Text("Conferma i vini e ricevi notifiche per la temperatura ottimale di servizio.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Label(formatDate(dinner.date), systemImage: "calendar")
                Label(formatTime(dinner.date), systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Nessun vino da confermare")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Genera prima un menu con abbinamenti vino.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Wine List Section

    private var activeWinesCount: Int {
        confirmedWines.filter { $0.quantity > 0 }.count
    }

    private var wineListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vini dal Menu")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(activeWinesCount) di \(confirmedWines.count) selezionati")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if activeWinesCount < confirmedWines.count {
                        Text("Usa +/- per regolare le quantità")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }

            ForEach(confirmedWines.indices, id: \.self) { index in
                WineConfirmationRow(
                    wine: $confirmedWines[index],
                    onDelete: nil // No delete button, use quantity 0 instead
                )
            }
        }
    }

    // MARK: - Schedule Summary Section

    private var scheduleSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Programma Notifiche", systemImage: "bell")
                .font(.headline)

            // Only include wines with quantity > 0
            let activeWines = confirmedWines.filter { $0.quantity > 0 }
            let summary = WineConfirmationSummary(confirmedWines: activeWines, dinnerDate: dinner.date)
            let schedule = summary.fridgeSchedule()

            if schedule.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("I vini rossi strutturati si servono a temperatura ambiente.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                ForEach(schedule, id: \.wine.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "snowflake")
                                .foregroundColor(.blue)
                            Text(formatTime(item.putInTime))
                                .font(.caption.bold())
                            Text("Metti in frigo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(item.wine.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)

                        if let takeOutTime = item.takeOutTime {
                            HStack {
                                Image(systemName: "thermometer.sun")
                                    .foregroundColor(.orange)
                                Text(formatTime(takeOutTime))
                                    .font(.caption.bold())
                                Text("Togli dal frigo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await scheduleNotifications() }
            } label: {
                HStack {
                    if isScheduling {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bell.badge")
                    }
                    Text(isScheduling ? "Programmazione..." : "Conferma e Programma Notifiche")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(activeWinesCount == 0 || isScheduling ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(activeWinesCount == 0 || isScheduling)

            if activeWinesCount == 0 && !confirmedWines.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Aumenta la quantità di almeno un vino per confermare")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            if dinner.notificationsScheduled {
                Button(role: .destructive) {
                    Task { await cancelNotifications() }
                } label: {
                    Label("Cancella Notifiche Programmate", systemImage: "bell.slash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
            }

            #if DEBUG
            // Test notification button
            Button {
                testNotification()
            } label: {
                HStack {
                    Image(systemName: "bell.badge")
                    Text("Test Notifica (5 sec)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }
            #endif
        }
    }

    #if DEBUG
    private func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notifica Convivio"
        content.body = "Se vedi questo messaggio, le notifiche funzionano! 🍷"
        content.sound = .default

        // Fire in 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling test notification: \(error)")
            } else {
                print("✅ Test notification scheduled - will fire in 5 seconds")
            }
        }
    }
    #endif

    // MARK: - Actions

    private func loadWinesFromMenu() {
        // First check if there are already confirmed wines
        if !dinner.confirmedWines.isEmpty {
            confirmedWines = dinner.confirmedWines
            return
        }

        // Otherwise, load from menu
        guard let menu = dinner.menuResponse else { return }

        var wines: [ConfirmedWine] = []

        // Add wines from pairings
        for pairing in menu.abbinamenti {
            var wine = ConfirmedWine.from(pairing: pairing)
            // Try to suggest temperature based on wine name/type
            wine.temperatureCategory = suggestTemperature(for: wine)
            wines.append(wine)
        }

        confirmedWines = wines
    }

    private func suggestTemperature(for wine: ConfirmedWine) -> WineTemperatureCategory {
        let nameLower = wine.wineName.lowercased()

        // Check for sparkling indicators
        if nameLower.contains("spumante") || nameLower.contains("prosecco") ||
           nameLower.contains("champagne") || nameLower.contains("franciacorta") ||
           nameLower.contains("metodo classico") || nameLower.contains("brut") {
            return .bollicine
        }

        // Check for rosé
        if nameLower.contains("rosato") || nameLower.contains("rosé") ||
           nameLower.contains("cerasuolo") || nameLower.contains("chiaretto") {
            return .rosato
        }

        // Check for white wine indicators
        if nameLower.contains("bianco") || nameLower.contains("verdicchio") ||
           nameLower.contains("pinot grigio") || nameLower.contains("sauvignon") ||
           nameLower.contains("chardonnay") || nameLower.contains("vermentino") ||
           nameLower.contains("trebbiano") || nameLower.contains("soave") ||
           nameLower.contains("gavi") || nameLower.contains("falanghina") {
            // Check if structured white
            if nameLower.contains("riserva") || nameLower.contains("barrique") {
                return .biancoStrutturato
            }
            return .biancoLeggero
        }

        // Check for light red indicators
        if nameLower.contains("lambrusco") || nameLower.contains("grignolino") ||
           nameLower.contains("schiava") || nameLower.contains("freisa") {
            return .rossoLeggero
        }

        // Default to structured red for most wines
        return .rossoStrutturato
    }

    private func scheduleNotifications() async {
        isScheduling = true
        errorMessage = nil
        showSuccessMessage = false

        // Filter wines with quantity > 0
        let activeWines = confirmedWines.filter { $0.quantity > 0 }

        guard !activeWines.isEmpty else {
            await MainActor.run {
                errorMessage = "Seleziona almeno un vino con quantità > 0"
                isScheduling = false
            }
            return
        }

        // Request permission
        let granted = await NotificationService.shared.requestPermission()
        if !granted {
            await MainActor.run {
                isScheduling = false
                showPermissionAlert = true
            }
            return
        }

        do {
            // Schedule notifications only for active wines
            let result = try await NotificationService.shared.scheduleWineNotifications(
                for: dinner,
                wines: activeWines
            )

            await MainActor.run {
                // Update confirmed wines with notification IDs
                // Keep all wines but only the active ones have notifications
                var updatedWines = confirmedWines
                for resultWine in result.wines {
                    if let index = updatedWines.firstIndex(where: { $0.id == resultWine.id }) {
                        updatedWines[index] = resultWine
                    }
                }
                confirmedWines = updatedWines
                dinner.confirmedWines = updatedWines.filter { $0.quantity > 0 } // Only save active wines
                dinner.postDinnerNotificationId = result.postDinnerNotificationId
                dinner.notificationsScheduled = true
                dinner.updatedAt = Date()
                try? modelContext.save()
                isScheduling = false

                // Dismiss and return to menu
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isScheduling = false
            }
        }
    }

    private func cancelNotifications() async {
        await NotificationService.shared.cancelNotifications(for: dinner)

        await MainActor.run {
            // Clear notification IDs from wines
            for i in confirmedWines.indices {
                confirmedWines[i].putInFridgeNotificationId = nil
                confirmedWines[i].takeOutNotificationId = nil
            }
            dinner.confirmedWines = confirmedWines
            dinner.postDinnerNotificationId = nil
            dinner.notificationsScheduled = false
            dinner.updatedAt = Date()
            try? modelContext.save()
            showSuccessMessage = false
        }
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Wine Confirmation Row

struct WineConfirmationRow: View {
    @Binding var wine: ConfirmedWine
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Wine info header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(wine.isFromCellar ? "Cantina" : "Acquisto")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(wine.isFromCellar ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundColor(wine.isFromCellar ? .green : .blue)
                            .cornerRadius(4)

                        Text(wine.course.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(wine.displayName)
                        .font(.subheadline.bold())
                }

                Spacer()

                Image(systemName: wine.temperatureCategory.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
            }

            // Quantity stepper
            HStack {
                Text("Bottiglie")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        if wine.quantity > 0 {
                            wine.quantity -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(wine.quantity > 0 ? .purple : .gray)
                    }
                    .disabled(wine.quantity <= 0)

                    Text("\(wine.quantity)")
                        .font(.title2.bold())
                        .frame(minWidth: 44)
                        .foregroundColor(wine.quantity == 0 ? .secondary : .primary)

                    Button {
                        wine.quantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.vertical, 4)

            // Zero quantity warning
            if wine.quantity == 0 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Questo vino verrà escluso dalla conferma")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Temperature picker (only if quantity > 0)
            if wine.quantity > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temperatura di servizio")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Picker("Temperatura", selection: $wine.temperatureCategory) {
                        ForEach(WineTemperatureCategory.allCases) { category in
                            HStack {
                                Text(category.displayName)
                                Text(category.servingTemperature)
                                    .foregroundColor(.secondary)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.purple)

                    Text(wine.temperatureCategory.servingInstructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(6)
                }
            }

            // Notification status
            if wine.hasScheduledNotifications {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.green)
                    Text("Notifiche programmate")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(wine.quantity == 0 ? Color(.secondarySystemBackground).opacity(0.5) : Color(.secondarySystemBackground))
        .cornerRadius(12)
        .opacity(wine.quantity == 0 ? 0.7 : 1.0)
    }
}
