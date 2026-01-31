import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query private var bottles: [Bottle]
    @Query private var wines: [Wine]
    @Query private var cellars: [Cellar]
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var cloudKitService = CloudKitService.shared
    @ObservedObject private var cellarManager = CellarManager.shared

    @State private var showApiKeySheet = false
    @State private var showLogsSheet = false
    @State private var isLoadingSamples = false
    @State private var sampleLoadResult: String?
    @State private var showSampleResult = false
    @State private var showCollaborationOnboarding = false
    @State private var showRolesInfo = false

    var currentSettings: AppSettings? { settings.first }

    var stats: (total: Int, value: Double, byType: [WineType: Int]) {
        var total = 0
        var value = 0.0
        var byType: [WineType: Int] = [:]

        for bottle in bottles where bottle.quantity > 0 {
            total += bottle.quantity
            if let price = bottle.purchasePrice {
                value += price * Double(bottle.quantity)
            }
            if let wine = bottle.wine {
                byType[wine.type, default: 0] += bottle.quantity
            }
        }

        return (total, value, byType)
    }

    private var syncStatusText: String {
        if cloudKitService.iCloudAvailable {
            switch languageManager.currentLanguage {
            case .italian: return "Sincronizzato con iCloud"
            case .english: return "Synced with iCloud"
            case .german: return "Mit iCloud synchronisiert"
            case .french: return "Synchronisé avec iCloud"
            }
        } else {
            switch languageManager.currentLanguage {
            case .italian: return "Dati salvati localmente"
            case .english: return "Data saved locally"
            case .german: return "Lokal gespeicherte Daten"
            case .french: return "Données enregistrées localement"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // User info
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.myCellar)
                                .font(.headline)
                            HStack(spacing: 4) {
                                if cloudKitService.iCloudAvailable {
                                    Image(systemName: "icloud.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                Text(syncStatusText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // iCloud Sync Section
                Section {
                    if FeatureFlags.cloudKitEnabled {
                        // Sync status row
                        HStack {
                            Image(systemName: cloudKitService.syncStatus.icon)
                                .foregroundColor(cloudKitService.syncStatus.color)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sincronizzazione iCloud")
                                    .font(.subheadline)

                                Text(cloudKitService.syncStatus.displayName)
                                    .font(.caption)
                                    .foregroundColor(cloudKitService.syncStatus.color)
                            }

                            Spacer()

                            if case .syncing = cloudKitService.syncStatus {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        // Last sync
                        if let lastSync = cloudKitService.lastSyncDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)

                                Text("Ultimo sync")

                                Spacer()

                                Text(lastSync, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Manual sync button
                        Button {
                            Task {
                                await cloudKitService.triggerSync()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)

                                Text("Sincronizza ora")

                            Spacer()
                        }
                    }
                        .disabled(!cloudKitService.iCloudAvailable)

                        // iCloud account status
                        if !cloudKitService.iCloudAvailable {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iCloud non disponibile")
                                        .font(.subheadline)
                                    Text("Accedi a iCloud nelle Impostazioni")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // CloudKit disabled via feature flag
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundColor(.secondary)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Archiviazione Locale")
                                    .font(.subheadline)
                                Text("I dati sono salvati solo su questo dispositivo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloud in arrivo")
                                    .font(.subheadline)
                                Text("La sincronizzazione cloud sarà disponibile presto")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Archiviazione")
                } footer: {
                    if FeatureFlags.cloudKitEnabled {
                        Text("I tuoi vini e cene vengono sincronizzati automaticamente su tutti i tuoi dispositivi")
                    } else {
                        Text("Attiva iCloud per sincronizzare i dati tra i tuoi dispositivi")
                    }
                }

                // Collaboration Section
                Section {
                    // Shared cellars count
                    let sharedCellars = cellars.filter { $0.isShared }
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cantine condivise")
                            Text(sharedCellars.isEmpty ? "Nessuna" : "\(sharedCellars.count) cantina/e")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    // Learn about collaboration
                    Button {
                        showCollaborationOnboarding = true
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Collabora con amici")
                                Text("Condividi la cantina e pianifica cene insieme")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    // Roles info
                    Button {
                        showRolesInfo = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            Text("Ruoli e permessi")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text("Collaborazione")
                }

                // Stats
                Section("Statistiche") {
                    StatRow(
                        icon: "wineglass",
                        label: "Bottiglie totali",
                        value: "\(stats.total)"
                    )

                    StatRow(
                        icon: "eurosign.circle",
                        label: "Valore stimato",
                        value: formatCurrency(stats.value)
                    )

                    HStack {
                        Image(systemName: "chart.pie")
                            .foregroundColor(.purple)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Per tipo")
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                ForEach(WineType.allCases, id: \.self) { type in
                                    if let count = stats.byType[type], count > 0 {
                                        HStack(spacing: 2) {
                                            Text(type.icon)
                                                .font(.caption)
                                            Text("\(count)")
                                                .font(.caption.bold())
                                        }
                                    }
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                // Storage Configuration
                Section("Gestione Cantina") {
                    NavigationLink {
                        StorageConfigurationView()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Aree di stoccaggio")
                                    .font(.subheadline)
                                Text("Configura dove conservi i tuoi vini")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Taste Preferences
                Section("Preferenze Gusto") {
                    NavigationLink {
                        TastePreferencesView(settings: currentSettings ?? createSettings())
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("I miei gusti")
                                Text("Configura le tue preferenze vino")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }

                // Language & Locale
                Section {
                    // Language picker
                    Picker(selection: Binding(
                        get: { currentSettings?.preferredLanguage ?? "auto" },
                        set: { newValue in
                            if let settings = currentSettings {
                                settings.preferredLanguage = newValue
                                settings.updatedAt = Date()
                                try? modelContext.save()

                                // Update language manager
                                if newValue == "auto" {
                                    languageManager.setLanguage(AppLanguage.fromDeviceLanguage())
                                } else if let language = AppLanguage(rawValue: newValue) {
                                    languageManager.setLanguage(language)
                                }
                            }
                        }
                    )) {
                        Text("Automatico")
                            .tag("auto")

                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            Text(L10n.language)
                        }
                    }

                    // City text field
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.orange)
                            .frame(width: 30)

                        TextField("Città", text: Binding(
                            get: { currentSettings?.userCity ?? "" },
                            set: { newValue in
                                if let settings = currentSettings {
                                    settings.userCity = newValue.isEmpty ? nil : newValue
                                    settings.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            }
                        ))
                    }

                    // Country picker
                    Picker(selection: Binding(
                        get: { currentSettings?.userCountry ?? "" },
                        set: { newValue in
                            if let settings = currentSettings {
                                settings.userCountry = newValue.isEmpty ? nil : newValue
                                settings.updatedAt = Date()
                                try? modelContext.save()
                            }
                        }
                    )) {
                        Text("Non specificato")
                            .tag("")

                        ForEach(LocaleService.SupportedCountry.all) { country in
                            Text("\(country.nativeName)")
                                .tag(country.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flag")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            Text("Paese")
                        }
                    }
                } header: {
                    Text("Lingua e Località")
                } footer: {
                    if currentSettings?.preferredLanguage == "auto" {
                        Text("Lingua automatica: \(AppLanguage.fromDeviceLanguage().displayName). La località personalizza i suggerimenti AI.")
                    } else {
                        Text("La località personalizza i suggerimenti AI per ingredienti, tradizioni e cultura locale.")
                    }
                }

                // AI Configuration
                Section(L10n.apiKey) {
                    Button {
                        showApiKeySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("API Key OpenAI")
                                if currentSettings?.openAIApiKey != nil {
                                    Text("Configurata")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Non configurata")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button {
                        showLogsSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            Text("Log chiamate AI")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    NavigationLink {
                        PromptConfigurationListView()
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Configurazione Prompt")
                                Text("Personalizza i prompt AI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Informazioni section
                Section("Informazioni") {
                    // About Convivio
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            Text("About Convivio")
                        }
                    }

                    // Privacy Policy
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            Text("Privacy Policy")
                        }
                    }

                    // Istruzioni d'uso
                    NavigationLink {
                        HelpView()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            Text("Istruzioni d'uso")
                        }
                    }

                    // Note di rilascio
                    NavigationLink {
                        ReleaseNotesView()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            Text("Note di rilascio")
                        }
                    }

                    // Debug panel - only visible if debug mode enabled
                    if let settings = currentSettings, settings.debugModeEnabled {
                        NavigationLink {
                            DebugPanelView()
                        } label: {
                            HStack {
                                Image(systemName: "ladybug")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)

                                Text("Pannello Debug")
                            }
                        }
                    }
                }
                .onTapGesture(count: 5) {
                    // Secret gesture to enable debug mode (5 taps)
                    if let settings = currentSettings {
                        settings.debugModeEnabled = true
                        settings.updatedAt = Date()
                        try? modelContext.save()
                    }
                }

                // Dev section - visible when debug mode is enabled
                if currentSettings?.debugModeEnabled == true {
                    Section("Sviluppo") {
                        Button {
                            Task { await loadSampleWines() }
                        } label: {
                            HStack {
                                Image(systemName: "flask")
                                Text("Carica 3 vini di esempio")
                                Spacer()
                                if isLoadingSamples {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isLoadingSamples)

                        Button(role: .destructive) {
                            clearAllData()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Cancella tutti i dati")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeyConfigView(settings: currentSettings ?? createSettings())
            }
            .sheet(isPresented: $showLogsSheet) {
                AILogsView()
            }
            .alert("Vini di esempio", isPresented: $showSampleResult) {
                Button("OK") {}
            } message: {
                Text(sampleLoadResult ?? "")
            }
            .sheet(isPresented: $showCollaborationOnboarding) {
                CollaborationOnboardingView()
            }
            .sheet(isPresented: $showRolesInfo) {
                RolesOverviewView()
            }
            .task {
                await cloudKitService.checkiCloudStatus()
            }
        }
    }

    private func createSettings() -> AppSettings {
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }

    private func loadSampleWines() async {
        isLoadingSamples = true

        let sampleData: [(name: String, producer: String, vintage: String, type: WineType, region: String, price: Double, qty: Int)] = [
            ("Barolo Monfortino Riserva", "Giacomo Conterno", "2015", .red, "Piemonte", 350, 2),
            ("Tignanello", "Antinori", "2019", .red, "Toscana", 120, 3),
            ("Franciacorta Satèn", "Ca' del Bosco", "2018", .sparkling, "Lombardia", 45, 4)
        ]

        for item in sampleData {
            let wine = Wine(
                name: item.name,
                producer: item.producer,
                vintage: item.vintage,
                type: item.type,
                region: item.region,
                country: "Italia"
            )

            let bottle = Bottle(
                wine: wine,
                quantity: item.qty,
                purchasePrice: item.price,
                purchaseDate: Date()
            )

            modelContext.insert(wine)
            modelContext.insert(bottle)
        }

        try? modelContext.save()
        isLoadingSamples = false
        sampleLoadResult = "Aggiunti 3 vini alla cantina!"
        showSampleResult = true
    }

    private func clearAllData() {
        for bottle in bottles {
            modelContext.delete(bottle)
        }
        for wine in wines {
            modelContext.delete(wine)
        }
        try? modelContext.save()
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 30)

            Text(label)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct ApiKeyConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var settings: AppSettings
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-...", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Key OpenAI")
                } footer: {
                    Text("La chiave viene salvata localmente sul tuo dispositivo. Puoi ottenerla da platform.openai.com")
                }

                Section {
                    Button {
                        Task { await validateAndSave() }
                    } label: {
                        HStack {
                            Text("Salva")
                            Spacer()
                            if isValidating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating)

                    if let result = validationResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Errore") ? .red : .green)
                    }
                }

                if settings.openAIApiKey != nil {
                    Section {
                        Button(role: .destructive) {
                            removeApiKey()
                        } label: {
                            Text("Rimuovi API Key")
                        }
                    }
                }
            }
            .navigationTitle("Configura API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existingKey = settings.openAIApiKey {
                    // Show masked key
                    apiKey = String(existingKey.prefix(7)) + "..." + String(existingKey.suffix(4))
                }
            }
        }
    }

    private func validateAndSave() async {
        isValidating = true
        validationResult = nil

        // Basic validation
        guard apiKey.hasPrefix("sk-") else {
            validationResult = "Errore: La chiave deve iniziare con 'sk-'"
            isValidating = false
            return
        }

        // Save the key
        settings.openAIApiKey = apiKey
        settings.updatedAt = Date()
        try? modelContext.save()

        // Update OpenAI service
        await OpenAIService.shared.setApiKey(apiKey)

        validationResult = "API Key salvata con successo!"
        isValidating = false

        // Dismiss after a short delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        dismiss()
    }

    private func removeApiKey() {
        settings.openAIApiKey = nil
        settings.updatedAt = Date()
        try? modelContext.save()
        apiKey = ""
        validationResult = nil
    }
}

// MARK: - AI Logs View

struct AILogsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var logs: [AILogEntry] = []
    @State private var selectedLog: AILogEntry?

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "Nessun log",
                        systemImage: "doc.text",
                        description: Text("I log delle chiamate AI appariranno qui")
                    )
                } else {
                    ForEach(logs) { log in
                        Button {
                            selectedLog = log
                        } label: {
                            LogRow(log: log)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Log AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pulisci") {
                        Task {
                            await OpenAIService.shared.clearLogs()
                            await loadLogs()
                        }
                    }
                    .disabled(logs.isEmpty)
                }
            }
            .task {
                await loadLogs()
            }
            .sheet(item: $selectedLog) { log in
                LogDetailView(log: log)
            }
        }
    }

    private func loadLogs() async {
        logs = await OpenAIService.shared.logs
    }
}

struct LogRow: View {
    let log: AILogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(log.success ? .green : .red)

                Text(log.endpoint)
                    .font(.headline)

                Spacer()

                Text(log.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(log.prompt.prefix(100) + (log.prompt.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(String(format: "%.2fs", log.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let error = log.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let log: AILogEntry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(log.success ? .green : .red)
                            .font(.title)

                        VStack(alignment: .leading) {
                            Text(log.endpoint)
                                .font(.headline)
                            Text(log.formattedTimestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(String(format: "%.2fs", log.duration))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Prompt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROMPT")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Text(log.prompt)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // Response
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RESPONSE")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        if log.success {
                            Text(log.response)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(log.error ?? "Unknown error")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Dettaglio Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Taste Preferences View

struct TastePreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings

    @State private var prefs: TastePreferences = TastePreferences()

    // Wine type options
    let wineTypes = ["Rosso", "Bianco", "Rosato", "Bollicine", "Dolce", "Fortificato"]
    let regions = ["Piemonte", "Toscana", "Veneto", "Lombardia", "Sicilia", "Puglia", "Friuli", "Alto Adige", "Campania", "Umbria"]
    let grapes = ["Nebbiolo", "Sangiovese", "Barbera", "Chardonnay", "Pinot Grigio", "Glera", "Moscato", "Vermentino", "Primitivo", "Nero d'Avola"]

    var body: some View {
        Form {
            Section("Tipi di vino preferiti") {
                ForEach(wineTypes, id: \.self) { type in
                    Toggle(type, isOn: Binding(
                        get: { prefs.preferredWineTypes.contains(type) },
                        set: { isOn in
                            if isOn {
                                prefs.preferredWineTypes.append(type)
                            } else {
                                prefs.preferredWineTypes.removeAll { $0 == type }
                            }
                        }
                    ))
                }
            }

            Section("Regioni preferite") {
                ForEach(regions, id: \.self) { region in
                    Toggle(region, isOn: Binding(
                        get: { prefs.preferredRegions.contains(region) },
                        set: { isOn in
                            if isOn {
                                prefs.preferredRegions.append(region)
                            } else {
                                prefs.preferredRegions.removeAll { $0 == region }
                            }
                        }
                    ))
                }
            }

            Section("Vitigni preferiti") {
                ForEach(grapes, id: \.self) { grape in
                    Toggle(grape, isOn: Binding(
                        get: { prefs.preferredGrapes.contains(grape) },
                        set: { isOn in
                            if isOn {
                                prefs.preferredGrapes.append(grape)
                            } else {
                                prefs.preferredGrapes.removeAll { $0 == grape }
                            }
                        }
                    ))
                }
            }

            Section("Caratteristiche") {
                Picker("Corpo", selection: $prefs.bodyPreference) {
                    ForEach(BodyPreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }

                Picker("Dolcezza", selection: $prefs.sweetnessPreference) {
                    ForEach(SweetnessPreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }

                Picker("Tannini", selection: $prefs.tanninPreference) {
                    ForEach(TanninPreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }

                Picker("Acidità", selection: $prefs.acidityPreference) {
                    ForEach(AcidityPreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
            }

            Section("Note aggiuntive") {
                TextField("Es: Preferisco vini eleganti, non troppo fruttati...", text: Binding(
                    get: { prefs.notes ?? "" },
                    set: { prefs.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("Preferenze Gusto")
        .onAppear {
            prefs = settings.tastePreferences
        }
        .onDisappear {
            settings.tastePreferences = prefs
            settings.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [AppSettings.self, Wine.self, Bottle.self], inMemory: true)
}
