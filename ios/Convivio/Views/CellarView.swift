import SwiftUI
import SwiftData

struct CellarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bottle> { $0.statusRaw == "available" },
           sort: \Bottle.createdAt, order: .reverse)
    private var bottles: [Bottle]

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
        var result = bottles.filter { $0.quantity > 0 }

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
                return (b1.wine?.typeRaw ?? "") < (b2.wine?.typeRaw ?? "")
            case .quantity:
                return b1.quantity > b2.quantity
            }
        }

        return result
    }

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
            VStack(spacing: 0) {
                // Stats bar
                CellarStatsBar(
                    totalBottles: stats.total,
                    totalValue: stats.value,
                    wineTypes: stats.byType
                )

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                    .onDelete(perform: deleteBottles)
                }
                .listStyle(.plain)
                .overlay {
                    if filteredBottles.isEmpty {
                        ContentUnavailableView(
                            "Nessuna bottiglia",
                            systemImage: "wineglass",
                            description: Text("Aggiungi la tua prima bottiglia scansionando un'etichetta o manualmente")
                        )
                    }
                }
            }
            .navigationTitle("Cantina")
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

    private func deleteBottles(at offsets: IndexSet) {
        for index in offsets {
            let bottle = filteredBottles[index]
            modelContext.delete(bottle)
        }
        try? modelContext.save()
    }
}

struct CellarStatsBar: View {
    let totalBottles: Int
    let totalValue: Double
    let wineTypes: [WineType: Int]

    var body: some View {
        HStack(spacing: 24) {
            StatItem(value: "\(totalBottles)", label: "Bottiglie")
            StatItem(value: formatCurrency(totalValue), label: "Valore")

            HStack(spacing: 4) {
                ForEach(WineType.allCases, id: \.self) { type in
                    if let count = wineTypes[type], count > 0 {
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

                HStack(spacing: 4) {
                    if let region = bottle.wine?.region {
                        Text(region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Show rating if exists
                    if let review = bottle.review {
                        Spacer()
                        MiniStarRating(rating: review.rating)
                    }
                }
            }

            Spacer()

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

struct MiniStarRating: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct BottleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var bottle: Bottle
    @Query private var allQuickRatings: [QuickRating]
    @Query private var allAISSchede: [SchedaAIS]

    @State private var showConsumeAlert = false
    @State private var showReviewSheet = false
    @State private var showRatingSheet = false
    @State private var showHistorySheet = false
    @State private var showEditQuantity = false
    @State private var newQuantity: Int = 1

    private var quickRatings: [QuickRating] {
        guard let wine = bottle.wine else { return [] }
        return allQuickRatings.filter { $0.wineId == wine.stableUUID }
            .sorted { $0.dataAssaggio > $1.dataAssaggio }
    }

    private var aisSchede: [SchedaAIS] {
        guard let wine = bottle.wine else { return [] }
        return allAISSchede.filter { $0.wineId == wine.stableUUID }
            .sorted { $0.dataAssaggio > $1.dataAssaggio }
    }

    private var averageQuickRating: Double? {
        guard !quickRatings.isEmpty else { return nil }
        return quickRatings.reduce(0.0) { $0 + $1.rating } / Double(quickRatings.count)
    }

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

                    // Rating display - show average QuickRating if available
                    if let avgRating = averageQuickRating {
                        StarRatingDisplayView(rating: avgRating, size: .medium, showValue: true)
                            .padding(.top, 4)
                    } else if let review = bottle.review {
                        StarRatingDisplay(rating: review.rating)
                            .padding(.top, 4)
                    }

                    // AIS badge if available
                    if !aisSchede.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                            Text("Scheda AIS disponibile")
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(.top)

                // Wine Rating Card (New System)
                if let wine = bottle.wine {
                    wineRatingSection(wine: wine)
                }

                // Legacy Review/Tasting Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("La mia valutazione", systemImage: "star.fill")
                            .font(.headline)
                        Spacer()
                        Button {
                            showReviewSheet = true
                        } label: {
                            Text(bottle.review == nil ? "Valuta" : "Modifica")
                                .font(.subheadline)
                        }
                    }

                    if let review = bottle.review {
                        ReviewSummaryView(review: review)
                    } else {
                        Text("Non hai ancora valutato questo vino")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)

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

                    // Editable quantity
                    HStack {
                        Text("Quantità")
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper("\(bottle.quantity) bottiglie", value: $bottle.quantity, in: 0...100)
                            .onChange(of: bottle.quantity) {
                                bottle.updatedAt = Date()
                                try? modelContext.save()
                            }
                    }

                    if let price = bottle.purchasePrice {
                        DetailRow(label: "Prezzo acquisto", value: String(format: "€%.2f", price))
                    }

                    if let location = bottle.location {
                        DetailRow(label: "Posizione", value: location)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Description
                if let description = bottle.wine?.wineDescription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrizione")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            Button("Conferma") {
                consumeBottle()
            }
        } message: {
            Text("Vuoi segnare questa bottiglia come bevuta?")
        }
        .sheet(isPresented: $showReviewSheet) {
            WineReviewView(bottle: bottle)
        }
        .sheet(isPresented: $showRatingSheet) {
            if let wine = bottle.wine {
                WineRatingView(wine: wine)
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            if let wine = bottle.wine {
                WineRatingsHistoryView(wine: wine)
            }
        }
    }

    // MARK: - Wine Rating Section

    @ViewBuilder
    private func wineRatingSection(wine: Wine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Valutazioni vino", systemImage: "star.fill")
                    .font(.headline)

                Spacer()

                if !quickRatings.isEmpty || !aisSchede.isEmpty {
                    Button {
                        showHistorySheet = true
                    } label: {
                        Text("Storico")
                            .font(.caption)
                    }
                }
            }

            // Quick Ratings Summary
            if let avg = averageQuickRating {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Valutazione media")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        StarRatingDisplayView(rating: avg, size: .small, showValue: true)

                        Text("\(quickRatings.count) valutazion\(quickRatings.count == 1 ? "e" : "i")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // AIS Scheda Summary
            if let latestAIS = aisSchede.first {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ultima scheda AIS")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Text("\(latestAIS.punteggioTotale)/100")
                                .font(.headline)
                                .foregroundColor(.purple)
                        }

                        Text("\(aisSchede.count) sched\(aisSchede.count == 1 ? "a" : "e") AIS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }

            // Add Rating Button
            Button {
                showRatingSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Aggiungi valutazione")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func consumeBottle() {
        if bottle.quantity > 1 {
            bottle.quantity -= 1
        } else {
            bottle.status = .consumed
            bottle.quantity = 0
        }
        bottle.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Star Rating Display

struct StarRatingDisplay: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starType(for: index))
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            Text(String(format: "%.1f", rating))
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Review Summary View

struct ReviewSummaryView: View {
    let review: WineReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tastingDate = review.tastingDate {
                Text("Assaggiato il \(formatDate(tastingDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = review.overallNotes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .lineLimit(3)
            }

            // Quick characteristics
            HStack(spacing: 12) {
                if let body = review.body {
                    CharacteristicTag(label: body.rawValue)
                }
                if let tannins = review.tannins {
                    CharacteristicTag(label: "Tannini: \(tannins.rawValue)")
                }
                if let finish = review.finish {
                    CharacteristicTag(label: "Finale: \(finish.rawValue)")
                }
            }

            if let wouldBuy = review.wouldBuyAgain {
                HStack {
                    Image(systemName: wouldBuy ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .foregroundColor(wouldBuy ? .green : .red)
                    Text(wouldBuy ? "Lo ricomprerei" : "Non lo ricomprerei")
                        .font(.caption)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

struct CharacteristicTag: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .foregroundColor(.purple)
            .cornerRadius(8)
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

struct AddBottleView: View {
    @Environment(\.modelContext) private var modelContext
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
                        saveBottle()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }

    private func saveBottle() {
        isLoading = true

        let wine = Wine(
            name: name,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintage.isEmpty ? nil : vintage,
            type: selectedType,
            region: region.isEmpty ? nil : region,
            country: country
        )

        let bottle = Bottle(
            wine: wine,
            quantity: quantity,
            purchasePrice: Double(price),
            purchaseDate: Date()
        )

        modelContext.insert(wine)
        modelContext.insert(bottle)
        try? modelContext.save()

        dismiss()
    }
}

// MARK: - Wine Review View

struct WineReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var bottle: Bottle

    @State private var rating: Double = 3.0
    @State private var tastingDate: Date = Date()
    @State private var overallNotes: String = ""

    // Visual
    @State private var colorIntensity: ColorIntensity?
    @State private var colorNotes: String = ""

    // Nose
    @State private var aromaIntensity: AromaIntensity?
    @State private var selectedAromas: Set<String> = []
    @State private var aromaComplexity: Complexity?
    @State private var aromaNotes: String = ""

    // Palate
    @State private var bodyLevel: BodyLevel?
    @State private var tannins: TanninLevel?
    @State private var acidity: AcidityLevel?
    @State private var sweetness: SweetnessLevel?
    @State private var alcohol: AlcoholLevel?
    @State private var finish: FinishLength?
    @State private var tasteNotes: String = ""

    // Overall
    @State private var wouldBuyAgain: Bool? = nil
    @State private var priceQualityRating: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Rating Section
                Section("Valutazione") {
                    VStack(spacing: 16) {
                        Text(bottle.wine?.name ?? "Vino")
                            .font(.headline)

                        // Star rating
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        if rating == Double(index) && rating > Double(index) - 0.5 {
                                            rating = Double(index) - 0.5
                                        } else {
                                            rating = Double(index)
                                        }
                                    }
                                } label: {
                                    Image(systemName: starType(for: index))
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        Text(ratingDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)

                    DatePicker("Data assaggio", selection: $tastingDate, displayedComponents: .date)
                }

                // Visual Section
                Section("Aspetto visivo") {
                    Picker("Intensità colore", selection: $colorIntensity) {
                        Text("Non specificato").tag(nil as ColorIntensity?)
                        ForEach(ColorIntensity.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as ColorIntensity?)
                        }
                    }

                    TextField("Note sul colore", text: $colorNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Nose Section
                Section("Naso (Aromi)") {
                    Picker("Intensità aromatica", selection: $aromaIntensity) {
                        Text("Non specificato").tag(nil as AromaIntensity?)
                        ForEach(AromaIntensity.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as AromaIntensity?)
                        }
                    }

                    Picker("Complessità", selection: $aromaComplexity) {
                        Text("Non specificato").tag(nil as Complexity?)
                        ForEach(Complexity.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as Complexity?)
                        }
                    }

                    NavigationLink {
                        AromaPickerView(selectedAromas: $selectedAromas)
                    } label: {
                        HStack {
                            Text("Aromi percepiti")
                            Spacer()
                            Text("\(selectedAromas.count) selezionati")
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("Note aromatiche", text: $aromaNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Palate Section
                Section("Palato (Gusto)") {
                    Picker("Corpo", selection: $bodyLevel) {
                        Text("Non specificato").tag(nil as BodyLevel?)
                        ForEach(BodyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as BodyLevel?)
                        }
                    }

                    Picker("Tannini", selection: $tannins) {
                        Text("Non specificato").tag(nil as TanninLevel?)
                        ForEach(TanninLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as TanninLevel?)
                        }
                    }

                    Picker("Acidità", selection: $acidity) {
                        Text("Non specificato").tag(nil as AcidityLevel?)
                        ForEach(AcidityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as AcidityLevel?)
                        }
                    }

                    Picker("Dolcezza", selection: $sweetness) {
                        Text("Non specificato").tag(nil as SweetnessLevel?)
                        ForEach(SweetnessLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as SweetnessLevel?)
                        }
                    }

                    Picker("Alcol", selection: $alcohol) {
                        Text("Non specificato").tag(nil as AlcoholLevel?)
                        ForEach(AlcoholLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as AlcoholLevel?)
                        }
                    }

                    Picker("Finale", selection: $finish) {
                        Text("Non specificato").tag(nil as FinishLength?)
                        ForEach(FinishLength.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as FinishLength?)
                        }
                    }

                    TextField("Note di gusto", text: $tasteNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Overall Section
                Section("Impressioni generali") {
                    TextField("Note generali sul vino...", text: $overallNotes, axis: .vertical)
                        .lineLimit(3...6)

                    // Would buy again
                    HStack {
                        Text("Lo ricomprerei?")
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                wouldBuyAgain = true
                            } label: {
                                Image(systemName: wouldBuyAgain == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .foregroundColor(wouldBuyAgain == true ? .green : .gray)
                                    .font(.title2)
                            }

                            Button {
                                wouldBuyAgain = false
                            } label: {
                                Image(systemName: wouldBuyAgain == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .foregroundColor(wouldBuyAgain == false ? .red : .gray)
                                    .font(.title2)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Price/Quality
                    HStack {
                        Text("Rapporto qualità/prezzo")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { index in
                                Button {
                                    priceQualityRating = index
                                } label: {
                                    Image(systemName: (priceQualityRating ?? 0) >= index ? "eurosign.circle.fill" : "eurosign.circle")
                                        .foregroundColor((priceQualityRating ?? 0) >= index ? .green : .gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Valutazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveReview()
                    }
                }
            }
            .onAppear {
                loadExistingReview()
            }
        }
    }

    private var ratingDescription: String {
        switch rating {
        case 0..<1: return "Non valutato"
        case 1..<2: return "Scarso"
        case 2..<3: return "Mediocre"
        case 3..<4: return "Buono"
        case 4..<4.5: return "Ottimo"
        case 4.5...5: return "Eccezionale"
        default: return ""
        }
    }

    private func starType(for index: Int) -> String {
        let value = Double(index)
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private func loadExistingReview() {
        guard let review = bottle.review else { return }

        rating = review.rating
        tastingDate = review.tastingDate ?? Date()
        colorIntensity = review.colorIntensity
        colorNotes = review.colorNotes ?? ""
        aromaIntensity = review.aromaIntensity
        selectedAromas = Set(review.aromas)
        aromaComplexity = review.aromaComplexity
        aromaNotes = review.aromaNotes ?? ""
        bodyLevel = review.body
        tannins = review.tannins
        acidity = review.acidity
        sweetness = review.sweetness
        alcohol = review.alcohol
        finish = review.finish
        tasteNotes = review.tasteNotes ?? ""
        overallNotes = review.overallNotes ?? ""
        wouldBuyAgain = review.wouldBuyAgain
        priceQualityRating = review.priceQualityRating
    }

    private func saveReview() {
        let review = WineReview(
            rating: rating,
            tastingDate: tastingDate,
            colorIntensity: colorIntensity,
            colorNotes: colorNotes.isEmpty ? nil : colorNotes,
            aromaIntensity: aromaIntensity,
            aromas: Array(selectedAromas),
            aromaComplexity: aromaComplexity,
            aromaNotes: aromaNotes.isEmpty ? nil : aromaNotes,
            body: bodyLevel,
            tannins: tannins,
            acidity: acidity,
            sweetness: sweetness,
            alcohol: alcohol,
            finish: finish,
            tasteNotes: tasteNotes.isEmpty ? nil : tasteNotes,
            overallNotes: overallNotes.isEmpty ? nil : overallNotes,
            foodPairings: [],
            wouldBuyAgain: wouldBuyAgain,
            priceQualityRating: priceQualityRating
        )

        bottle.review = review
        bottle.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Aroma Picker View

struct AromaPickerView: View {
    @Binding var selectedAromas: Set<String>

    var body: some View {
        List {
            ForEach(Array(WineAromas.all.keys.sorted()), id: \.self) { category in
                Section(category) {
                    ForEach(WineAromas.all[category] ?? [], id: \.self) { aroma in
                        Button {
                            if selectedAromas.contains(aroma) {
                                selectedAromas.remove(aroma)
                            } else {
                                selectedAromas.insert(aroma)
                            }
                        } label: {
                            HStack {
                                Text(aroma)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedAromas.contains(aroma) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Seleziona Aromi")
    }
}

#Preview {
    CellarView()
        .modelContainer(for: [Wine.self, Bottle.self], inMemory: true)
}
