import SwiftUI
import SwiftData

struct WineConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var dinner: DinnerEvent

    @State private var confirmedWines: [ConfirmedWine] = []
    @State private var isScheduling = false
    @State private var showPermissionAlert = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

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

                    // Schedule summary
                    if !confirmedWines.isEmpty {
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

    private var wineListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vini Selezionati")
                .font(.headline)

            ForEach(confirmedWines.indices, id: \.self) { index in
                WineConfirmationRow(wine: $confirmedWines[index])
            }
        }
    }

    // MARK: - Schedule Summary Section

    private var scheduleSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Programma Notifiche", systemImage: "bell")
                .font(.headline)

            let summary = WineConfirmationSummary(confirmedWines: confirmedWines, dinnerDate: dinner.date)
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
                .background(confirmedWines.isEmpty || isScheduling ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(confirmedWines.isEmpty || isScheduling)

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
        }
    }

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
            // Schedule notifications
            let result = try await NotificationService.shared.scheduleWineNotifications(
                for: dinner,
                wines: confirmedWines
            )

            await MainActor.run {
                confirmedWines = result.wines
                dinner.confirmedWines = result.wines
                dinner.postDinnerNotificationId = result.postDinnerNotificationId
                dinner.notificationsScheduled = true
                dinner.updatedAt = Date()
                try? modelContext.save()
                isScheduling = false
                showSuccessMessage = true
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Wine info
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

                    Text("\(wine.quantity) bottigli\(wine.quantity == 1 ? "a" : "e")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: wine.temperatureCategory.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
            }

            // Temperature picker
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
