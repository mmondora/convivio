import SwiftUI

// MARK: - Note Vini View

struct NoteViniView: View {
    let dinner: DinnerEvent
    let content: NoteViniContent
    let onRegenerate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = ["timeline", "schede"]
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Timeline Vini
                timelineSection

                // Schede Vino
                schedeVinoSection

                // Sequenza Servizio
                sequenzaSection

                // Attrezzatura
                attrezzaturaSection

                // Consigli Sommelier
                consigliSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Note Vini")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        onRegenerate()
                        dismiss()
                    } label: {
                        Label("Rigenera", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(content: DinnerNotesService.shared.exportNoteViniAsText(content, dinner: dinner))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "wineglass.fill")
                .font(.largeTitle)
                .foregroundColor(Color(hex: "722F37"))

            Text(dinner.title)
                .font(.headline)

            Text(formatDate(dinner.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        ExpandableSection(
            title: "Timeline Vini",
            icon: "clock",
            iconColor: .blue,
            isExpanded: expandedSections.contains("timeline"),
            onToggle: { toggleSection("timeline") }
        ) {
            VStack(spacing: 12) {
                ForEach(content.timelineVini.sorted(by: { $0.quandoMinuti < $1.quandoMinuti })) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(step.icona)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.quandoLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)

                            Text(step.vino)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(step.azione)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if step.id != content.timelineVini.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Schede Vino Section

    private var schedeVinoSection: some View {
        ExpandableSection(
            title: "Schede Vino",
            icon: "wineglass",
            iconColor: Color(hex: "722F37"),
            isExpanded: expandedSections.contains("schede"),
            onToggle: { toggleSection("schede") }
        ) {
            VStack(spacing: 16) {
                ForEach(content.schedeVino) { scheda in
                    WineServiceCard(scheda: scheda)
                }
            }
        }
    }

    // MARK: - Sequenza Section

    private var sequenzaSection: some View {
        ExpandableSection(
            title: "Sequenza Servizio",
            icon: "list.number",
            iconColor: .purple,
            isExpanded: expandedSections.contains("sequenza"),
            onToggle: { toggleSection("sequenza") }
        ) {
            VStack(spacing: 0) {
                ForEach(content.sequenzaServizio.sorted(by: { $0.ordine < $1.ordine })) { passo in
                    HStack(alignment: .top, spacing: 16) {
                        // Ordine number
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 32, height: 32)

                            Text("\(passo.ordine)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(passo.vino)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(passo.momento)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let transizione = passo.transizione {
                                Text("→ \(transizione)")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.purple)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if passo.ordine != content.sequenzaServizio.map({ $0.ordine }).max() {
                        // Vertical line connecting steps
                        HStack {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 2, height: 20)
                                .padding(.leading, 15)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Attrezzatura Section

    private var attrezzaturaSection: some View {
        ExpandableSection(
            title: "Attrezzatura Necessaria",
            icon: "tray.full",
            iconColor: .gray,
            isExpanded: expandedSections.contains("attrezzatura"),
            onToggle: { toggleSection("attrezzatura") }
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(content.attrezzaturaNecessaria) { item in
                    HStack(spacing: 8) {
                        Text(item.icona)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text(item.nome)
                                .font(.subheadline)

                            if let q = item.quantita {
                                Text("x\(q)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Consigli Section

    private var consigliSection: some View {
        Group {
            if !content.consigliSommelier.isEmpty {
                ExpandableSection(
                    title: "Consigli Sommelier",
                    icon: "lightbulb",
                    iconColor: .yellow,
                    isExpanded: expandedSections.contains("consigli"),
                    onToggle: { toggleSection("consigli") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(content.consigliSommelier, id: \.self) { consiglio in
                            HStack(alignment: .top, spacing: 8) {
                                Text("🍷")
                                Text(consiglio)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Wine Service Card

struct WineServiceCard: View {
    let scheda: SchedaVino

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scheda.nomeVino)
                        .font(.headline)

                    if let produttore = scheda.produttore {
                        Text(produttore)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(scheda.portataAbbinata)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            Divider()

            // Service details
            HStack(spacing: 20) {
                // Temperatura
                VStack(spacing: 4) {
                    Text("🌡️")
                        .font(.title2)
                    Text(scheda.temperaturaServizio)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Temperatura")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Bicchiere
                VStack(spacing: 4) {
                    Text("🍷")
                        .font(.title2)
                    Text(scheda.bicchiereConsigliato)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("Bicchiere")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Quantità
                VStack(spacing: 4) {
                    Text("📏")
                        .font(.title2)
                    Text(scheda.quantitaPersona)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("Per persona")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Decantazione
            if let dec = scheda.decantazione, dec.necessaria {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading) {
                        Text("Decantazione: \(dec.tempo ?? "consigliata")")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let motivo = dec.motivo {
                            Text(motivo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Come presentare
            VStack(alignment: .leading, spacing: 4) {
                Text("Come presentare:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(scheda.comePresentare)
                    .font(.subheadline)
                    .italic()
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
