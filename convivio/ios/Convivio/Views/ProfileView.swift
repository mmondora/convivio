//
//  ProfileView.swift
//  Convivio
//
//  Profilo utente, gestione amici e impostazioni
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingFriendsList = false
    @State private var showingCellarSettings = false
    @State private var showingExportData = false
    @State private var showingDeleteAccount = false
    
    var body: some View {
        NavigationStack {
            List {
                // User info section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.user?.displayNameOrEmail ?? "Utente")
                                .font(.headline)
                            
                            if let email = authManager.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Stats section
                Section("La tua cantina") {
                    StatRow(icon: "wineglass", label: "Bottiglie", value: "\(viewModel.stats.totalBottles)")
                    StatRow(icon: "star.fill", label: "Vini valutati", value: "\(viewModel.stats.ratedWines)")
                    StatRow(icon: "fork.knife", label: "Cene organizzate", value: "\(viewModel.stats.totalDinners)")
                }
                
                // Friends section
                Section("Amici") {
                    NavigationLink {
                        FriendsListView()
                    } label: {
                        HStack {
                            Image(systemName: "person.2")
                            Text("Gestisci amici")
                            Spacer()
                            Text("\(viewModel.friendsCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Settings section
                Section("Impostazioni") {
                    NavigationLink {
                        CellarSettingsView()
                    } label: {
                        Label("Cantine", systemImage: "square.grid.2x2")
                    }
                    
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        Label("Preferenze vino", systemImage: "slider.horizontal.3")
                    }
                    
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifiche", systemImage: "bell")
                    }
                }
                
                // Privacy section
                Section("Privacy e dati") {
                    Button {
                        showingExportData = true
                    } label: {
                        Label("Esporta i tuoi dati", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAccount = true
                    } label: {
                        Label("Elimina account", systemImage: "trash")
                    }
                }
                
                // Sign out
                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Esci")
                            Spacer()
                        }
                    }
                }
                
                // App info
                Section {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profilo")
            .refreshable {
                await viewModel.loadStats()
            }
            .alert("Esporta dati", isPresented: $showingExportData) {
                Button("Esporta JSON") {
                    Task { await viewModel.exportData() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Riceverai un file JSON con tutti i tuoi dati (GDPR).")
            }
            .alert("Elimina account", isPresented: $showingDeleteAccount) {
                Button("Elimina", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Questa azione è irreversibile. Tutti i tuoi dati verranno eliminati.")
            }
        }
        .task {
            await viewModel.loadStats()
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(label)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Friends List View

struct FriendsListView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showingAddFriend = false
    @State private var selectedFriend: Friend?
    
    var body: some View {
        List {
            ForEach(viewModel.friends) { friend in
                FriendRow(friend: friend)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFriend = friend
                    }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteFriend(viewModel.friends[index])
                    }
                }
            }
        }
        .navigationTitle("Amici")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFriend = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView { friend in
                Task { await viewModel.addFriend(friend) }
            }
        }
        .sheet(item: $selectedFriend) { friend in
            FriendDetailView(friend: friend)
        }
        .overlay {
            if viewModel.friends.isEmpty {
                ContentUnavailableView {
                    Label("Nessun amico", systemImage: "person.2")
                } description: {
                    Text("Aggiungi amici per tracciare le loro preferenze alimentari")
                }
            }
        }
        .task {
            await viewModel.loadFriends()
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                
                Text(friend.foodieLevel.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (Friend) -> Void
    
    @State private var name = ""
    @State private var email = ""
    @State private var foodieLevel: FoodieLevel = .curious
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $name)
                    TextField("Email (opzionale)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Livello foodie") {
                    Picker("Livello", selection: $foodieLevel) {
                        ForEach(FoodieLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Note") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Nuovo Amico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") {
                        let friend = Friend(
                            id: nil,
                            name: name,
                            email: email.isEmpty ? nil : email,
                            phone: nil,
                            foodieLevel: foodieLevel,
                            notes: notes.isEmpty ? nil : notes,
                            createdAt: nil
                        )
                        onSave(friend)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Friend Detail View

struct FriendDetailView: View {
    let friend: Friend
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = FriendPreferencesViewModel()
    @State private var showingAddPreference = false
    
    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    HStack {
                        Text("Livello foodie")
                        Spacer()
                        Text(friend.foodieLevel.displayName)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let email = friend.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let notes = friend.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Note")
                            Text(notes)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Preferences section
                Section {
                    ForEach(viewModel.preferences) { pref in
                        HStack {
                            Image(systemName: pref.type.icon)
                                .foregroundStyle(prefColor(pref.type))
                            
                            VStack(alignment: .leading) {
                                Text(pref.category)
                                    .font(.headline)
                                Text(pref.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await viewModel.deletePreference(viewModel.preferences[index])
                            }
                        }
                    }
                    
                    Button {
                        showingAddPreference = true
                    } label: {
                        Label("Aggiungi preferenza", systemImage: "plus")
                    }
                } header: {
                    Text("Preferenze alimentari")
                }
            }
            .navigationTitle(friend.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddPreference) {
                AddPreferenceView { pref in
                    Task { await viewModel.addPreference(pref, to: friend) }
                }
            }
        }
        .task {
            await viewModel.loadPreferences(for: friend)
        }
    }
    
    private func prefColor(_ type: FoodPrefType) -> Color {
        switch type {
        case .allergy: return .red
        case .intolerance: return .orange
        case .dislike: return .yellow
        case .preference: return .green
        case .diet: return .blue
        }
    }
}

// MARK: - Add Preference View

struct AddPreferenceView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (FoodPreference) -> Void
    
    @State private var type: FoodPrefType = .intolerance
    @State private var category = ""
    @State private var description = ""
    
    let commonCategories = ["Lattosio", "Glutine", "Frutta secca", "Crostacei", "Pesce", "Uova", "Soia", "Carne rossa", "Maiale", "Piccante"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        ForEach(FoodPrefType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                }
                
                Section("Categoria") {
                    TextField("Es: Lattosio, Glutine...", text: $category)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(commonCategories, id: \.self) { cat in
                                Button(cat) {
                                    category = cat
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                Section("Descrizione (opzionale)") {
                    TextField("Dettagli aggiuntivi", text: $description)
                }
            }
            .navigationTitle("Nuova Preferenza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") {
                        let pref = FoodPreference(
                            id: nil,
                            friendId: nil,
                            type: type,
                            category: category,
                            description: description.isEmpty ? nil : description,
                            severity: nil
                        )
                        onSave(pref)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(category.isEmpty)
                }
            }
        }
    }
}

// MARK: - Placeholder Views

struct CellarSettingsView: View {
    var body: some View {
        Text("Impostazioni Cantine")
            .navigationTitle("Cantine")
    }
}

struct PreferencesView: View {
    var body: some View {
        Text("Preferenze Vino")
            .navigationTitle("Preferenze")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Text("Impostazioni Notifiche")
            .navigationTitle("Notifiche")
    }
}

// MARK: - View Models

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var stats = UserStats()
    @Published var friendsCount = 0
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadStats() async {
        isLoading = true
        defer { isLoading = false }

        do {
            stats = try await firebase.getUserStats()
            let friends = try await firebase.getFriends()
            friendsCount = friends.count
        } catch {
            self.error = error.localizedDescription
        }
    }

    func exportData() async {
        do {
            let data = try await firebase.exportUserData()
            // Convert to JSON and share
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // Save to Documents and share via UIActivityViewController
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("convivio_data.json")
                try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                // Would present share sheet here
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAccount() async {
        do {
            try await firebase.deleteUserAccount()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadFriends() async {
        isLoading = true
        defer { isLoading = false }

        do {
            friends = try await firebase.getFriends()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addFriend(_ friend: Friend) async {
        do {
            _ = try await firebase.addFriend(friend)
            await loadFriends()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteFriend(_ friend: Friend) async {
        guard let friendId = friend.id else { return }

        do {
            try await firebase.deleteFriend(friendId)
            friends.removeAll { $0.id == friendId }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
class FriendPreferencesViewModel: ObservableObject {
    @Published var preferences: [FoodPreference] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadPreferences(for friend: Friend) async {
        guard let friendId = friend.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            preferences = try await firebase.getFoodPreferences(for: friendId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addPreference(_ pref: FoodPreference, to friend: Friend) async {
        guard let friendId = friend.id else { return }

        do {
            try await firebase.addFoodPreference(pref, to: friendId)
            await loadPreferences(for: friend)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePreference(_ pref: FoodPreference) async {
        guard let prefId = pref.id else { return }

        do {
            try await firebase.deleteFoodPreference(prefId)
            preferences.removeAll { $0.id == prefId }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
