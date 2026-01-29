import SwiftUI

struct CellarView: View {
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var searchText = ""
    @State private var selectedType: WineType?
    @State private var sortBy: SortOption = .name
    @State private var showAddBottle = false

    enum SortOption: String, CaseIterable {
        case name = "Nome"
        case vintage = "Annata"
        case type = "Tipo"
        case quantity = "Quantità"
    }

    var filteredBottles: [Bottle] {
        var result = firebaseService.bottles

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { bottle in
                let wine = bottle.wine
                return wine?.name.localizedCaseInsensitiveContains(searchText) == true ||
                       wine?.producer?.localizedCaseInsensitiveContains(searchText) == true ||
                       wine?.region?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.wine?.type == type }
        }

        // Sort
        result.sort { b1, b2 in
            switch sortBy {
            case .name:
                return (b1.wine?.name ?? "") < (b2.wine?.name ?? "")
            case .vintage:
                return (b1.wine?.vintage ?? "") > (b2.wine?.vintage ?? "")
            case .type:
                return (b1.wine?.type.rawValue ?? "") < (b2.wine?.type.rawValue ?? "")
            case .quantity:
                return b1.quantity > b2.quantity
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats bar
                if let cellar = firebaseService.currentCellar {
                    CellarStatsBar(stats: cellar.stats)
                }

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Type filters
                        ForEach(WineType.allCases, id: \.self) { type in
                            FilterChip(
                                title: "\(type.icon) \(type.displayName)",
                                isSelected: selectedType == type
                            ) {
                                if selectedType == type {
                                    selectedType = nil
                                } else {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                // Wine list
                List {
                    ForEach(filteredBottles) { bottle in
                        NavigationLink {
                            BottleDetailView(bottle: bottle)
                        } label: {
                            BottleRow(bottle: bottle)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if filteredBottles.isEmpty {
                        ContentUnavailableView(
                            "Nessuna bottiglia",
                            systemImage: "wineglass",
                            description: Text("Aggiungi la tua prima bottiglia")
                        )
                    }
                }
            }
            .navigationTitle(firebaseService.currentCellar?.name ?? "Cantina")
            .searchable(text: $searchText, prompt: "Cerca vini...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortBy = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if sortBy == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBottle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBottle) {
                AddBottleView()
            }
        }
    }
}

struct CellarStatsBar: View {
    let stats: CellarStats

    var body: some View {
        HStack(spacing: 24) {
            StatItem(value: "\(stats.totalBottles)", label: "Bottiglie")
            StatItem(value: formatCurrency(stats.totalValue), label: "Valore")

            HStack(spacing: 4) {
                ForEach(WineType.allCases, id: \.self) { type in
                    if let count = stats.wineTypes[type.rawValue], count > 0 {
                        Text(type.icon)
                            .font(.caption)
                        Text("\(count)")
                            .font(.caption.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct BottleRow: View {
    let bottle: Bottle

    var body: some View {
        HStack(spacing: 12) {
            // Wine type icon
            Text(bottle.wine?.type.icon ?? "🍷")
                .font(.title)
                .frame(width: 50, height: 50)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(bottle.wine?.name ?? "Vino sconosciuto")
                    .font(.headline)

                HStack {
                    if let producer = bottle.wine?.producer {
                        Text(producer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let vintage = bottle.wine?.vintage {
                        Text("• \(vintage)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let region = bottle.wine?.region {
                    Text(region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quantity badge
            Text("\(bottle.quantity)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.purple)
                .clipShape(Circle())
        }
        .padding(.vertical, 4)
    }
}

struct BottleDetailView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    let bottle: Bottle
    @State private var showConsumeAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(bottle.wine?.type.icon ?? "🍷")
                        .font(.system(size: 80))

                    Text(bottle.wine?.name ?? "Vino")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    if let producer = bottle.wine?.producer {
                        Text(producer)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)

                // Details
                VStack(spacing: 16) {
                    DetailRow(label: "Annata", value: bottle.wine?.vintage ?? "-")
                    DetailRow(label: "Tipo", value: bottle.wine?.type.displayName ?? "-")
                    DetailRow(label: "Regione", value: bottle.wine?.region ?? "-")
                    DetailRow(label: "Paese", value: bottle.wine?.country ?? "-")

                    if let grapes = bottle.wine?.grapes, !grapes.isEmpty {
                        DetailRow(label: "Vitigni", value: grapes.joined(separator: ", "))
                    }

                    if let alcohol = bottle.wine?.alcohol {
                        DetailRow(label: "Gradazione", value: String(format: "%.1f%%", alcohol))
                    }

                    Divider()

                    DetailRow(label: "Quantità", value: "\(bottle.quantity) bottiglie")

                    if let price = bottle.purchasePrice {
                        DetailRow(label: "Prezzo acquisto", value: String(format: "€%.2f", price))
                    }

                    if let location = bottle.location {
                        if let zone = location.zone {
                            DetailRow(label: "Zona", value: zone)
                        }
                        if let rack = location.rack, let shelf = location.shelf {
                            DetailRow(label: "Posizione", value: "Scaffale \(rack), Ripiano \(shelf)")
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Tasting notes
                if let notes = bottle.wine?.tastingNotes {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Note di Degustazione")
                            .font(.headline)

                        if let appearance = notes.appearance {
                            NoteSection(title: "Aspetto", content: appearance)
                        }

                        if let nose = notes.nose, !nose.isEmpty {
                            NoteSection(title: "Profumo", content: nose.joined(separator: ", "))
                        }

                        if let palate = notes.palate, !palate.isEmpty {
                            NoteSection(title: "Gusto", content: palate.joined(separator: ", "))
                        }

                        if let finish = notes.finish {
                            NoteSection(title: "Finale", content: finish)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Actions
                Button {
                    showConsumeAlert = true
                } label: {
                    Label("Segna come bevuta", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Conferma", isPresented: $showConsumeAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Conferma", role: .destructive) {
                Task {
                    try? await firebaseService.consumeBottle(bottle)
                    dismiss()
                }
            }
        } message: {
            Text("Vuoi segnare questa bottiglia come bevuta?")
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct NoteSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(content)
        }
    }
}

struct AddBottleView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var producer = ""
    @State private var vintage = ""
    @State private var selectedType: WineType = .red
    @State private var region = ""
    @State private var country = "Italia"
    @State private var quantity = 1
    @State private var price = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Vino") {
                    TextField("Nome del vino *", text: $name)
                    TextField("Produttore", text: $producer)
                    TextField("Annata", text: $vintage)
                        .keyboardType(.numberPad)

                    Picker("Tipo", selection: $selectedType) {
                        ForEach(WineType.allCases, id: \.self) { type in
                            Text("\(type.icon) \(type.displayName)").tag(type)
                        }
                    }
                }

                Section("Origine") {
                    TextField("Regione", text: $region)
                    TextField("Paese", text: $country)
                }

                Section("Dettagli Acquisto") {
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...100)
                    TextField("Prezzo (€)", text: $price)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Aggiungi Bottiglia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task { await saveBottle() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveBottle() async {
        isLoading = true

        let wine = Wine(
            name: name,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintage.isEmpty ? nil : vintage,
            type: selectedType,
            region: region.isEmpty ? nil : region,
            country: country,
            createdAt: .init(date: Date()),
            updatedAt: .init(date: Date())
        )

        let bottle = Bottle(
            wineId: "",
            cellarId: "",
            purchaseDate: .init(date: Date()),
            purchasePrice: Double(price),
            quantity: quantity,
            status: .available,
            createdAt: .init(date: Date()),
            updatedAt: .init(date: Date())
        )

        do {
            try await firebaseService.addBottle(bottle, wine: wine)
            dismiss()
        } catch {
            print("Error saving bottle: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    CellarView()
        .environmentObject(FirebaseService.shared)
}
