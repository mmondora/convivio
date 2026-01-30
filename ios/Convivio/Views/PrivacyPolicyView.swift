import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())

                    Text("Ultimo aggiornamento: Gennaio 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                Group {
                    sectionTitle("Raccolta dei Dati")
                    Text("""
                    Convivio raccoglie e memorizza localmente sul tuo dispositivo:
                    • Informazioni sui vini nella tua cantina
                    • Cene ed eventi pianificati
                    • Preferenze di gusto e impostazioni
                    """)

                    sectionTitle("Utilizzo dei Dati")
                    Text("""
                    I tuoi dati vengono utilizzati esclusivamente per:
                    • Generare menu personalizzati con abbinamenti vino
                    • Sincronizzare i dati tra i tuoi dispositivi (se iCloud è abilitato)
                    • Migliorare la tua esperienza nell'app
                    """)

                    sectionTitle("Servizi di Terze Parti")
                    Text("""
                    Convivio utilizza i seguenti servizi esterni:
                    • OpenAI API: per la generazione di menu e suggerimenti
                    • Apple iCloud: per la sincronizzazione dei dati (opzionale)

                    Le chiamate API includono solo i dati necessari per generare i suggerimenti e non vengono memorizzate permanentemente sui server esterni.
                    """)

                    sectionTitle("Sicurezza")
                    Text("""
                    • I tuoi dati sono memorizzati in modo sicuro sul dispositivo
                    • Le chiavi API sono salvate nel Keychain di iOS
                    • Le comunicazioni con i servizi esterni sono crittografate
                    """)

                    sectionTitle("I Tuoi Diritti")
                    Text("""
                    Hai il pieno controllo sui tuoi dati:
                    • Puoi cancellare tutti i dati dall'app in qualsiasi momento
                    • Puoi disabilitare la sincronizzazione iCloud
                    • Puoi rimuovere l'app per eliminare tutti i dati locali
                    """)
                }

                Divider()

                Text("Per domande sulla privacy, contattaci all'indirizzo: support@convivio.app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
