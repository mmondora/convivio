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
                    version: "1.2.0",
                    date: "Gennaio 2025",
                    isCurrent: true,
                    features: [
                        "Nuovo sistema di stati cena (planning → winesConfirmed → confirmed)",
                        "Toggle debug mode accessibile da Profilo",
                        "Migliorata sincronizzazione vini tra menu e conferma",
                        "Fix layout note servizio nella pagina Convivio"
                    ],
                    fixes: [
                        "Risolto problema sovrapposizione pannelli vini",
                        "Corretto comportamento swipe actions su menu confermato"
                    ]
                )

                releaseSection(
                    version: "1.1.0",
                    date: "Gennaio 2025",
                    features: [
                        "Layout ottimizzato per iPad",
                        "Sistema di valutazione vini con stelle",
                        "Notifiche temperatura vini",
                        "Preparazione per CloudKit sync"
                    ],
                    fixes: [
                        "Migliorata stabilità generazione menu",
                        "Fix notifiche in foreground"
                    ]
                )

                releaseSection(
                    version: "1.0.0",
                    date: "Dicembre 2024",
                    features: [
                        "Gestione cantina vini",
                        "Pianificazione cene con AI",
                        "Generazione menu con abbinamenti",
                        "Scansione etichette vino",
                        "Supporto multilingua (IT, EN, DE, FR)"
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
