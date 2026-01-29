import SwiftUI
import SwiftData
import UserNotifications

struct FoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DinnerEvent.date, order: .reverse) private var dinners: [DinnerEvent]

    @State private var showNewDinner = false

    var body: some View {
        NavigationStack {
            Group {
                if dinners.isEmpty {
                    ContentUnavailableView(
                        "Nessun pasto pianificato",
                        systemImage: "fork.knife",
                        description: Text("Aggiungi una cena o un pranzo per iniziare")
                    )
                } else {
                    List {
                        ForEach(dinners) { dinner in
                            NavigationLink(destination: DinnerDetailView(dinner: dinner)) {
                                DinnerRowView(dinner: dinner)
                            }
                        }
                        .onDelete(perform: deleteDinners)
                    }
                }
            }
            .navigationTitle("Convivio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewDinner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewDinner) {
                NewDinnerView()
            }
        }
    }

    private func deleteDinners(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(dinners[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Dinner Row

struct DinnerRowView: View {
    let dinner: DinnerEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dinner.title)
                    .font(.headline)

                Spacer()

                StatusBadge(status: dinner.status)
            }

            HStack {
                Label(formatDate(dinner.date), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label("\(dinner.guestCount)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if dinner.needsBottleUnload {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Da completare - scarica bottiglie")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else if dinner.menu != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Menu generato")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: DinnerStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    var backgroundColor: Color {
        switch status {
        case .planning: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
}

// MARK: - New Convivio View

struct NewDinnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wines: [Wine]
    @Query(filter: #Predicate<Bottle> { $0.quantity > 0 }) private var bottles: [Bottle]
    @Query private var appSettings: [AppSettings]

    @State private var title = ""
    @State private var date = Date()
    @State private var guestCount = 4
    @State private var occasion = ""
    @State private var tipoDieta: DietType = .normale
    @State private var tipoCucina: String = CuisineType.italiana.rawValue
    @State private var notes = ""

    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var settings: AppSettings? { appSettings.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Convivio") {
                    TextField("Titolo (es: Cena di compleanno)", text: $title)

                    DatePicker("Data e ora", selection: $date)

                    Stepper("Ospiti: \(guestCount)", value: $guestCount, in: 1...20)

                    OccasionPicker(occasion: $occasion)
                }

                Section("Particolarità alimentari") {
                    Picker("Dieta", selection: $tipoDieta) {
                        ForEach(DietType.allCases) { diet in
                            Label(diet.displayName, systemImage: diet.icon)
                                .tag(diet)
                        }
                    }
                }

                Section("Tipo di cucina") {
                    Picker("Cucina", selection: $tipoCucina) {
                        ForEach(CuisineType.allCases) { cuisine in
                            Text(cuisine.rawValue).tag(cuisine.rawValue)
                        }
                    }
                }

                Section("Note per il menu") {
                    TextField("Es: Menu leggero, no piccante, piatti della tradizione...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if settings?.openAIApiKey == nil {
                    Section {
                        Label("Configura API key OpenAI in Profilo per generare il menu automaticamente", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Nuovo Convivio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createAndGenerateMenu() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Crea")
                        }
                    }
                    .disabled(title.isEmpty || isGenerating)
                }
            }
        }
    }

    private func createAndGenerateMenu() async {
        isGenerating = true
        errorMessage = nil

        // Create the dinner event
        let dinner = DinnerEvent(
            title: title,
            date: date,
            guestCount: guestCount,
            occasion: occasion.isEmpty ? nil : occasion,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(dinner)

        // Generate menu if API key is available
        if settings?.openAIApiKey != nil {
            let request = MenuRequest(
                titolo: title,
                data: date,
                persone: guestCount,
                occasione: occasion.isEmpty ? nil : occasion,
                tipoDieta: tipoDieta,
                tipoCucina: tipoCucina,
                descrizione: notes.isEmpty ? nil : notes,
                tastePreferences: settings?.tastePreferences
            )

            do {
                let response = try await MenuGeneratorService.shared.generateMenu(
                    request: request,
                    wines: wines,
                    bottles: bottles
                )

                await MainActor.run {
                    // Store the full response as JSON in menuData
                    if let jsonData = try? JSONEncoder().encode(response) {
                        dinner.menuData = jsonData
                    }
                    dinner.updatedAt = Date()
                    try? modelContext.save()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Errore generazione menu: \(error.localizedDescription)"
                    // Save dinner anyway without menu
                    try? modelContext.save()
                }
            }
        } else {
            try? modelContext.save()
            dismiss()
        }

        await MainActor.run {
            isGenerating = false
        }
    }
}

// MARK: - Dinner Detail View

struct DinnerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wines: [Wine]
    @Query(filter: #Predicate<Bottle> { $0.quantity > 0 }) private var bottles: [Bottle]
    @Query private var appSettings: [AppSettings]

    @Bindable var dinner: DinnerEvent

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var selectedDish: Dish?
    @State private var selectedWinePairing: MenuWinePairing?
    @State private var showEditSheet = false
    @State private var expandedSections: Set<String> = ["menu", "vini"]
    @State private var showWineConfirmation = false
    @State private var showInviteGenerator = false
    @State private var showBottleUnload = false
    @State private var regeneratingDish: (course: String, index: Int)?
    @State private var showDeleteConfirmation = false
    @State private var dishToDelete: (course: String, index: Int)?

    private var settings: AppSettings? { appSettings.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header info
                dinnerInfoSection

                // Menu section
                if let menuResponse = dinner.menuResponse {
                    generatedMenuResponseSection(menuResponse)
                } else if dinner.menu != nil {
                    // Legacy support
                    Text("Menu generato (formato legacy)")
                        .foregroundColor(.secondary)
                } else {
                    generateMenuSection
                }
            }
            .padding()
        }
        .navigationTitle(dinner.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifica") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditDinnerView(dinner: dinner)
        }
        .sheet(item: $selectedDish) { dish in
            RecipeDetailView(dish: dish, guestCount: dinner.guestCount)
        }
        .sheet(item: $selectedWinePairing) { pairing in
            WinePairingDetailView(pairing: pairing, bottles: bottles)
        }
        .sheet(isPresented: $showWineConfirmation) {
            WineConfirmationView(dinner: dinner)
        }
        .sheet(isPresented: $showInviteGenerator) {
            InviteGeneratorView(dinner: dinner)
        }
        .sheet(isPresented: $showBottleUnload) {
            BottleUnloadView(dinner: dinner)
        }
        .alert("Elimina piatto", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                if let toDelete = dishToDelete {
                    deleteDish(course: toDelete.course, index: toDelete.index)
                }
            }
        } message: {
            Text("Vuoi eliminare questo piatto dal menu?")
        }
    }

    // MARK: - Dinner Info Section

    private var dinnerInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Label(formatDate(dinner.date), systemImage: "calendar")
                    Label("\(dinner.guestCount) persone", systemImage: "person.2")
                    if let occasion = dinner.occasion {
                        Label(occasion, systemImage: "star")
                    }
                }
                .font(.subheadline)

                Spacer()

                StatusBadge(status: dinner.status)
            }

            if let notes = dinner.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            // Post-dinner unload banner
            if dinner.needsBottleUnload {
                postDinnerUnloadBanner
            }
        }
    }

    // MARK: - Post-Dinner Unload Banner

    private var postDinnerUnloadBanner: some View {
        Button {
            showBottleUnload = true
        } label: {
            HStack {
                Image(systemName: "wineglass.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cena completata!")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Conferma le bottiglie consumate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Menu Section

    private var generateMenuSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(.purple)

            Text("Genera il menu")
                .font(.headline)

            Text("L'AI creerà un menu personalizzato con ricette e abbinamenti vino dalla tua cantina")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            Button {
                Task { await generateMenu() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Generazione..." : "Genera Menu")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGenerating ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isGenerating || settings?.openAIApiKey == nil)

            if settings?.openAIApiKey == nil {
                Text("Configura l'API key OpenAI in Profilo")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Generated Menu Section

    private func generatedMenuResponseSection(_ menu: MenuResponse) -> some View {
        VStack(spacing: 16) {
            // Menu courses
            DisclosureGroup(
                isExpanded: bindingFor("menu"),
                content: {
                    VStack(spacing: 12) {
                        ForEach(menu.menu.allCourses, id: \.name) { course in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(course.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.purple)

                                ForEach(Array(course.dishes.enumerated()), id: \.element.id) { index, dish in
                                    EditableDishRow(
                                        dish: dish,
                                        courseName: course.name,
                                        dishIndex: index,
                                        isRegenerating: regeneratingDish?.course == course.name && regeneratingDish?.index == index,
                                        onTap: { selectedDish = dish },
                                        onRegenerate: { regenerateDish(course: course.name, index: index) },
                                        onDelete: {
                                            dishToDelete = (course.name, index)
                                            showDeleteConfirmation = true
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    Label("Menu", systemImage: "menucard")
                        .font(.headline)
                }
            )
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Wine pairings - compact view
            DisclosureGroup(
                isExpanded: bindingFor("vini"),
                content: {
                    VStack(alignment: .leading, spacing: 12) {
                        // Wines from cellar
                        let cellarWines = menu.abbinamenti.filter { $0.vino.provenienza == .cantina }
                        if !cellarWines.isEmpty {
                            ForEach(cellarWines) { pairing in
                                Button {
                                    selectedWinePairing = pairing
                                } label: {
                                    CompactWineRow(
                                        label: "Cantina",
                                        wine: "\(pairing.vino.quantitaNecessaria) bott. \(pairing.vino.produttore) \(pairing.vino.nome)",
                                        vintage: pairing.vino.annata,
                                        compatibility: pairing.vino.compatibilita?.punteggio
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Purchase suggestions
                        if !menu.suggerimentiAcquisto.isEmpty {
                            ForEach(menu.suggerimentiAcquisto) { suggestion in
                                CompactWineRow(
                                    label: "Acquisto",
                                    wine: "\(suggestion.produttore) \(suggestion.vino)",
                                    vintage: suggestion.annata,
                                    compatibility: suggestion.compatibilita?.punteggio
                                )
                            }
                        }

                        // Service notes
                        if !menu.noteServizio.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Note di servizio")
                                    .font(.caption.bold())
                                Text(menu.noteServizio)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                },
                label: {
                    Label("Vini", systemImage: "wineglass")
                        .font(.headline)
                }
            )
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Galateo section
            DisclosureGroup(
                isExpanded: bindingFor("galateo"),
                content: {
                    GalateoView(galateo: menu.galateo)
                        .padding(.top, 8)
                },
                label: {
                    Label("Galateo", systemImage: "sparkles")
                        .font(.headline)
                }
            )
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Action buttons
            VStack(spacing: 12) {
                // Bottle unload button for past dinners or debug
                if dinner.status != .completed && !dinner.confirmedWines.isEmpty {
                    Button {
                        showBottleUnload = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Scarica Bottiglie")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                }

                // Wine confirmation button
                if !menu.abbinamenti.isEmpty {
                    Button {
                        showWineConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: dinner.notificationsScheduled ? "bell.badge.fill" : "thermometer.medium")
                            Text(dinner.notificationsScheduled ? "Vini Confermati" : "Conferma Vini")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(dinner.notificationsScheduled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(dinner.notificationsScheduled ? .green : .orange)
                        .cornerRadius(12)
                    }
                }

                // Invite generator button
                Button {
                    showInviteGenerator = true
                } label: {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Genera Invito")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }

                // Regenerate button
                Button {
                    Task { await regenerateMenu() }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.purple)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isGenerating ? "Rigenerazione..." : "Rigenera Menu")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
                .disabled(isGenerating || settings?.openAIApiKey == nil)

                #if DEBUG
                // Debug section
                debugButtonsSection
                #endif

                // Completed dinner indicator
                if dinner.status == .completed {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Cena completata")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugButtonsSection: some View {
        VStack(spacing: 8) {
            Divider()

            Text("DEBUG")
                .font(.caption.bold())
                .foregroundColor(.red)

            // Simulate post-dinner notification
            Button {
                simulatePostDinnerNotification()
            } label: {
                HStack {
                    Image(systemName: "bell.badge")
                    Text("Simula Notifica Scarico")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(12)
            }

            // Show bottle unload directly
            Button {
                showBottleUnload = true
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Apri Scarico Bottiglie")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }

    private func simulatePostDinnerNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Com'è andata la cena?"
        content.body = "Conferma le bottiglie consumate per aggiornare la cantina"
        content.sound = .default
        content.categoryIdentifier = "BOTTLE_UNLOAD"
        content.userInfo = [
            "dinnerTitle": dinner.title,
            "action": "unloadBottles"
        ]

        // Fire in 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)

        let request = UNNotificationRequest(
            identifier: "debug-postDinner-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling debug notification: \(error)")
            } else {
                print("Debug notification scheduled - will fire in 3 seconds")
            }
        }
    }
    #endif

    private func bindingFor(_ section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    // MARK: - Dish Editing Actions

    private func regenerateDish(course: String, index: Int) {
        guard let currentMenu = dinner.menuResponse else { return }

        regeneratingDish = (course, index)

        Task {
            do {
                let updatedMenu = try await MenuGeneratorService.shared.regenerateDish(
                    courseName: course,
                    dishIndex: index,
                    currentMenu: currentMenu,
                    dinner: dinner,
                    wines: wines,
                    bottles: bottles,
                    tastePreferences: settings?.tastePreferences
                )

                await MainActor.run {
                    if let jsonData = try? JSONEncoder().encode(updatedMenu) {
                        dinner.menuData = jsonData
                    }
                    dinner.updatedAt = Date()
                    try? modelContext.save()
                    regeneratingDish = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Errore: \(error.localizedDescription)"
                    regeneratingDish = nil
                }
            }
        }
    }

    private func deleteDish(course: String, index: Int) {
        guard let currentMenu = dinner.menuResponse else { return }

        let updatedMenu = MenuGeneratorService.shared.deleteDish(
            courseName: course,
            dishIndex: index,
            from: currentMenu
        )

        if let jsonData = try? JSONEncoder().encode(updatedMenu) {
            dinner.menuData = jsonData
        }
        dinner.updatedAt = Date()
        try? modelContext.save()
        dishToDelete = nil
    }

    // MARK: - Menu Actions

    private func generateMenu() async {
        isGenerating = true
        errorMessage = nil

        let request = MenuRequest(
            titolo: dinner.title,
            data: dinner.date,
            persone: dinner.guestCount,
            occasione: dinner.occasion,
            tipoDieta: .normale,
            tipoCucina: "Italiana",
            descrizione: dinner.notes,
            tastePreferences: settings?.tastePreferences
        )

        do {
            let response = try await MenuGeneratorService.shared.generateMenu(
                request: request,
                wines: wines,
                bottles: bottles
            )

            await MainActor.run {
                // Store full MenuResponse as JSON
                if let jsonData = try? JSONEncoder().encode(response) {
                    dinner.menuData = jsonData
                }
                dinner.updatedAt = Date()
                try? modelContext.save()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isGenerating = false
        }
    }

    private func regenerateMenu() async {
        // Clear existing menu first
        await MainActor.run {
            dinner.menuData = nil
        }
        // Then generate new menu
        await generateMenu()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Editable Dish Row

struct EditableDishRow: View {
    let dish: Dish
    let courseName: String
    let dishIndex: Int
    let isRegenerating: Bool
    let onTap: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            DishRow(dish: dish, isRegenerating: isRegenerating)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRegenerate()
            } label: {
                Label("Rigenera piatto", systemImage: "arrow.clockwise")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Elimina piatto", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onRegenerate()
            } label: {
                Label("Rigenera", systemImage: "arrow.clockwise")
            }
            .tint(.purple)
        }
    }
}

// MARK: - Dish Row

struct DishRow: View {
    let dish: Dish
    var isRegenerating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dish.nome)
                    .font(.subheadline.bold())

                if isRegenerating {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Text(dish.descrizione)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(dish.ricetta.tempoTotale) min", systemImage: "clock")
                Label(dish.ricetta.difficolta.capitalized, systemImage: "chart.bar")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .opacity(isRegenerating ? 0.6 : 1.0)
    }
}

// MARK: - Galateo View

struct GalateoView: View {
    let galateo: GalateoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Inviti
            GalateoSubSection(
                title: "Inviti",
                icon: "envelope",
                items: [
                    ("Tempistica", galateo.inviti.tempistica),
                    ("Formulazione", galateo.inviti.formulazione),
                    ("Conferma", galateo.inviti.conferma)
                ],
                tips: galateo.inviti.consigli
            )

            // Ricevimento
            GalateoSubSection(
                title: "Ricevimento",
                icon: "person.2",
                items: [
                    ("Accoglienza", galateo.ricevimento.accoglienza),
                    ("Aperitivo", galateo.ricevimento.aperitivo),
                    ("A tavola", galateo.ricevimento.passaggioTavola),
                    ("Congedo", galateo.ricevimento.congedo)
                ],
                tips: galateo.ricevimento.consigli
            )

            // Tavola
            GalateoSubSection(
                title: "Tavola",
                icon: "fork.knife",
                items: [
                    ("Disposizione", galateo.tavola.disposizione),
                    ("Servizio", galateo.tavola.servizio),
                    ("Conversazione", galateo.tavola.conversazione)
                ],
                tips: galateo.tavola.consigli
            )
        }
    }
}

struct GalateoSubSection: View {
    let title: String
    let icon: String
    let items: [(String, String)]
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.purple)

            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.caption.bold())
                    Text(item.1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consigli")
                        .font(.caption.bold())
                        .foregroundColor(.orange)

                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Compact Wine Row

struct CompactWineRow: View {
    let label: String
    let wine: String
    let vintage: String?
    let compatibility: Int?

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(label == "Cantina" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundColor(label == "Cantina" ? .green : .blue)
                .cornerRadius(4)

            VStack(alignment: .leading) {
                Text(wine)
                    .font(.subheadline)
                if let vintage = vintage {
                    Text(vintage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let score = compatibility {
                CompatibilityBadge(score: score)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct CompatibilityBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)%")
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.2))
            .foregroundColor(backgroundColor)
            .cornerRadius(4)
    }

    var backgroundColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: MenuCourse
    let onRecipeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(course.course.icon)
                Text(course.course.displayName)
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }

            Text(course.name)
                .font(.headline)

            Text(course.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                onRecipeTap()
            } label: {
                Label("Vedi ricetta", systemImage: "book")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let dish: Dish
    let guestCount: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dish.nome)
                            .font(.title2.bold())

                        Text(dish.descrizione)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Label("\(dish.ricetta.tempoPreparazione) min prep", systemImage: "clock")
                            Label("\(dish.ricetta.tempoCottura) min cottura", systemImage: "flame")
                            Label(dish.ricetta.difficolta.capitalized, systemImage: "chart.bar")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Divider()

                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredienti")
                            .font(.headline)

                        Text("Per \(guestCount) persone")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(dish.ricetta.ingredienti) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.purple)
                                Text(ingredient.displayText)
                                    .font(.subheadline)
                            }
                        }
                    }

                    Divider()

                    // Procedure
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Procedimento")
                            .font(.headline)

                        ForEach(Array(dish.ricetta.procedimento.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .frame(width: 24, height: 24)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)

                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Tips
                    if let consigli = dish.ricetta.consigli {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Consigli", systemImage: "lightbulb")
                                .font(.headline)

                            Text(consigli)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ricetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Wine Pairing Detail View

struct WinePairingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let pairing: MenuWinePairing
    let bottles: [Bottle]

    private var availability: WineAvailabilityStatus {
        MenuGeneratorService.checkWineAvailability(pairing: pairing, bottles: bottles)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Wine info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pairing.vino.provenienza.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(pairing.vino.provenienza == .cantina ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                .foregroundColor(pairing.vino.provenienza == .cantina ? .green : .blue)
                                .cornerRadius(4)

                            Spacer()

                            if let message = availability.message {
                                Text(message)
                                    .font(.caption)
                            }
                        }

                        Text(pairing.vino.produttore)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(pairing.vino.nome)
                            .font(.title2.bold())

                        if let annata = pairing.vino.annata {
                            Text(annata)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Pairing info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Abbinamento: \(pairing.portata.capitalized)")
                            .font(.headline)

                        Text(pairing.vino.motivazione)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(pairing.vino.quantitaNecessaria) bottigli\(pairing.vino.quantitaNecessaria == 1 ? "a" : "e") necessari\(pairing.vino.quantitaNecessaria == 1 ? "a" : "e")")
                            .font(.caption)
                    }

                    // Compatibility
                    if let compat = pairing.vino.compatibilita {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Compatibilità con i tuoi gusti")
                                    .font(.headline)

                                Spacer()

                                CompatibilityBadge(score: compat.punteggio)
                            }

                            Text(compat.motivazione)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if !compat.puntiForza.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Punti di forza")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)

                                    ForEach(compat.puntiForza, id: \.self) { punto in
                                        Label(punto, systemImage: "plus.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }

                            if !compat.puntiDeboli.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Punti deboli")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)

                                    ForEach(compat.puntiDeboli, id: \.self) { punto in
                                        Label(punto, systemImage: "minus.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dettaglio Vino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Edit Dinner View

struct EditDinnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var dinner: DinnerEvent

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var guestCount: Int = 4
    @State private var occasion: String = ""
    @State private var notes: String = ""
    @State private var status: DinnerStatus = .planning

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Titolo", text: $title)
                    DatePicker("Data e ora", selection: $date)
                    Stepper("Ospiti: \(guestCount)", value: $guestCount, in: 1...20)
                    OccasionPicker(occasion: $occasion)

                    Picker("Stato", selection: $status) {
                        ForEach(DinnerStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("Note per il menu") {
                    TextField("Note speciali...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Modifica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveDinner()
                    }
                }
            }
            .onAppear {
                title = dinner.title
                date = dinner.date
                guestCount = dinner.guestCount
                occasion = dinner.occasion ?? ""
                notes = dinner.notes ?? ""
                status = dinner.status
            }
        }
    }

    private func saveDinner() {
        dinner.title = title
        dinner.date = date
        dinner.guestCount = guestCount
        dinner.occasion = occasion.isEmpty ? nil : occasion
        dinner.notes = notes.isEmpty ? nil : notes
        dinner.status = status
        dinner.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Occasion Picker

struct OccasionPicker: View {
    @Binding var occasion: String

    private let commonOccasions = [
        "Compleanno",
        "Anniversario",
        "Cena romantica",
        "Cena di lavoro",
        "Festa",
        "Cena tra amici"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Occasione", text: $occasion)

            // Quick selection chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonOccasions, id: \.self) { occ in
                        Button {
                            occasion = occ
                        } label: {
                            Text(occ)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(occasion == occ ? Color.purple : Color(.tertiarySystemBackground))
                                .foregroundColor(occasion == occ ? .white : .primary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    FoodView()
        .modelContainer(for: [DinnerEvent.self, Wine.self, Bottle.self, AppSettings.self], inMemory: true)
}
