import SwiftUI

struct DinnerListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var showCreateDinner = false

    var body: some View {
        NavigationStack {
            List {
                // Upcoming dinners
                let upcoming = firebaseService.dinners.filter {
                    $0.date.dateValue() >= Date() && $0.status != .cancelled
                }
                if !upcoming.isEmpty {
                    Section("In Programma") {
                        ForEach(upcoming) { dinner in
                            NavigationLink {
                                DinnerDetailView(dinner: dinner)
                            } label: {
                                DinnerRow(dinner: dinner)
                            }
                        }
                    }
                }

                // Past dinners
                let past = firebaseService.dinners.filter {
                    $0.date.dateValue() < Date() || $0.status == .completed
                }
                if !past.isEmpty {
                    Section("Passate") {
                        ForEach(past) { dinner in
                            NavigationLink {
                                DinnerDetailView(dinner: dinner)
                            } label: {
                                DinnerRow(dinner: dinner)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cene")
            .overlay {
                if firebaseService.dinners.isEmpty {
                    ContentUnavailableView(
                        "Nessuna cena",
                        systemImage: "fork.knife",
                        description: Text("Pianifica la tua prima cena")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateDinner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateDinner) {
                CreateDinnerView()
            }
        }
    }
}

struct DinnerRow: View {
    let dinner: DinnerEvent

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack {
                Text(dayOfMonth)
                    .font(.title2.bold())
                Text(monthAbbreviation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(dinner.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text("\(dinner.guestCount) ospiti")
                        .font(.caption)

                    if let occasion = dinner.occasion {
                        Text("• \(occasion)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)

                if dinner.menu != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Menu generato")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            StatusBadge(status: dinner.status)
        }
        .padding(.vertical, 4)
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: dinner.date.dateValue())
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: dinner.date.dateValue()).uppercased()
    }
}

struct StatusBadge: View {
    let status: DinnerStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .planning: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
}

extension DinnerStatus {
    var displayName: String {
        switch self {
        case .planning: return "Pianificazione"
        case .confirmed: return "Confermata"
        case .completed: return "Completata"
        case .cancelled: return "Annullata"
        }
    }
}

struct CreateDinnerView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date().addingTimeInterval(86400 * 7) // Default to 1 week from now
    @State private var guestCount = 4
    @State private var occasion = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Titolo *", text: $title)
                    DatePicker("Data e ora", selection: $date)
                    Stepper("Ospiti: \(guestCount)", value: $guestCount, in: 1...50)
                }

                Section("Occasione") {
                    Picker("Tipo", selection: $occasion) {
                        Text("Seleziona...").tag("")
                        Text("Cena romantica").tag("Cena romantica")
                        Text("Compleanno").tag("Compleanno")
                        Text("Anniversario").tag("Anniversario")
                        Text("Cena di lavoro").tag("Cena di lavoro")
                        Text("Riunione amici").tag("Riunione amici")
                        Text("Festività").tag("Festività")
                        Text("Altro").tag("Altro")
                    }
                }

                Section("Note per la Pianificazione") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)

                    Text("Inserisci preferenze, allergie, requisiti specifici per il menu. Queste note avranno la massima priorità nella generazione del menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Nuova Cena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crea") {
                        Task { await createDinner() }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    LoadingOverlay(message: "Creazione cena e generazione menu...")
                }
            }
            .alert("Errore", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Errore sconosciuto")
            }
        }
    }

    private func createDinner() async {
        guard let userId = authManager.currentUser?.uid else {
            errorMessage = "Utente non autenticato"
            showError = true
            return
        }

        isLoading = true

        // Ensure cellar exists
        do {
            try await firebaseService.ensureCellarExists(for: userId)
        } catch {
            isLoading = false
            errorMessage = "Errore creazione cantina: \(error.localizedDescription)"
            showError = true
            return
        }

        let dinner = DinnerEvent(
            hostId: userId,
            cellarId: firebaseService.currentCellar?.id ?? "",
            title: title,
            date: .init(date: date),
            guestCount: guestCount,
            occasion: occasion.isEmpty ? nil : occasion,
            notes: notes.isEmpty ? nil : notes,
            status: .planning,
            createdAt: .init(date: Date()),
            updatedAt: .init(date: Date())
        )

        do {
            _ = try await firebaseService.createDinner(dinner)
            dismiss()
        } catch {
            errorMessage = "Errore creazione cena: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }
}

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

struct DinnerDetailView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var dinner: DinnerEvent
    @State private var isGeneratingMenu = false

    init(dinner: DinnerEvent) {
        _dinner = State(initialValue: dinner)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(dinner.title)
                        .font(.title.bold())

                    Text(dateFormatter.string(from: dinner.date.dateValue()))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Label("\(dinner.guestCount) ospiti", systemImage: "person.2")
                        if let occasion = dinner.occasion {
                            Text("•")
                            Text(occasion)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()

                // Notes
                if let notes = dinner.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Note di Pianificazione", systemImage: "note.text")
                            .font(.headline)

                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Menu
                if let menu = dinner.menu {
                    MenuView(menu: menu)
                } else if isGeneratingMenu {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generazione menu...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "menucard")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("Menu non ancora generato")
                            .foregroundColor(.secondary)

                        Button {
                            Task { await generateMenu() }
                        } label: {
                            Label("Genera Menu", systemImage: "wand.and.stars")
                                .padding()
                                .background(.purple.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }

                Spacer(minLength: 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generateMenu() async {
        isGeneratingMenu = true

        do {
            let menu = try await firebaseService.proposeDinnerMenu(for: dinner)
            dinner.menu = menu

            // Update in Firestore
            try await firebaseService.updateDinner(dinner)
        } catch {
            print("Error generating menu: \(error)")
        }

        isGeneratingMenu = false
    }
}

struct MenuView: View {
    let menu: MenuProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Menu Proposto")
                    .font(.headline)

                Spacer()

                if let date = menu.generatedAt {
                    Text(formatDate(date.dateValue()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Wine strategy
            if let strategy = menu.wineStrategy {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wineglass")
                        .foregroundColor(.purple)
                    Text(strategy)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Courses
            ForEach(menu.courses) { course in
                CourseCard(course: course)
            }

            // AI notes
            if let notes = menu.aiNotes {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Note del Sommelier", systemImage: "lightbulb")
                        .font(.subheadline.bold())

                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CourseCard: View {
    let course: MenuCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course header
            HStack {
                Text(course.course.icon)
                    .font(.title2)
                Text(course.course.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let prepTime = course.prepTime {
                    Label("\(prepTime) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Dish name and description
            Text(course.name)
                .font(.headline)

            Text(course.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Dietary flags
            if let flags = course.dietaryFlags, !flags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(flags, id: \.self) { flag in
                        Text(flag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }

            // Wine pairings
            if course.cellarWine != nil || course.marketWine != nil {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if let cellarWine = course.cellarWine {
                        WinePairingRow(
                            title: "Dalla Cantina",
                            icon: "house.fill",
                            color: .purple,
                            pairing: cellarWine
                        )
                    }

                    if let marketWine = course.marketWine {
                        WinePairingRow(
                            title: "Da Acquistare",
                            icon: "cart.fill",
                            color: .orange,
                            pairing: marketWine
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct WinePairingRow: View {
    let title: String
    let icon: String
    let color: Color
    let pairing: WinePairing

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(color)
            }

            Text(pairing.name)
                .font(.subheadline.bold())

            Text(pairing.reasoning)
                .font(.caption)
                .foregroundColor(.secondary)

            if let details = pairing.details {
                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(8)
        .background(color.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    DinnerListView()
        .environmentObject(AuthManager.shared)
        .environmentObject(FirebaseService.shared)
}
