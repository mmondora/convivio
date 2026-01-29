import SwiftUI
import SwiftData

// MARK: - Wine Rating View (Entry Point)

struct WineRatingView: View {
    @Environment(\.dismiss) private var dismiss

    let wine: Wine
    var existingQuickRating: QuickRating?
    var existingSchedaAIS: SchedaAIS?

    @State private var ratingMode: RatingMode = .quick

    enum RatingMode: String, CaseIterable {
        case quick = "Veloce"
        case ais = "Scheda AIS"

        var icon: String {
            switch self {
            case .quick: return "star.fill"
            case .ais: return "doc.text"
            }
        }

        var description: String {
            switch self {
            case .quick: return "Valutazione rapida stile Vivino"
            case .ais: return "Scheda degustazione professionale"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode selector
            modeSelector
                .padding()
                .background(Color(.secondarySystemBackground))

            // Content based on mode
            switch ratingMode {
            case .quick:
                QuickRatingView(wine: wine, existingRating: existingQuickRating)
            case .ais:
                SchedaAISView(wine: wine, existingScheda: existingSchedaAIS)
            }
        }
    }

    private var modeSelector: some View {
        VStack(spacing: 12) {
            Text("Modalità valutazione")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(RatingMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: ratingMode == mode
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            ratingMode = mode
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: WineRatingView.RatingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)

                Text(mode.rawValue)
                    .font(.subheadline.bold())

                Text(mode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.purple.opacity(0.15) : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .purple : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wine Rating Badge (for displaying in wine list/detail)

struct WineRatingBadge: View {
    let averageRating: Double?
    let hasAISScheda: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let rating = averageRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text(String(format: "%.1f", rating))
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }

            if hasAISScheda {
                HStack(spacing: 2) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption2)
                    Text("AIS")
                        .font(.caption2.bold())
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Wine Rating Summary Card

struct WineRatingSummaryCard: View {
    let wine: Wine
    let quickRatings: [QuickRating]
    let aisSchede: [SchedaAIS]
    let onTapQuickRating: () -> Void
    let onTapAIS: () -> Void
    let onTapHistory: () -> Void

    private var averageRating: Double? {
        guard !quickRatings.isEmpty else { return nil }
        let sum = quickRatings.reduce(0.0) { $0 + $1.rating }
        return sum / Double(quickRatings.count)
    }

    private var latestAIS: SchedaAIS? {
        aisSchede.sorted { $0.dataAssaggio > $1.dataAssaggio }.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Le mie valutazioni", systemImage: "star.fill")
                    .font(.headline)

                Spacer()

                if !quickRatings.isEmpty || !aisSchede.isEmpty {
                    Button {
                        onTapHistory()
                    } label: {
                        Text("Storico")
                            .font(.caption)
                    }
                }
            }

            // Quick rating summary
            if let avg = averageRating {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Valutazione media")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            StarRatingDisplayView(rating: avg, size: .medium, showValue: true)
                        }

                        Text("\(quickRatings.count) valutazion\(quickRatings.count == 1 ? "e" : "i")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        onTapQuickRating()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            } else {
                Button {
                    onTapQuickRating()
                } label: {
                    HStack {
                        Image(systemName: "star")
                        Text("Aggiungi valutazione veloce")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // AIS scheda summary
            if let ais = latestAIS {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ultima scheda AIS")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Text("\(ais.punteggioTotale)/100")
                                .font(.headline)
                                .foregroundColor(.purple)

                            Text(formatDate(ais.dataAssaggio))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(aisSchede.count) sched\(aisSchede.count == 1 ? "a" : "e") AIS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        onTapAIS()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            } else {
                Button {
                    onTapAIS()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Compila scheda AIS")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Wine.self, QuickRating.self, SchedaAIS.self, configurations: config)

    let wine = Wine(
        name: "Barolo Riserva",
        producer: "Giacomo Conterno",
        vintage: "2018",
        type: .red,
        region: "Piemonte",
        country: "Italia"
    )
    container.mainContext.insert(wine)

    return WineRatingView(wine: wine)
        .modelContainer(container)
}
