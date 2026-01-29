import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var showCellarPicker = false
    @State private var isLoadingSamples = false
    @State private var sampleLoadResult: String?
    @State private var showSampleResult = false

    var body: some View {
        NavigationStack {
            List {
                // User info
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("La mia cantina")
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Cellar selection
                Section("Cantina") {
                    if let cellar = firebaseService.currentCellar {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(cellar.name)
                                    .font(.headline)
                                Text("\(cellar.stats.totalBottles) bottiglie")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if firebaseService.cellars.count > 1 {
                                Button {
                                    showCellarPicker = true
                                } label: {
                                    Text("Cambia")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }

                // Stats
                Section("Statistiche") {
                    if let cellar = firebaseService.currentCellar {
                        StatRow(
                            icon: "wineglass",
                            label: "Bottiglie totali",
                            value: "\(cellar.stats.totalBottles)"
                        )

                        StatRow(
                            icon: "eurosign.circle",
                            label: "Valore stimato",
                            value: formatCurrency(cellar.stats.totalValue)
                        )

                        HStack {
                            Image(systemName: "chart.pie")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Per tipo")
                                    .font(.subheadline)

                                HStack(spacing: 8) {
                                    ForEach(WineType.allCases, id: \.self) { type in
                                        if let count = cellar.stats.wineTypes[type.rawValue], count > 0 {
                                            HStack(spacing: 2) {
                                                Text(type.icon)
                                                    .font(.caption)
                                                Text("\(count)")
                                                    .font(.caption.bold())
                                            }
                                        }
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // App info
                Section("Informazioni") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.1")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://convivio.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://convivio.app/terms")!) {
                        HStack {
                            Text("Termini di Servizio")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Dev section
                #if DEBUG
                Section("Dev") {
                    Button {
                        Task { await loadSampleWines() }
                    } label: {
                        HStack {
                            Image(systemName: "flask")
                            Text("Carica 3 vini di esempio")
                            Spacer()
                            if isLoadingSamples {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingSamples)
                }
                #endif

            }
            .navigationTitle("Profilo")
            .sheet(isPresented: $showCellarPicker) {
                CellarPickerView()
            }
            .alert("Vini di esempio", isPresented: $showSampleResult) {
                Button("OK") {}
            } message: {
                Text(sampleLoadResult ?? "")
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }

    private func loadSampleWines() async {
        guard let userId = authManager.currentUser?.uid else {
            sampleLoadResult = "Errore: utente non autenticato"
            showSampleResult = true
            return
        }

        isLoadingSamples = true

        // Ensure cellar exists
        do {
            try await firebaseService.ensureCellarExists(for: userId)
        } catch {
            isLoadingSamples = false
            sampleLoadResult = "Errore creazione cantina: \(error.localizedDescription)"
            showSampleResult = true
            return
        }

        let sampleWines: [(Wine, Bottle)] = [
            (
                Wine(
                    name: "Barolo Monfortino Riserva",
                    producer: "Giacomo Conterno",
                    vintage: "2015",
                    type: .red,
                    region: "Piemonte",
                    country: "Italia",
                    grapes: ["Nebbiolo"],
                    alcohol: 14.5,
                    description: "Grande Barolo di Serralunga, strutturato e longevo",
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                ),
                Bottle(
                    wineId: "",
                    cellarId: "",
                    purchasePrice: 350,
                    quantity: 2,
                    status: .available,
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                )
            ),
            (
                Wine(
                    name: "Tignanello",
                    producer: "Antinori",
                    vintage: "2019",
                    type: .red,
                    region: "Toscana",
                    country: "Italia",
                    grapes: ["Sangiovese", "Cabernet Sauvignon", "Cabernet Franc"],
                    alcohol: 14.0,
                    description: "Supertuscan iconico, blend elegante",
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                ),
                Bottle(
                    wineId: "",
                    cellarId: "",
                    purchasePrice: 120,
                    quantity: 3,
                    status: .available,
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                )
            ),
            (
                Wine(
                    name: "Franciacorta Satèn",
                    producer: "Ca' del Bosco",
                    vintage: "2018",
                    type: .sparkling,
                    region: "Lombardia",
                    country: "Italia",
                    grapes: ["Chardonnay"],
                    alcohol: 12.5,
                    description: "Bollicine eleganti, cremoso e raffinato",
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                ),
                Bottle(
                    wineId: "",
                    cellarId: "",
                    purchasePrice: 45,
                    quantity: 4,
                    status: .available,
                    createdAt: .init(date: Date()),
                    updatedAt: .init(date: Date())
                )
            )
        ]

        var addedCount = 0
        var errors: [String] = []

        for (wine, bottle) in sampleWines {
            do {
                try await firebaseService.addBottle(bottle, wine: wine)
                addedCount += 1
            } catch {
                errors.append("\(wine.name): \(error.localizedDescription)")
            }
        }

        isLoadingSamples = false

        if errors.isEmpty {
            sampleLoadResult = "Aggiunti \(addedCount) vini alla cantina!"
        } else {
            sampleLoadResult = "Aggiunti \(addedCount)/3 vini.\nErrori: \(errors.joined(separator: ", "))"
        }
        showSampleResult = true
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 30)

            Text(label)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct CellarPickerView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(firebaseService.cellars) { cellar in
                    Button {
                        if let userId = authManager.currentUser?.uid {
                            firebaseService.selectCellar(cellar, userId: userId)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(cellar.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("\(cellar.stats.totalBottles) bottiglie")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if cellar.id == firebaseService.currentCellar?.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Seleziona Cantina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(FirebaseService.shared)
}
