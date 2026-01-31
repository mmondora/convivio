import SwiftUI

// MARK: - Note Accoglienza View

struct NoteAccoglienzaView: View {
    let dinner: DinnerEvent
    let content: NoteAccoglienzaContent
    let onRegenerate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = ["ambiente", "accoglienza"]
    @State private var checkedItems: Set<String> = []
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Preparazione Ambiente
                ambienteSection

                // Accoglienza
                accoglienzaSection

                // Gestione Serata
                gestioneSection

                // Post Cena
                postCenaSection

                // Consigli Host
                consigliSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Note Accoglienza")
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
            ShareSheetView(content: DinnerNotesService.shared.exportNoteAccoglienzaAsText(content, dinner: dinner))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundColor(.teal)

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

    // MARK: - Ambiente Section

    private var ambienteSection: some View {
        ExpandableSection(
            title: "Preparazione Ambiente",
            icon: "house",
            iconColor: .teal,
            isExpanded: expandedSections.contains("ambiente"),
            onToggle: { toggleSection("ambiente") }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                // Tavola
                VStack(alignment: .leading, spacing: 12) {
                    Label("Tavola", systemImage: "tablecells")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(content.preparazioneAmbiente.tavola.descrizione)
                        .font(.subheadline)

                    if let tov = content.preparazioneAmbiente.tavola.tovaglia {
                        detailRow("Tovaglia", tov)
                    }
                    if let tovag = content.preparazioneAmbiente.tavola.tovaglioli {
                        detailRow("Tovaglioli", tovag)
                    }
                    if let bicch = content.preparazioneAmbiente.tavola.bicchieri {
                        detailRow("Bicchieri", bicch)
                    }
                    if let centro = content.preparazioneAmbiente.tavola.centrotavola {
                        detailRow("Centrotavola", centro)
                    }
                    if let segna = content.preparazioneAmbiente.tavola.segnaposto {
                        detailRow("Segnaposto", segna)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Atmosfera
                VStack(alignment: .leading, spacing: 12) {
                    Label("Atmosfera", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let luce = content.preparazioneAmbiente.atmosfera.illuminazione {
                        detailRow("💡 Illuminazione", luce)
                    }
                    if let musica = content.preparazioneAmbiente.atmosfera.musica {
                        detailRow("🎵 Musica", musica)
                    }
                    if let profumo = content.preparazioneAmbiente.atmosfera.profumo {
                        detailRow("🌸 Profumo", profumo)
                    }
                    if let temp = content.preparazioneAmbiente.atmosfera.temperatura {
                        detailRow("🌡️ Temperatura", temp)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Checklist
                VStack(alignment: .leading, spacing: 12) {
                    Label("Checklist pre-ospiti", systemImage: "checklist")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(content.preparazioneAmbiente.checklistPreOspiti, id: \.self) { item in
                        Button {
                            toggleChecked(item)
                        } label: {
                            HStack {
                                Image(systemName: checkedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(checkedItems.contains(item) ? .green : .secondary)

                                Text(item)
                                    .strikethrough(checkedItems.contains(item))
                                    .foregroundColor(checkedItems.contains(item) ? .secondary : .primary)
                                    .font(.subheadline)

                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Accoglienza Section

    private var accoglienzaSection: some View {
        ExpandableSection(
            title: "Accoglienza",
            icon: "door.left.hand.open",
            iconColor: .green,
            isExpanded: expandedSections.contains("accoglienza"),
            onToggle: { toggleSection("accoglienza") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Info cards
                HStack(spacing: 12) {
                    InfoCard(icon: "🕐", title: "Arrivo", value: content.accoglienza.orarioArrivo)
                    InfoCard(icon: "📍", title: "Dove", value: content.accoglienza.doveRicevere)
                }

                // Aperitivo
                VStack(alignment: .leading, spacing: 8) {
                    Label("Aperitivo", systemImage: "wineglass")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text("🍸")
                        Text(content.accoglienza.aperitivo.cosa)
                            .font(.subheadline)
                    }
                    HStack {
                        Text("📍")
                        Text(content.accoglienza.aperitivo.dove)
                            .font(.subheadline)
                    }
                    HStack {
                        Text("⏱️")
                        Text(content.accoglienza.aperitivo.durata)
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Come accomodare
                VStack(alignment: .leading, spacing: 8) {
                    Label("Invitare a tavola", systemImage: "arrow.right.circle")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(content.accoglienza.comeAccomodare)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Rompighiaccio
                VStack(alignment: .leading, spacing: 8) {
                    Label("Rompighiaccio", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(content.accoglienza.rompighiaccio, id: \.self) { argomento in
                        HStack(alignment: .top) {
                            Text("💬")
                            Text(argomento)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Gestione Serata Section

    private var gestioneSection: some View {
        ExpandableSection(
            title: "Gestione Serata",
            icon: "clock.badge.checkmark",
            iconColor: .orange,
            isExpanded: expandedSections.contains("gestione"),
            onToggle: { toggleSection("gestione") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                detailRow("⏱️ Tempi portate", content.gestioneSerata.tempiPortate)
                detailRow("🍽️ Sparecchiare", content.gestioneSerata.quandoSparecchiare)

                // Consigli conversazione
                VStack(alignment: .leading, spacing: 8) {
                    Label("Argomenti conversazione", systemImage: "text.bubble")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(content.gestioneSerata.consigliConversazione, id: \.self) { arg in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(arg)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Se qualcosa va storto
                VStack(alignment: .leading, spacing: 8) {
                    Label("Se qualcosa va storto", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    ForEach(content.gestioneSerata.seQualcosaVaStorto, id: \.self) { soluzione in
                        HStack(alignment: .top) {
                            Text("🔧")
                            Text(soluzione)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Post Cena Section

    private var postCenaSection: some View {
        ExpandableSection(
            title: "Post Cena",
            icon: "cup.and.saucer",
            iconColor: .brown,
            isExpanded: expandedSections.contains("postcena"),
            onToggle: { toggleSection("postcena") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Caffè/Tè
                VStack(alignment: .leading, spacing: 8) {
                    Label("Caffè e Tè", systemImage: "cup.and.saucer.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    detailRow("Quando", content.postCena.caffeTe.quando)
                    detailRow("Come", content.postCena.caffeTe.come)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)

                // Digestivo
                if let digestivo = content.postCena.digestivo {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Digestivo", systemImage: "waterbottle")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        detailRow("Cosa", digestivo.cosa)
                        detailRow("Quando", digestivo.quando)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }

                // Intrattenimento
                if let intrattenimento = content.postCena.intrattenimento {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Intrattenimento", systemImage: "music.note")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(intrattenimento)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }

                // Congedo
                VStack(alignment: .leading, spacing: 8) {
                    Label("Congedo", systemImage: "hand.wave")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    detailRow("Segnali", content.postCena.congedo.segnali)
                    detailRow("Saluti", content.postCena.congedo.saluti)
                    if let omaggio = content.postCena.congedo.omaggio {
                        detailRow("Omaggio", omaggio)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Consigli Section

    private var consigliSection: some View {
        Group {
            if !content.consigliHost.isEmpty {
                ExpandableSection(
                    title: "Consigli Host",
                    icon: "lightbulb",
                    iconColor: .yellow,
                    isExpanded: expandedSections.contains("consigli"),
                    onToggle: { toggleSection("consigli") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(content.consigliHost, id: \.self) { consiglio in
                            HStack(alignment: .top, spacing: 8) {
                                Text("✨")
                                Text(consiglio)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
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

    private func toggleChecked(_ item: String) {
        if checkedItems.contains(item) {
            checkedItems.remove(item)
        } else {
            checkedItems.insert(item)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title2)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
