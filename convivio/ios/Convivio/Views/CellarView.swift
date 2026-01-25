//
//  CellarView.swift
//  Convivio
//
//  Schermata principale della cantina con lista vini raggruppati per tipo
//

import SwiftUI
import FirebaseFirestore

struct CellarView: View {
    @StateObject private var viewModel = CellarViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: WineType?
    @State private var showingFilters = false
    @State private var selectedWine: WineInventoryItem?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento cantina...")
                } else if viewModel.inventory.isEmpty {
                    EmptyCellarView()
                } else {
                    wineList
                }
            }
            .navigationTitle("Cantina")
            .searchable(text: $searchText, prompt: "Cerca vino, produttore...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilters.toggle()
                    } label: {
                        Image(systemName: selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(selectedFilter: $selectedFilter)
                    .presentationDetents([.medium])
            }
            .sheet(item: $selectedWine) { wine in
                WineDetailView(item: wine)
            }
            .refreshable {
                await viewModel.loadInventory()
            }
        }
        .task {
            await viewModel.loadInventory()
        }
    }
    
    // MARK: - Wine List
    
    private var wineList: some View {
        List {
            ForEach(groupedWines.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { type in
                Section {
                    ForEach(groupedWines[type] ?? []) { item in
                        WineRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWine = item
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.consumeBottle(item)
                                    }
                                } label: {
                                    Label("Bevi", systemImage: "wineglass")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(type.icon)
                        Text("\(type.displayName) (\(groupedWines[type]?.count ?? 0))")
                            .textCase(.none)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Grouping & Filtering
    
    private var filteredInventory: [WineInventoryItem] {
        var items = viewModel.inventory
        
        // Filter by type
        if let filter = selectedFilter {
            items = items.filter { $0.wine.type == filter }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                item.wine.name.lowercased().contains(query) ||
                item.wine.producer?.lowercased().contains(query) == true ||
                item.wine.region?.lowercased().contains(query) == true
            }
        }
        
        return items
    }
    
    private var groupedWines: [WineType: [WineInventoryItem]] {
        Dictionary(grouping: filteredInventory) { $0.wine.type }
    }
}

// MARK: - Wine Row

struct WineRow: View {
    let item: WineInventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Wine type indicator
            Circle()
                .fill(Color(item.wine.type.color))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.wine.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(item.wine.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    // Rating
                    if let rating = item.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", Double(rating.rating)))
                        }
                        .font(.caption)
                    }
                    
                    // Location
                    if let location = item.primaryLocation {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                            Text(location.shelf)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Bottle count
            VStack {
                Text("\(item.availableBottles)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("bott.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyCellarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ContentUnavailableView {
            Label("Cantina vuota", systemImage: "wineglass")
        } description: {
            Text("Inizia ad aggiungere vini scansionando le etichette")
        } actions: {
            Button {
                appState.selectedTab = .scan
            } label: {
                Label("Aggiungi vino", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var selectedFilter: WineType?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedFilter = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("Tutti i vini")
                        Spacer()
                        if selectedFilter == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
                
                ForEach(WineType.allCases) { type in
                    Button {
                        selectedFilter = type
                        dismiss()
                    } label: {
                        HStack {
                            Text(type.icon)
                            Text(type.displayName)
                            Spacer()
                            if selectedFilter == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Filtra per tipo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class CellarViewModel: ObservableObject {
    @Published var inventory: [WineInventoryItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    
    func loadInventory() async {
        guard let userId = AuthManager.shared.user?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get user's cellars
            let cellarsSnapshot = try await db.collection("cellars")
                .whereField("members.\(userId)", isNotEqualTo: NSNull())
                .getDocuments()
            
            var wineData: [String: (wine: Wine, bottles: Int, locations: [Location])] = [:]
            
            // For each cellar, get bottles
            for cellarDoc in cellarsSnapshot.documents {
                let bottlesSnapshot = try await cellarDoc.reference
                    .collection("bottles")
                    .whereField("status", isEqualTo: "available")
                    .getDocuments()
                
                for bottleDoc in bottlesSnapshot.documents {
                    let bottle = try bottleDoc.data(as: Bottle.self)
                    
                    if var existing = wineData[bottle.wineId] {
                        existing.bottles += 1
                        wineData[bottle.wineId] = existing
                    } else {
                        // Load wine
                        let wineDoc = try await db.collection("wines").document(bottle.wineId).getDocument()
                        if let wine = try? wineDoc.data(as: Wine.self) {
                            // Load location
                            let locationDoc = try await cellarDoc.reference
                                .collection("locations")
                                .document(bottle.locationId)
                                .getDocument()
                            let location = try? locationDoc.data(as: Location.self)
                            
                            wineData[bottle.wineId] = (
                                wine: wine,
                                bottles: 1,
                                locations: location != nil ? [location!] : []
                            )
                        }
                    }
                }
            }
            
            // Load ratings
            var items: [WineInventoryItem] = []
            for (wineId, data) in wineData {
                let ratingSnapshot = try await db.collection("users").document(userId)
                    .collection("ratings")
                    .whereField("wineId", isEqualTo: wineId)
                    .limit(to: 1)
                    .getDocuments()
                
                let rating = try? ratingSnapshot.documents.first?.data(as: Rating.self)
                
                items.append(WineInventoryItem(
                    wine: data.wine,
                    availableBottles: data.bottles,
                    locations: data.locations,
                    rating: rating,
                    tasteProfile: nil
                ))
            }
            
            // Sort by name
            inventory = items.sorted { $0.wine.name < $1.wine.name }
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func consumeBottle(_ item: WineInventoryItem) async {
        guard let userId = AuthManager.shared.user?.uid,
              let wineId = item.wine.id else { return }
        
        do {
            // Find one available bottle of this wine
            let cellarsSnapshot = try await db.collection("cellars")
                .whereField("members.\(userId)", isNotEqualTo: NSNull())
                .getDocuments()
            
            for cellarDoc in cellarsSnapshot.documents {
                let bottlesSnapshot = try await cellarDoc.reference
                    .collection("bottles")
                    .whereField("wineId", isEqualTo: wineId)
                    .whereField("status", isEqualTo: "available")
                    .limit(to: 1)
                    .getDocuments()
                
                if let bottleDoc = bottlesSnapshot.documents.first {
                    // Update bottle status
                    try await bottleDoc.reference.updateData([
                        "status": "consumed",
                        "consumedAt": FieldValue.serverTimestamp()
                    ])
                    
                    // Create movement record
                    try await cellarDoc.reference.collection("movements").addDocument(data: [
                        "bottleId": bottleDoc.documentID,
                        "type": "out",
                        "reason": "consumed",
                        "performedBy": userId,
                        "performedAt": FieldValue.serverTimestamp()
                    ])
                    
                    // Reload inventory
                    await loadInventory()
                    return
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Wine Detail View (Placeholder)

struct WineDetailView: View {
    let item: WineInventoryItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.wine.type.icon)
                                .font(.largeTitle)
                            Text(item.wine.type.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(item.wine.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let producer = item.wine.producer {
                            Text(producer)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Info
                    VStack(spacing: 12) {
                        InfoRow(label: "Disponibili", value: "\(item.availableBottles) bottiglie")
                        
                        if let region = item.wine.region {
                            InfoRow(label: "Regione", value: region)
                        }
                        
                        if let country = item.wine.country {
                            InfoRow(label: "Paese", value: country)
                        }
                        
                        if let location = item.primaryLocation {
                            InfoRow(label: "Posizione", value: location.displayPath)
                        }
                    }
                    .padding()
                    
                    // Rating section
                    if let rating = item.rating {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Il tuo giudizio")
                                .font(.headline)
                            
                            HStack {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: index <= rating.rating ? "star.fill" : "star")
                                        .foregroundStyle(index <= rating.rating ? .yellow : .gray)
                                }
                            }
                            .font(.title2)
                            
                            if let notes = rating.notes, !notes.isEmpty {
                                Text(notes)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    CellarView()
        .environmentObject(AppState.shared)
        .environmentObject(AuthManager.shared)
}
