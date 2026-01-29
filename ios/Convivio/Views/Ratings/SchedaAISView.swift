import SwiftUI
import SwiftData

struct SchedaAISView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let wine: Wine
    var existingScheda: SchedaAIS?

    @State private var scheda: SchedaAIS
    @State private var selectedTab = 0
    @State private var isSaving = false
    @State private var showDescriptorPicker = false

    init(wine: Wine, existingScheda: SchedaAIS? = nil) {
        self.wine = wine
        self.existingScheda = existingScheda

        if let existing = existingScheda {
            _scheda = State(initialValue: existing)
        } else {
            _scheda = State(initialValue: SchedaAIS(wineId: wine.stableUUID))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress and score header
                headerSection

                // Tab selector
                tabSelector

                // Content
                TabView(selection: $selectedTab) {
                    esameVisivoSection.tag(0)
                    esameOlfattivoSection.tag(1)
                    esameGustativoSection.tag(2)
                    valutazioneFinaleSection.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Scheda AIS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveScheda()
                    }
                    .disabled(!scheda.isComplete || isSaving)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Wine info
            HStack {
                Text(wine.type.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(wine.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let producer = wine.producer {
                        Text(producer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Score display
                VStack(spacing: 2) {
                    Text("\(scheda.punteggioTotale)")
                        .font(.title.bold())
                        .foregroundColor(scoreColor)

                    Text("/100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            AISProgressBar(
                progress: scheda.completionPercentage,
                label: "Scheda completata"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var scoreColor: Color {
        switch scheda.punteggioTotale {
        case 90...100: return .blue
        case 80..<90: return .green
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "Visivo", icon: "eye", isSelected: selectedTab == 0) {
                withAnimation { selectedTab = 0 }
            }
            TabButton(title: "Olfattivo", icon: "nose", isSelected: selectedTab == 1) {
                withAnimation { selectedTab = 1 }
            }
            TabButton(title: "Gustativo", icon: "mouth", isSelected: selectedTab == 2) {
                withAnimation { selectedTab = 2 }
            }
            TabButton(title: "Finale", icon: "checkmark.seal", isSelected: selectedTab == 3) {
                withAnimation { selectedTab = 3 }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Esame Visivo

    private var esameVisivoSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AISSectionHeader(
                    title: "Esame Visivo",
                    icon: "eye",
                    score: scheda.punteggioVisivo,
                    maxScore: 15
                )

                AISParameterPicker(
                    title: "Limpidezza",
                    selection: Binding(
                        get: { scheda.limpidezza },
                        set: { scheda.limpidezza = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                AISParameterPicker(
                    title: "Colore",
                    selection: Binding(
                        get: { scheda.colore },
                        set: { scheda.colore = $0 }
                    ),
                    showScore: false
                )

                AISParameterPicker(
                    title: "Intensità colore",
                    selection: Binding(
                        get: { scheda.intensitaColore },
                        set: { scheda.intensitaColore = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                AISParameterPicker(
                    title: "Consistenza",
                    selection: Binding(
                        get: { scheda.consistenza },
                        set: { scheda.consistenza = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                // Effervescenza (solo spumanti)
                if wine.type == .sparkling {
                    effervescenzaSection
                }

                // Navigation hint
                navigationHint(nextTab: 1, nextTitle: "Esame Olfattivo")
            }
            .padding()
        }
    }

    private var effervescenzaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Effervescenza")
                .font(.subheadline.bold())
                .foregroundColor(.purple)

            AISParameterPicker(
                title: "Grana",
                selection: Binding(
                    get: { scheda.effervescenzaGrana },
                    set: { scheda.effervescenzaGrana = $0 }
                ),
                scoreExtractor: { $0.punteggio }
            )

            AISParameterPicker(
                title: "Numero bollicine",
                selection: Binding(
                    get: { scheda.effervescenzaNumero },
                    set: { scheda.effervescenzaNumero = $0 }
                ),
                scoreExtractor: { $0.punteggio }
            )

            AISParameterPicker(
                title: "Persistenza",
                selection: Binding(
                    get: { scheda.effervescenzaPersistenza },
                    set: { scheda.effervescenzaPersistenza = $0 }
                ),
                scoreExtractor: { $0.punteggio }
            )
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Esame Olfattivo

    private var esameOlfattivoSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AISSectionHeader(
                    title: "Esame Olfattivo",
                    icon: "nose",
                    score: scheda.punteggioOlfattivo,
                    maxScore: 15
                )

                AISParameterPicker(
                    title: "Intensità",
                    selection: Binding(
                        get: { scheda.intensitaOlfattiva },
                        set: { scheda.intensitaOlfattiva = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                AISParameterPicker(
                    title: "Complessità",
                    selection: Binding(
                        get: { scheda.complessita },
                        set: { scheda.complessita = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                AISParameterPicker(
                    title: "Qualità",
                    selection: Binding(
                        get: { scheda.qualitaOlfattiva },
                        set: { scheda.qualitaOlfattiva = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                // Descrittori olfattivi
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Descrittori olfattivi")
                            .font(.subheadline.bold())

                        Spacer()

                        Button {
                            showDescriptorPicker = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }

                    if !scheda.descrittoriOlfattivi.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(scheda.descrittoriOlfattivi, id: \.self) { descriptor in
                                SelectedDescriptorChip(descriptor: descriptor) {
                                    scheda.descrittoriOlfattivi.removeAll { $0 == descriptor }
                                }
                            }
                        }
                    } else {
                        Text("Nessun descrittore selezionato")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }

                navigationHint(nextTab: 2, nextTitle: "Esame Gustativo")
            }
            .padding()
        }
        .sheet(isPresented: $showDescriptorPicker) {
            NavigationStack {
                OlfactoryDescriptorPicker(
                    selectedDescriptors: Binding(
                        get: { scheda.descrittoriOlfattivi },
                        set: { scheda.descrittoriOlfattivi = $0 }
                    )
                )
                .padding()
                .navigationTitle("Descrittori olfattivi")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fatto") {
                            showDescriptorPicker = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Esame Gustativo

    private var esameGustativoSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AISSectionHeader(
                    title: "Esame Gustativo",
                    icon: "mouth",
                    score: scheda.punteggioGustativo,
                    maxScore: 50
                )

                // Durezza
                VStack(alignment: .leading, spacing: 12) {
                    Text("Componenti dure")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    AISParameterPicker(
                        title: "Acidità",
                        selection: Binding(
                            get: { scheda.acidita },
                            set: { scheda.acidita = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    if wine.type == .red {
                        AISParameterPicker(
                            title: "Tannini",
                            selection: Binding(
                                get: { scheda.tannini },
                                set: { scheda.tannini = $0 }
                            ),
                            scoreExtractor: { $0.punteggio }
                        )
                    }

                    AISParameterPicker(
                        title: "Sapidità",
                        selection: Binding(
                            get: { scheda.sapidita },
                            set: { scheda.sapidita = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )
                }

                Divider()

                // Morbidezza
                VStack(alignment: .leading, spacing: 12) {
                    Text("Componenti morbide")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    AISParameterPicker(
                        title: "Zuccheri",
                        selection: Binding(
                            get: { scheda.zuccheri },
                            set: { scheda.zuccheri = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    AISParameterPicker(
                        title: "Alcol",
                        selection: Binding(
                            get: { scheda.alcol },
                            set: { scheda.alcol = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    AISParameterPicker(
                        title: "Polialcoli (morbidezza)",
                        selection: Binding(
                            get: { scheda.polialcoli },
                            set: { scheda.polialcoli = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )
                }

                Divider()

                // Struttura e persistenza
                VStack(alignment: .leading, spacing: 12) {
                    Text("Struttura e persistenza")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    AISParameterPicker(
                        title: "Corpo",
                        selection: Binding(
                            get: { scheda.corpo },
                            set: { scheda.corpo = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    AISParameterPicker(
                        title: "Equilibrio",
                        selection: Binding(
                            get: { scheda.equilibrio },
                            set: { scheda.equilibrio = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    AISParameterPicker(
                        title: "Intensità gustativa (PAI)",
                        selection: Binding(
                            get: { scheda.intensitaGustativa },
                            set: { scheda.intensitaGustativa = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )

                    AISParameterPicker(
                        title: "Qualità gustativa",
                        selection: Binding(
                            get: { scheda.qualitaGustativa },
                            set: { scheda.qualitaGustativa = $0 }
                        ),
                        scoreExtractor: { $0.punteggio }
                    )
                }

                navigationHint(nextTab: 3, nextTitle: "Valutazione Finale")
            }
            .padding()
        }
    }

    // MARK: - Valutazione Finale

    private var valutazioneFinaleSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AISSectionHeader(
                    title: "Valutazione Finale",
                    icon: "checkmark.seal",
                    score: scheda.punteggioFinale,
                    maxScore: 10
                )

                AISParameterPicker(
                    title: "Stato evolutivo",
                    selection: Binding(
                        get: { scheda.statoEvolutivo },
                        set: { scheda.statoEvolutivo = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                AISParameterPicker(
                    title: "Armonia",
                    selection: Binding(
                        get: { scheda.armonia },
                        set: { scheda.armonia = $0 }
                    ),
                    scoreExtractor: { $0.punteggio }
                )

                // Note libere
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note libere")
                        .font(.subheadline.bold())

                    TextField("Impressioni, abbinamenti consigliati, potenziale di invecchiamento...", text: Binding(
                        get: { scheda.noteLibere ?? "" },
                        set: { scheda.noteLibere = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(4...8)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Punteggio finale card
                VStack(spacing: 16) {
                    Text("Punteggio Totale")
                        .font(.headline)

                    AISScoreDisplay(
                        score: scheda.punteggioTotale,
                        label: ""
                    )

                    Text(scoreDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                // Save button
                Button {
                    saveScheda()
                } label: {
                    Label("Salva Scheda AIS", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(scheda.isComplete ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!scheda.isComplete || isSaving)
            }
            .padding()
        }
    }

    private var scoreDescription: String {
        switch scheda.punteggioTotale {
        case 95...100: return "Eccezionale - Vino di altissimo livello"
        case 90..<95: return "Eccellente - Vino di grande qualità"
        case 85..<90: return "Ottimo - Vino di qualità superiore"
        case 80..<85: return "Molto buono - Vino di buona qualità"
        case 75..<80: return "Buono - Vino corretto e piacevole"
        case 70..<75: return "Discreto - Vino accettabile"
        case 65..<70: return "Sufficiente - Vino con alcune carenze"
        default: return "Insufficiente - Vino con evidenti difetti"
        }
    }

    // MARK: - Navigation Hint

    private func navigationHint(nextTab: Int, nextTitle: String) -> some View {
        Button {
            withAnimation {
                selectedTab = nextTab
            }
        } label: {
            HStack {
                Text("Continua con \(nextTitle)")
                    .font(.subheadline)
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func saveScheda() {
        isSaving = true
        scheda.updatedAt = Date()

        if existingScheda == nil {
            modelContext.insert(scheda)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .purple : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Wine.self, SchedaAIS.self, configurations: config)

    let wine = Wine(
        name: "Barolo Riserva",
        producer: "Giacomo Conterno",
        vintage: "2018",
        type: .red,
        region: "Piemonte",
        country: "Italia"
    )
    container.mainContext.insert(wine)

    return SchedaAISView(wine: wine)
        .modelContainer(container)
}
