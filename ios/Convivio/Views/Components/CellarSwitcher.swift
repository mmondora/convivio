import SwiftUI
import SwiftData

// MARK: - Cellar Switcher

/// Menu for switching between cellars
struct CellarSwitcher: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var cellarManager = CellarManager.shared
    @Query(sort: \Cellar.name) private var cellars: [Cellar]

    @State private var showNewCellarDialog = false
    @State private var newCellarName = ""

    var body: some View {
        Menu {
            // List of cellars
            ForEach(cellars) { cellar in
                Button {
                    cellarManager.selectCellar(cellar)
                } label: {
                    HStack {
                        Text(cellar.name)
                        Spacer()
                        if cellar.isShared {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.secondary)
                        }
                        if cellar.id == cellarManager.selectedCellarId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }

            Divider()

            // Create new cellar
            Button {
                showNewCellarDialog = true
            } label: {
                Label("Nuova Cantina", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cellarManager.selectedCellar?.isShared == true ? "person.2.fill" : "archivebox.fill")
                    .font(.subheadline)
                Text(cellarManager.selectedCellar?.name ?? "Cantina")
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
        }
        .onAppear {
            cellarManager.loadCellars(from: modelContext)
        }
        .alert("Nuova Cantina", isPresented: $showNewCellarDialog) {
            TextField("Nome cantina", text: $newCellarName)
            Button("Annulla", role: .cancel) {
                newCellarName = ""
            }
            Button("Crea") {
                if !newCellarName.isEmpty {
                    _ = cellarManager.createCellar(name: newCellarName, in: modelContext)
                    newCellarName = ""
                }
            }
        } message: {
            Text("Inserisci un nome per la nuova cantina")
        }
    }
}

// MARK: - Cellar Switcher Button (Compact)

/// Compact version for toolbar
struct CellarSwitcherButton: View {
    @ObservedObject var cellarManager = CellarManager.shared

    var body: some View {
        Menu {
            CellarSwitcherMenu()
        } label: {
            Label(
                cellarManager.selectedCellar?.name ?? "Cantina",
                systemImage: cellarManager.selectedCellar?.isShared == true ? "person.2.fill" : "archivebox.fill"
            )
        }
    }
}

// MARK: - Cellar Switcher Menu Content

/// Menu content for cellar switching
struct CellarSwitcherMenu: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var cellarManager = CellarManager.shared
    @Query(sort: \Cellar.name) private var cellars: [Cellar]

    @State private var showNewCellarDialog = false
    @State private var newCellarName = ""

    var body: some View {
        ForEach(cellars) { cellar in
            Button {
                cellarManager.selectCellar(cellar)
            } label: {
                HStack {
                    Text(cellar.name)
                    if cellar.isShared {
                        Image(systemName: "person.2.fill")
                    }
                    if cellar.id == cellarManager.selectedCellarId {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Divider()

        Button {
            showNewCellarDialog = true
        } label: {
            Label("Nuova Cantina", systemImage: "plus")
        }
    }
}

// MARK: - Cellar Header View

/// Full header with cellar info and actions
struct CellarHeaderView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var cellarManager = CellarManager.shared

    @State private var showShareSheet = false
    @State private var showCellarSettings = false

    var body: some View {
        if let cellar = cellarManager.selectedCellar {
            HStack {
                // Cellar info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: cellar.isShared ? "person.2.fill" : "archivebox.fill")
                            .foregroundColor(.purple)
                        Text(cellar.name)
                            .font(.headline)
                    }

                    HStack(spacing: 12) {
                        Label("\(cellar.totalWines) vini", systemImage: "wineglass")
                        Label("\(cellar.totalBottles) bottiglie", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    if cellarManager.getUserRole(for: cellar) == .owner {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: cellar.isShared ? "person.badge.plus" : "square.and.arrow.up")
                        }
                    }

                    Button {
                        showCellarSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .sheet(isPresented: $showShareSheet) {
                ShareManagementView(cellar: cellar)
            }
            .sheet(isPresented: $showCellarSettings) {
                CellarSettingsView(cellar: cellar)
            }
        }
    }
}

// MARK: - Cellar Settings View

struct CellarSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cellarManager = CellarManager.shared

    let cellar: Cellar

    @State private var name: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Nome cantina", text: $name)
                }

                Section("Informazioni") {
                    LabeledContent("Vini", value: "\(cellar.totalWines)")
                    LabeledContent("Bottiglie", value: "\(cellar.totalBottles)")
                    LabeledContent("Cene", value: "\(cellar.dinners.count)")

                    if cellar.isShared {
                        LabeledContent("Stato", value: "Condivisa")
                    }
                }

                if cellarManager.getUserRole(for: cellar) == .owner {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Elimina Cantina", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni Cantina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        if !name.isEmpty && name != cellar.name {
                            cellarManager.renameCellar(cellar, to: name, in: modelContext)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = cellar.name
            }
            .alert("Elimina Cantina?", isPresented: $showDeleteConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    try? cellarManager.deleteCellar(cellar, from: modelContext)
                    dismiss()
                }
            } message: {
                Text("Tutti i vini e le cene in questa cantina verranno eliminati. Questa azione non può essere annullata.")
            }
        }
    }
}

// MARK: - Preview

#Preview("Switcher") {
    CellarSwitcher()
        .modelContainer(for: Cellar.self, inMemory: true)
}
