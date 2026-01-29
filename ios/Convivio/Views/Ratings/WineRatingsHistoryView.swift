import SwiftUI
import SwiftData

struct WineRatingsHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let wine: Wine

    @Query private var allQuickRatings: [QuickRating]
    @Query private var allAISSchede: [SchedaAIS]

    @State private var selectedQuickRating: QuickRating?
    @State private var selectedAISScheda: SchedaAIS?
    @State private var showNewRatingSheet = false
    @State private var filterType: FilterType = .all

    enum FilterType: String, CaseIterable {
        case all = "Tutte"
        case quick = "Veloci"
        case ais = "AIS"
    }

    private var quickRatings: [QuickRating] {
        allQuickRatings.filter { $0.wineId == wine.stableUUID }
            .sorted { $0.dataAssaggio > $1.dataAssaggio }
    }

    private var aisSchede: [SchedaAIS] {
        allAISSchede.filter { $0.wineId == wine.stableUUID }
            .sorted { $0.dataAssaggio > $1.dataAssaggio }
    }

    private var filteredItems: [RatingHistoryItem] {
        var items: [RatingHistoryItem] = []

        if filterType == .all || filterType == .quick {
            items.append(contentsOf: quickRatings.map { RatingHistoryItem.quick($0) })
        }

        if filterType == .all || filterType == .ais {
            items.append(contentsOf: aisSchede.map { RatingHistoryItem.ais($0) })
        }

        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Filter
                filterPicker

                // List
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            RatingHistoryRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    switch item {
                                    case .quick(let rating):
                                        selectedQuickRating = rating
                                    case .ais(let scheda):
                                        selectedAISScheda = scheda
                                    }
                                }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Storico valutazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewRatingSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedQuickRating) { rating in
                QuickRatingView(wine: wine, existingRating: rating)
            }
            .sheet(item: $selectedAISScheda) { scheda in
                SchedaAISView(wine: wine, existingScheda: scheda)
            }
            .sheet(isPresented: $showNewRatingSheet) {
                WineRatingView(wine: wine)
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 24) {
            // Quick ratings stat
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text("\(quickRatings.count)")
                        .font(.headline)
                }
                Text("Veloci")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !quickRatings.isEmpty {
                    let avg = quickRatings.reduce(0.0) { $0 + $1.rating } / Double(quickRatings.count)
                    Text("Media: \(String(format: "%.1f", avg))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Divider()
                .frame(height: 40)

            // AIS schede stat
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.purple)
                    Text("\(aisSchede.count)")
                        .font(.headline)
                }
                Text("Schede AIS")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !aisSchede.isEmpty {
                    let avg = aisSchede.reduce(0) { $0 + $1.punteggioTotale } / aisSchede.count
                    Text("Media: \(avg)/100")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filtro", selection: $filterType) {
            ForEach(FilterType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Nessuna valutazione",
            systemImage: "star.slash",
            description: Text("Non hai ancora valutato questo vino")
        )
    }

    // MARK: - Actions

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            switch item {
            case .quick(let rating):
                modelContext.delete(rating)
            case .ais(let scheda):
                modelContext.delete(scheda)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Rating History Item

enum RatingHistoryItem: Identifiable {
    case quick(QuickRating)
    case ais(SchedaAIS)

    var id: UUID {
        switch self {
        case .quick(let rating): return rating.id
        case .ais(let scheda): return scheda.id
        }
    }

    var date: Date {
        switch self {
        case .quick(let rating): return rating.dataAssaggio
        case .ais(let scheda): return scheda.dataAssaggio
        }
    }
}

// MARK: - Rating History Row

struct RatingHistoryRow: View {
    let item: RatingHistoryItem

    var body: some View {
        switch item {
        case .quick(let rating):
            QuickRatingHistoryRow(rating: rating)
        case .ais(let scheda):
            AISSchedaHistoryRow(scheda: scheda)
        }
    }
}

struct QuickRatingHistoryRow: View {
    let rating: QuickRating

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    StarRatingDisplayView(rating: rating.rating, size: .small, showValue: true)

                    Spacer()

                    Text(formatDate(rating.dataAssaggio))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let occasione = rating.occasione {
                    Text(occasione)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let note = rating.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let loRicomprerei = rating.loRicomprerei {
                    HStack(spacing: 4) {
                        Image(systemName: loRicomprerei ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption)
                        Text(loRicomprerei ? "Lo ricomprerei" : "Non lo ricomprerei")
                            .font(.caption)
                    }
                    .foregroundColor(loRicomprerei ? .green : .red)
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

struct AISSchedaHistoryRow: View {
    let scheda: SchedaAIS

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            VStack {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("\(scheda.punteggioTotale)")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }
            .frame(width: 40, height: 40)
            .background(Color.purple.opacity(0.15))
            .cornerRadius(8)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scheda AIS")
                        .font(.subheadline.bold())

                    Spacer()

                    Text(formatDate(scheda.dataAssaggio))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Mini scores
                HStack(spacing: 12) {
                    MiniScoreView(label: "Vis", score: scheda.punteggioVisivo)
                    MiniScoreView(label: "Olf", score: scheda.punteggioOlfattivo)
                    MiniScoreView(label: "Gus", score: scheda.punteggioGustativo)
                }

                // Descriptors preview
                if !scheda.descrittoriOlfattivi.isEmpty {
                    Text(scheda.descrittoriOlfattivi.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let note = scheda.noteLibere, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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

struct MiniScoreView: View {
    let label: String
    let score: Int

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(score)")
                .font(.caption2.bold())
        }
    }
}

// MARK: - Preview

private struct WineRatingsHistoryPreview: View {
    @State private var wine: Wine?

    var body: some View {
        if let wine = wine {
            WineRatingsHistoryView(wine: wine)
        } else {
            ProgressView()
                .task {
                    wine = Wine(
                        name: "Barolo Riserva",
                        producer: "Giacomo Conterno",
                        vintage: "2018",
                        type: .red,
                        region: "Piemonte",
                        country: "Italia"
                    )
                }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Wine.self, QuickRating.self, SchedaAIS.self, configurations: config)

    WineRatingsHistoryPreview()
        .modelContainer(container)
}
