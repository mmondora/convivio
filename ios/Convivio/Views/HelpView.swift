import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Come usare Convivio")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                // Cantina
                helpSection(
                    icon: "wineglass.fill",
                    color: .purple,
                    title: "Gestire la Cantina",
                    items: [
                        "Tocca + per aggiungere un nuovo vino",
                        "Scansiona l'etichetta per riconoscimento automatico",
                        "Organizza i vini per tipo, regione o posizione",
                        "Modifica quantità con swipe o tap prolungato"
                    ]
                )

                // Cene
                helpSection(
                    icon: "fork.knife",
                    color: .orange,
                    title: "Pianificare una Cena",
                    items: [
                        "Vai su Convivio e tocca + per nuova cena",
                        "Aggiungi data, ospiti e preferenze",
                        "L'AI genera automaticamente un menu con abbinamenti",
                        "Modifica piatti e vini con swipe o menu contestuale"
                    ]
                )

                // Vini
                helpSection(
                    icon: "thermometer.medium",
                    color: .blue,
                    title: "Confermare i Vini",
                    items: [
                        "Tocca 'Conferma Vini' per selezionare i vini",
                        "Imposta quantità e temperatura di servizio",
                        "Ricevi notifiche per mettere i vini in frigo",
                        "Dopo la cena, scarica le bottiglie dalla cantina"
                    ]
                )

                // Condivisione
                helpSection(
                    icon: "person.2.fill",
                    color: .green,
                    title: "Collaborare",
                    items: [
                        "Condividi la cantina con amici e familiari",
                        "Invita ospiti a proporre piatti per la cena",
                        "Vota e commenta le proposte degli altri",
                        "Gestisci i permessi per ogni partecipante"
                    ]
                )

                // Tips
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Suggerimenti")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        tipRow("Usa le note nella cena per istruzioni specifiche all'AI")
                        tipRow("La scansione funziona meglio con buona illuminazione")
                        tipRow("Configura le tue preferenze gusto per suggerimenti migliori")
                        tipRow("Abilita le notifiche per promemoria temperatura vini")
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Istruzioni")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func helpSection(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("💡")
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
