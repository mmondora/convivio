import SwiftUI
import SwiftData

struct EditScannedWineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let extractionResult: ExtractionResult

    // Wine fields
    @State private var name: String = ""
    @State private var producer: String = ""
    @State private var vintage: String = ""
    @State private var wineType: WineType = .red
    @State private var region: String = ""
    @State private var country: String = "Italia"
    @State private var grapes: String = ""
    @State private var alcohol: String = ""

    // Bottle fields
    @State private var quantity: Int = 1
    @State private var purchasePrice: String = ""
    @State private var location: String = ""

    // Rating fields
    @State private var addRating: Bool = false
    @State private var rating: Double = 3.0
    @State private var tastingLocation: String = ""
    @State private var tastingNotes: String = ""
    @State private var occasione: OccasioneAssaggio? = nil
    @State private var wouldBuyAgain: Bool? = nil

    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Image preview section
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .cornerRadius(8)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Wine details section
                Section("Dettagli Vino") {
                    TextField("Nome del vino", text: $name)

                    TextField("Produttore", text: $producer)

                    TextField("Annata", text: $vintage)
                        .keyboardType(.numberPad)

                    Picker("Tipo", selection: $wineType) {
                        ForEach(WineType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    TextField("Regione", text: $region)

                    TextField("Paese", text: $country)

                    TextField("Vitigni (separati da virgola)", text: $grapes)

                    TextField("Gradazione alcolica", text: $alcohol)
                        .keyboardType(.decimalPad)
                }

                // Bottle details section
                Section("Dettagli Bottiglia") {
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...99)

                    TextField("Prezzo acquisto (€)", text: $purchasePrice)
                        .keyboardType(.decimalPad)

                    TextField("Posizione in cantina", text: $location)
                }

                // Rating section
                Section {
                    Toggle("Aggiungi valutazione", isOn: $addRating)

                    if addRating {
                        VStack(alignment: .leading, spacing: 16) {
                            // Star rating
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Valutazione")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                StarRatingView(rating: $rating, size: .large)
                            }

                            Divider()

                            // Where I drank it
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dove l'ho bevuto")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextField("Es: Ristorante Da Mario, Casa, Enoteca...", text: $tastingLocation)
                            }

                            Divider()

                            // Occasion
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Occasione")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(OccasioneAssaggio.allCases, id: \.self) { occ in
                                            OccasioneChip(
                                                occasione: occ,
                                                isSelected: occasione == occ
                                            ) {
                                                occasione = occasione == occ ? nil : occ
                                            }
                                        }
                                    }
                                }
                            }

                            Divider()

                            // Would buy again
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lo ricomprerei?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 16) {
                                    BuyAgainButton(
                                        isSelected: wouldBuyAgain == true,
                                        isPositive: true
                                    ) {
                                        wouldBuyAgain = wouldBuyAgain == true ? nil : true
                                    }

                                    BuyAgainButton(
                                        isSelected: wouldBuyAgain == false,
                                        isPositive: false
                                    ) {
                                        wouldBuyAgain = wouldBuyAgain == false ? nil : false
                                    }
                                }
                            }

                            Divider()

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note di degustazione")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextField("Le tue impressioni...", text: $tastingNotes, axis: .vertical)
                                    .lineLimit(3...6)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Valutazione")
                } footer: {
                    if addRating {
                        Text("La valutazione verrà salvata insieme al vino")
                    }
                }

                // Confidence indicator
                Section {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        Text("Confidenza riconoscimento")
                        Spacer()
                        Text(String(format: "%.0f%%", extractionResult.confidence * 100))
                            .foregroundColor(extractionResult.confidence > 0.7 ? .green : .orange)
                            .fontWeight(.medium)
                    }
                }
            }
            .navigationTitle("Nuovo Vino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveWine()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                populateFromExtraction()
            }
        }
    }

    private func populateFromExtraction() {
        name = extractionResult.name ?? ""
        producer = extractionResult.producer ?? ""
        vintage = extractionResult.vintage ?? ""

        if let typeStr = extractionResult.type,
           let type = WineType(rawValue: typeStr) {
            wineType = type
        }

        region = extractionResult.region ?? ""
        country = extractionResult.country ?? "Italia"

        if let grapesArray = extractionResult.grapes {
            grapes = grapesArray.joined(separator: ", ")
        }

        if let alc = extractionResult.alcohol {
            alcohol = String(format: "%.1f", alc)
        }
    }

    private func saveWine() {
        // Parse grapes
        let grapesArray = grapes
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Parse alcohol
        let alcoholValue = Double(alcohol.replacingOccurrences(of: ",", with: "."))

        // Parse price
        let priceValue = Double(purchasePrice.replacingOccurrences(of: ",", with: "."))

        // Create wine
        let wine = Wine(
            name: name,
            producer: producer.isEmpty ? nil : producer,
            vintage: vintage.isEmpty ? nil : vintage,
            type: wineType,
            region: region.isEmpty ? nil : region,
            country: country,
            grapes: grapesArray,
            alcohol: alcoholValue
        )

        // Create bottle
        let bottle = Bottle(
            wine: wine,
            quantity: quantity,
            purchasePrice: priceValue,
            purchaseDate: Date(),
            locationZone: location.isEmpty ? nil : location
        )

        modelContext.insert(wine)
        modelContext.insert(bottle)

        // Create rating if enabled
        if addRating {
            let quickRating = QuickRating(
                wineId: wine.wineUUID ?? UUID(),
                dataAssaggio: Date(),
                rating: rating,
                note: tastingNotes.isEmpty ? nil : tastingNotes,
                occasione: occasione?.rawValue,
                luogoDegustazione: tastingLocation.isEmpty ? nil : tastingLocation,
                loRicomprerei: wouldBuyAgain
            )
            modelContext.insert(quickRating)
        }

        try? modelContext.save()
        onSave()
        dismiss()
    }
}


