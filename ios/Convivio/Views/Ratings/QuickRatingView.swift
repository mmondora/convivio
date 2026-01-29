import SwiftUI
import SwiftData

struct QuickRatingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let wine: Wine
    var existingRating: QuickRating?

    @State private var rating: Double = 3.0
    @State private var note: String = ""
    @State private var occasione: OccasioneAssaggio?
    @State private var loRicomprerei: Bool?
    @State private var dataAssaggio: Date = Date()
    @State private var isSaving = false

    init(wine: Wine, existingRating: QuickRating? = nil) {
        self.wine = wine
        self.existingRating = existingRating

        if let existing = existingRating {
            _rating = State(initialValue: existing.rating)
            _note = State(initialValue: existing.note ?? "")
            _occasione = State(initialValue: existing.occasione.flatMap { OccasioneAssaggio(rawValue: $0) })
            _loRicomprerei = State(initialValue: existing.loRicomprerei)
            _dataAssaggio = State(initialValue: existing.dataAssaggio)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Wine Header
                    wineHeader

                    // Star Rating
                    ratingSection

                    // Occasion
                    occasionSection

                    // Would buy again
                    buyAgainSection

                    // Notes
                    notesSection

                    // Date
                    dateSection
                }
                .padding()
            }
            .navigationTitle(existingRating == nil ? "Valuta vino" : "Modifica valutazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveRating()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Wine Header

    private var wineHeader: some View {
        VStack(spacing: 8) {
            Text(wine.type.icon)
                .font(.system(size: 60))

            Text(wine.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let producer = wine.producer {
                    Text(producer)
                        .foregroundColor(.secondary)
                }

                if let vintage = wine.vintage {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(vintage)
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: 16) {
            StarRatingView(
                rating: $rating,
                size: .extraLarge,
                allowHalfStars: true
            )

            Text(rating.ratingDescription)
                .font(.headline)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: rating)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Occasion Section

    private var occasionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occasione")
                .font(.subheadline.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OccasioneAssaggio.allCases) { occ in
                        OccasioneChip(
                            occasione: occ,
                            isSelected: occasione == occ
                        ) {
                            withAnimation {
                                if occasione == occ {
                                    occasione = nil
                                } else {
                                    occasione = occ
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Buy Again Section

    private var buyAgainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lo ricompreresti?")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                BuyAgainButton(
                    isSelected: loRicomprerei == true,
                    isPositive: true
                ) {
                    withAnimation {
                        loRicomprerei = loRicomprerei == true ? nil : true
                    }
                }

                BuyAgainButton(
                    isSelected: loRicomprerei == false,
                    isPositive: false
                ) {
                    withAnimation {
                        loRicomprerei = loRicomprerei == false ? nil : false
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (opzionale)")
                .font(.subheadline.bold())

            TextField("Le tue impressioni su questo vino...", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data assaggio")
                .font(.subheadline.bold())

            DatePicker(
                "",
                selection: $dataAssaggio,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func saveRating() {
        isSaving = true

        if let existing = existingRating {
            // Update existing
            existing.rating = rating
            existing.note = note.isEmpty ? nil : note
            existing.occasione = occasione?.rawValue
            existing.loRicomprerei = loRicomprerei
            existing.dataAssaggio = dataAssaggio
            existing.updatedAt = Date()
        } else {
            // Create new
            let newRating = QuickRating(
                wineId: wine.stableUUID,
                dataAssaggio: dataAssaggio,
                rating: rating,
                note: note.isEmpty ? nil : note,
                occasione: occasione?.rawValue,
                loRicomprerei: loRicomprerei
            )
            modelContext.insert(newRating)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Occasione Chip

struct OccasioneChip: View {
    let occasione: OccasioneAssaggio
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: occasione.icon)
                    .font(.caption)
                Text(occasione.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.2) : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .purple : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Buy Again Button

struct BuyAgainButton: View {
    let isSelected: Bool
    let isPositive: Bool
    let action: () -> Void

    private var icon: String {
        if isPositive {
            return isSelected ? "hand.thumbsup.fill" : "hand.thumbsup"
        } else {
            return isSelected ? "hand.thumbsdown.fill" : "hand.thumbsdown"
        }
    }

    private var color: Color {
        isPositive ? .green : .red
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(isPositive ? "Sì" : "No")
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Wine.self, QuickRating.self, configurations: config)

    let wine = Wine(
        name: "Barolo Riserva",
        producer: "Giacomo Conterno",
        vintage: "2018",
        type: .red,
        region: "Piemonte",
        country: "Italia"
    )
    container.mainContext.insert(wine)

    return QuickRatingView(wine: wine)
        .modelContainer(container)
}
