import SwiftUI

struct ReleaseNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Note di Rilascio")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                // Current version
                releaseSection(
                    version: "1.6.0",
                    date: "Gennaio 2026",
                    isCurrent: true,
                    features: [
                        "Tre bottoni note separati: Cucina, Vini, Accoglienza",
                        "Viste dedicate per ogni tipo di nota con sezioni espandibili",
                        "Notifiche temperatura vini con campanella interattiva",
                        "Timeline preparazione e servizio per ogni nota",
                        "Lista spesa con checklist interattiva",
                        "Consigli chef, sommelier e host personalizzati"
                    ],
                    fixes: [
                        "Visualizzazione note ora funziona correttamente",
                        "Risolto blocco UI su 'Genera Dettaglio Menu'",
                        "Rimossa sezione 'Note di Servizio' duplicata dai vini",
                        "Corretta visibilità bottoni per ogni stato cena",
                        "Migliorato parsing JSON delle risposte AI"
                    ]
                )

                releaseSection(
                    version: "1.5.0",
                    date: "2026",
                    features: [
                        "Gestione cantina con quantità e posizioni",
                        "Configurazione aree di stoccaggio",
                        "Sommelier AI con ricerca in cantina",
                        "Generazione menu con abbinamenti",
                        "Editing granulare piatti (rigenera/elimina singoli)",
                        "Conferma vini e notifiche temperatura servizio",
                        "Scarico bottiglie post-cena",
                        "Generazione invito cena",
                        "Note dettagliate: ricette, vini, accoglienza",
                        "Valutazione vini (quick e scheda AIS)",
                        "Sync multi-device con iCloud",
                        "Cantine collaborative",
                        "Localizzazione per lingua e cultura",
                        "Prompt AI completamente personalizzabili"
                    ]
                )

                releaseSection(
                    version: "1.0.0",
                    date: "2026",
                    features: [
                        "Prima release pubblica"
                    ]
                )
            }
            .padding()
        }
        .navigationTitle("Note di Rilascio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func releaseSection(
        version: String,
        date: String,
        isCurrent: Bool = false,
        features: [String] = [],
        fixes: [String] = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("v\(version)")
                    .font(.title2.bold())

                if isCurrent {
                    Text("CORRENTE")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Spacer()

                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Novità", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundColor(.purple)

                    ForEach(features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.purple)
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                }
            }

            if !fixes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Correzioni", systemImage: "wrench.and.screwdriver")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)

                    ForEach(fixes, id: \.self) { fix in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(fix)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ReleaseNotesView()
    }
}
