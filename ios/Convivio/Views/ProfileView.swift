import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query private var bottles: [Bottle]
    @Query private var wines: [Wine]

    @State private var showApiKeySheet = false
    @State private var showLogsSheet = false
    @State private var isLoadingSamples = false
    @State private var sampleLoadResult: String?
    @State private var showSampleResult = false

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
                            Text("La mia cantina")
                                .font(.headline)
                            Text("Dati salvati localmente")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
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

                // AI Configuration
                Section("Intelligenza Artificiale") {
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
                }

                // App info
                Section("Informazioni") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("2.0 (Locale)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Storage")
                        Spacer()
                        Text("SwiftData")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("AI Engine")
                        Spacer()
                        Text("OpenAI GPT-4o")
                            .foregroundColor(.secondary)
                    }
                }

                // Dev section
                #if DEBUG
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
                #endif
            }
            .navigationTitle("Profilo")
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
