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
                    EmptyCellarView {
                        Task {
                            await viewModel.loadInventory()
                        }
                    }
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
    @State private var isLoadingSample = false
    var onSampleDataLoaded: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Cantina vuota", systemImage: "wineglass")
        } description: {
            Text("Inizia ad aggiungere vini scansionando le etichette")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    appState.selectedTab = .scan
                } label: {
                    Label("Aggiungi vino", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    loadSampleData()
                } label: {
                    if isLoadingSample {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Carica vini di esempio", systemImage: "wineglass.fill")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingSample)
            }
        }
    }

    private func loadSampleData() {
        isLoadingSample = true
        Task {
            do {
                try await FirebaseService.shared.seedSampleData()
                onSampleDataLoaded?()
            } catch {
                // Ignore errors silently for now
            }
            isLoadingSample = false
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

// MARK: - Wine Detail View

struct WineDetailView: View {
    let item: WineInventoryItem
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = WineDetailViewModel()

    // Rating state
    @State private var showingQuickRating = false
    @State private var ratingValue: Int = 0
    @State private var isFavorite = false
    @State private var ratingNotes = ""

    // Taste profile state
    @State private var showingTasteProfile = false
    @State private var acidity: Int = 0
    @State private var tannin: Int = 0
    @State private var bodyValue: Int = 0
    @State private var sweetness: Int = 0
    @State private var effervescence: Int = 0
    @State private var tasteNotes = ""

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

                    Divider()

                    // Rating section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Il tuo giudizio")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingQuickRating = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        if ratingValue > 0 {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: index <= ratingValue ? "star.fill" : "star")
                                        .foregroundStyle(index <= ratingValue ? .yellow : .gray)
                                }
                                if isFavorite {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                        .padding(.leading, 8)
                                }
                            }
                            .font(.title2)

                            if !ratingNotes.isEmpty {
                                Text(ratingNotes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                showingQuickRating = true
                            } label: {
                                HStack {
                                    Image(systemName: "star")
                                    Text("Valuta questo vino")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding()

                    Divider()

                    // Taste profile section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Profilo sensoriale")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingTasteProfile = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        if hasTasteProfile {
                            TasteRadarChart(
                                acidity: acidity,
                                tannin: tannin,
                                wineBody: bodyValue,
                                sweetness: sweetness,
                                effervescence: effervescence
                            )
                            .frame(height: 180)

                            if !tasteNotes.isEmpty {
                                Text(tasteNotes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                showingTasteProfile = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.pie")
                                    Text("Aggiungi profilo sensoriale")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .padding()

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
            .sheet(isPresented: $showingQuickRating) {
                QuickRatingSheet(
                    wine: item.wine,
                    rating: $ratingValue,
                    isFavorite: $isFavorite,
                    notes: $ratingNotes,
                    onSave: saveRating
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingTasteProfile) {
                TasteProfileEditor(
                    wine: item.wine,
                    acidity: $acidity,
                    tannin: $tannin,
                    wineBody: $bodyValue,
                    sweetness: $sweetness,
                    effervescence: $effervescence,
                    notes: $tasteNotes,
                    onSave: saveTasteProfile
                )
            }
            .task {
                await loadData()
            }
        }
    }

    private var hasTasteProfile: Bool {
        acidity > 0 || tannin > 0 || bodyValue > 0 || sweetness > 0 || effervescence > 0
    }

    private func loadData() async {
        guard let wineId = item.wine.id else { return }

        // Load existing rating
        if let rating = item.rating {
            ratingValue = rating.rating
            isFavorite = rating.isFavorite
            ratingNotes = rating.notes ?? ""
        }

        // Load existing taste profile
        if let profile = item.tasteProfile {
            acidity = profile.acidity
            tannin = profile.tannin
            bodyValue = profile.body
            sweetness = profile.sweetness
            effervescence = profile.effervescence
            tasteNotes = profile.notes ?? ""
        } else {
            // Try to fetch from Firebase
            do {
                if let profile = try await FirebaseService.shared.getTasteProfile(for: wineId) {
                    acidity = profile.acidity
                    tannin = profile.tannin
                    bodyValue = profile.body
                    sweetness = profile.sweetness
                    effervescence = profile.effervescence
                    tasteNotes = profile.notes ?? ""
                }
            } catch {
                // Ignore - no taste profile saved
            }
        }
    }

    private func saveRating() {
        guard let wineId = item.wine.id else { return }
        Task {
            do {
                try await FirebaseService.shared.setRating(
                    ratingValue,
                    isFavorite: isFavorite,
                    notes: ratingNotes.isEmpty ? nil : ratingNotes,
                    for: wineId
                )
            } catch {
                // Handle error silently for now
            }
        }
    }

    private func saveTasteProfile() {
        guard let wineId = item.wine.id else { return }
        Task {
            do {
                let profile = TasteProfile(
                    id: nil,
                    wineId: wineId,
                    acidity: acidity,
                    tannin: tannin,
                    body: bodyValue,
                    sweetness: sweetness,
                    effervescence: effervescence,
                    notes: tasteNotes.isEmpty ? nil : tasteNotes,
                    tags: nil,
                    createdAt: nil
                )
                try await FirebaseService.shared.setTasteProfile(profile)
            } catch {
                // Handle error silently for now
            }
        }
    }
}

@MainActor
class WineDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
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

// MARK: - Quick Rating Sheet

struct QuickRatingSheet: View {
    let wine: Wine
    @Binding var rating: Int
    @Binding var isFavorite: Bool
    @Binding var notes: String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Wine info header
                VStack(spacing: 8) {
                    Text(wine.type.icon)
                        .font(.system(size: 48))
                    Text(wine.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    if let producer = wine.producer {
                        Text(producer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                Divider()

                // Star rating
                VStack(spacing: 12) {
                    Text("Il tuo voto")
                        .font(.headline)

                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { index in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    rating = index
                                }
                            } label: {
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .font(.system(size: 36))
                                    .foregroundStyle(index <= rating ? .yellow : .gray.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Favorite toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isFavorite.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : .gray)
                        Text(isFavorite ? "Tra i preferiti" : "Aggiungi ai preferiti")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFavorite ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (opzionale)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Aggiungi una nota...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                Spacer()

                // Save button
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Salva")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rating > 0 ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(rating == 0)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Valuta il vino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Taste Profile Editor

struct TasteProfileEditor: View {
    let wine: Wine
    @Binding var acidity: Int
    @Binding var tannin: Int
    @Binding var wineBody: Int
    @Binding var sweetness: Int
    @Binding var effervescence: Int
    @Binding var notes: String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Wine info header
                    VStack(spacing: 8) {
                        Text(wine.type.icon)
                            .font(.system(size: 40))
                        Text(wine.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    Divider()

                    // Sliders
                    VStack(spacing: 20) {
                        TasteSlider(label: "Acidità", value: $acidity, icon: "drop.fill", color: .green)
                        TasteSlider(label: "Tannino", value: $tannin, icon: "leaf.fill", color: .brown)
                        TasteSlider(label: "Corpo", value: $wineBody, icon: "circle.fill", color: .purple)
                        TasteSlider(label: "Dolcezza", value: $sweetness, icon: "cube.fill", color: .orange)
                        TasteSlider(label: "Effervescenza", value: $effervescence, icon: "bubbles.and.sparkles.fill", color: .cyan)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note di degustazione")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Descrivi aromi, sapori...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)

                    // Radar chart preview
                    if hasAnyValue {
                        VStack(spacing: 8) {
                            Text("Profilo sensoriale")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TasteRadarChart(
                                acidity: acidity,
                                tannin: tannin,
                                wineBody: wineBody,
                                sweetness: sweetness,
                                effervescence: effervescence
                            )
                            .frame(height: 200)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Space for button
            }
            .overlay(alignment: .bottom) {
                // Save button
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Salva profilo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Profilo sensoriale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasAnyValue: Bool {
        acidity > 0 || tannin > 0 || wineBody > 0 || sweetness > 0 || effervescence > 0
    }
}

struct TasteSlider: View {
    let label: String
    @Binding var value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(value)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            value = value == index ? 0 : index
                        }
                    } label: {
                        Circle()
                            .fill(index <= value ? color : color.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text("\(index)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(index <= value ? .white : color)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Taste Radar Chart

struct TasteRadarChart: View {
    let acidity: Int
    let tannin: Int
    let wineBody: Int
    let sweetness: Int
    let effervescence: Int

    private let labels = ["Acidità", "Tannino", "Corpo", "Dolcezza", "Efferv."]
    private let maxValue: Double = 5.0

    private var values: [Double] {
        [Double(acidity), Double(tannin), Double(wineBody), Double(sweetness), Double(effervescence)]
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 30

            ZStack {
                // Grid circles
                ForEach(1...5, id: \.self) { level in
                    let r = radius * Double(level) / 5.0
                    RadarPolygon(sides: 5, radius: r, center: center)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                // Axis lines
                ForEach(0..<5, id: \.self) { index in
                    let angle = angleForIndex(index)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointOnCircle(center: center, radius: radius, angle: angle))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }

                // Data polygon
                RadarDataPolygon(values: values, maxValue: maxValue, radius: radius, center: center)
                    .fill(Color.accentColor.opacity(0.3))

                RadarDataPolygon(values: values, maxValue: maxValue, radius: radius, center: center)
                    .stroke(Color.accentColor, lineWidth: 2)

                // Data points
                ForEach(0..<5, id: \.self) { index in
                    let normalizedValue = values[index] / maxValue
                    let angle = angleForIndex(index)
                    let point = pointOnCircle(center: center, radius: radius * normalizedValue, angle: angle)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .position(point)
                }

                // Labels
                ForEach(0..<5, id: \.self) { index in
                    let angle = angleForIndex(index)
                    let labelRadius = radius + 20
                    let point = pointOnCircle(center: center, radius: labelRadius, angle: angle)

                    Text(labels[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(point)
                }
            }
        }
    }

    private func angleForIndex(_ index: Int) -> Double {
        let angleStep = (2 * .pi) / 5.0
        return -(.pi / 2) + angleStep * Double(index) // Start from top
    }

    private func pointOnCircle(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

struct RadarPolygon: Shape {
    let sides: Int
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let angleStep = (2 * .pi) / Double(sides)

        for i in 0..<sides {
            let angle = -(.pi / 2) + angleStep * Double(i)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarDataPolygon: Shape {
    let values: [Double]
    let maxValue: Double
    let radius: Double
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let angleStep = (2 * .pi) / Double(values.count)

        for (index, value) in values.enumerated() {
            let normalizedValue = value / maxValue
            let angle = -(.pi / 2) + angleStep * Double(index)
            let point = CGPoint(
                x: center.x + radius * normalizedValue * cos(angle),
                y: center.y + radius * normalizedValue * sin(angle)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    CellarView()
        .environmentObject(AppState.shared)
        .environmentObject(AuthManager.shared)
}
