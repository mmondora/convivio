import SwiftUI
import SwiftData

// MARK: - Storage Configuration View

struct StorageConfigurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageArea.sortOrder) private var areas: [StorageArea]

    @State private var showAddArea = false
    @State private var editingArea: StorageArea?
    @State private var showDeleteConfirmation = false
    @State private var areaToDelete: StorageArea?

    var body: some View {
        List {
            if areas.isEmpty {
                ContentUnavailableView(
                    "Nessuna area configurata",
                    systemImage: "archivebox",
                    description: Text("Aggiungi aree di stoccaggio come Cantina, Cucina, ecc.")
                )
            } else {
                ForEach(areas) { area in
                    Section {
                        // Area header
                        AreaHeaderRow(area: area) {
                            editingArea = area
                        }

                        // Containers in this area
                        if let containers = area.containers, !containers.isEmpty {
                            ForEach(containers.sorted(by: { $0.sortOrder < $1.sortOrder })) { container in
                                NavigationLink {
                                    EditContainerView(container: container)
                                } label: {
                                    ContainerRow(container: container)
                                }
                            }
                            .onDelete { indexSet in
                                deleteContainers(from: area, at: indexSet)
                            }
                        }

                        // Add container button
                        NavigationLink {
                            AddContainerView(area: area)
                        } label: {
                            Label("Aggiungi contenitore", systemImage: "plus.circle")
                                .foregroundColor(.purple)
                        }
                    }
                }
                .onDelete(perform: deleteAreas)
            }
        }
        .navigationTitle("Aree di Stoccaggio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddArea = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddArea) {
            AddAreaView()
        }
        .sheet(item: $editingArea) { area in
            EditAreaView(area: area)
        }
        .alert("Elimina Area", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                if let area = areaToDelete {
                    deleteArea(area)
                }
            }
        } message: {
            Text("I vini in questa area perderanno la loro posizione ma non verranno eliminati.")
        }
    }

    private func deleteAreas(at offsets: IndexSet) {
        for index in offsets {
            let area = areas[index]
            // Clear container references from bottles before deleting
            if let containers = area.containers {
                for container in containers {
                    clearBottleReferences(from: container)
                }
            }
            modelContext.delete(area)
        }
        try? modelContext.save()
    }

    private func deleteArea(_ area: StorageArea) {
        if let containers = area.containers {
            for container in containers {
                clearBottleReferences(from: container)
            }
        }
        modelContext.delete(area)
        try? modelContext.save()
    }

    private func deleteContainers(from area: StorageArea, at offsets: IndexSet) {
        guard let containers = area.containers?.sorted(by: { $0.sortOrder < $1.sortOrder }) else { return }
        for index in offsets {
            let container = containers[index]
            clearBottleReferences(from: container)
            modelContext.delete(container)
        }
        try? modelContext.save()
    }

    private func clearBottleReferences(from container: StorageContainer) {
        if let bottles = container.bottles {
            for bottle in bottles {
                bottle.storageContainer = nil
                bottle.positionInContainer = nil
            }
        }
    }
}

// MARK: - Area Header Row

struct AreaHeaderRow: View {
    let area: StorageArea
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(area.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(area.containerCount) contenitori", systemImage: "archivebox")
                    Label("\(area.totalBottles) bottiglie", systemImage: "wineglass")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Container Row

struct ContainerRow: View {
    let container: StorageContainer

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    if let usage = container.capacityUsage {
                        Label(usage, systemImage: "cube.box")
                            .foregroundColor(container.isNearCapacity ? .orange : .secondary)
                    } else {
                        Label("\(container.currentBottleCount) bottiglie", systemImage: "wineglass")
                            .foregroundColor(.secondary)
                    }

                    if let notes = container.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Area View

struct AddAreaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageArea.sortOrder) private var existingAreas: [StorageArea]

    @State private var name = ""

    private let suggestedAreas = ["Cantina", "Cucina", "Sala", "Garage", "Taverna", "Dispensa"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome area") {
                    TextField("Es: Cantina, Cucina...", text: $name)
                }

                Section("Suggerimenti") {
                    let availableSuggestions = suggestedAreas.filter { suggestion in
                        !existingAreas.contains { $0.name.lowercased() == suggestion.lowercased() }
                    }

                    if availableSuggestions.isEmpty {
                        Text("Tutte le aree suggerite sono già state create")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableSuggestions, id: \.self) { suggestion in
                                    Button {
                                        name = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(name == suggestion ? Color.purple : Color(.tertiarySystemBackground))
                                            .foregroundColor(name == suggestion ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuova Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") {
                        addArea()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addArea() {
        let nextOrder = (existingAreas.map(\.sortOrder).max() ?? -1) + 1
        let area = StorageArea(name: name, sortOrder: nextOrder)
        modelContext.insert(area)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Area View

struct EditAreaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var area: StorageArea
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome area") {
                    TextField("Nome", text: $name)
                }

                Section {
                    HStack {
                        Text("Contenitori")
                        Spacer()
                        Text("\(area.containerCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Bottiglie totali")
                        Spacer()
                        Text("\(area.totalBottles)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Modifica Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        area.name = name
                        area.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = area.name
            }
        }
    }
}

// MARK: - Add Container View

struct AddContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let area: StorageArea

    @State private var name = ""
    @State private var capacity: String = ""
    @State private var notes = ""

    private let suggestedContainers = [
        "Cantinetta",
        "Armadio vini",
        "Frigo vini",
        "Scaffale",
        "Credenza",
        "Rack a parete"
    ]

    var body: some View {
        Form {
            Section("Nome contenitore") {
                TextField("Es: Cantinetta Eurocave...", text: $name)
            }

            Section("Suggerimenti") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedContainers, id: \.self) { suggestion in
                            Button {
                                name = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(name == suggestion ? Color.purple : Color(.tertiarySystemBackground))
                                    .foregroundColor(name == suggestion ? .white : .primary)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Capacità (opzionale)") {
                TextField("Numero bottiglie", text: $capacity)
                    .keyboardType(.numberPad)
            }

            Section("Note (opzionale)") {
                TextField("Es: temperatura 14°C", text: $notes)
            }
        }
        .navigationTitle("Nuovo Contenitore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Aggiungi") {
                    addContainer()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func addContainer() {
        let nextOrder = (area.containers?.map(\.sortOrder).max() ?? -1) + 1
        let container = StorageContainer(
            name: name,
            capacity: Int(capacity),
            notes: notes.isEmpty ? nil : notes,
            sortOrder: nextOrder
        )
        container.area = area
        modelContext.insert(container)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Container View

struct EditContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var container: StorageContainer

    @State private var name = ""
    @State private var capacity = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Nome contenitore") {
                TextField("Nome", text: $name)
            }

            Section("Capacità (opzionale)") {
                TextField("Numero bottiglie", text: $capacity)
                    .keyboardType(.numberPad)
            }

            Section("Note (opzionale)") {
                TextField("Es: temperatura 14°C", text: $notes)
            }

            Section {
                HStack {
                    Text("Bottiglie presenti")
                    Spacer()
                    Text("\(container.currentBottleCount)")
                        .foregroundColor(.secondary)
                }

                if let cap = container.capacity {
                    HStack {
                        Text("Utilizzo")
                        Spacer()
                        Text("\(container.currentBottleCount)/\(cap)")
                            .foregroundColor(container.isNearCapacity ? .orange : .secondary)
                    }
                }
            }

            if let bottles = container.bottles, !bottles.isEmpty {
                Section("Vini in questo contenitore") {
                    ForEach(bottles.prefix(5)) { bottle in
                        if let wine = bottle.wine {
                            HStack {
                                Text(wine.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(bottle.quantity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if bottles.count > 5 {
                        Text("+ altri \(bottles.count - 5) vini")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Modifica Contenitore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    saveChanges()
                }
                .disabled(name.isEmpty)
            }
        }
        .onAppear {
            name = container.name
            capacity = container.capacity.map(String.init) ?? ""
            notes = container.notes ?? ""
        }
    }

    private func saveChanges() {
        container.name = name
        container.capacity = Int(capacity)
        container.notes = notes.isEmpty ? nil : notes
        container.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        StorageConfigurationView()
    }
    .modelContainer(for: [StorageArea.self, StorageContainer.self, Bottle.self, Wine.self], inMemory: true)
}
