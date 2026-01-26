//
//  DinnerListView.swift
//  Convivio
//
//  Lista delle cene pianificate
//

import SwiftUI
import FirebaseFirestore

struct DinnerListView: View {
    @StateObject private var viewModel = DinnerListViewModel()
    @State private var showingNewDinner = false
    @State private var selectedDinner: DinnerEvent?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento...")
                } else if viewModel.dinners.isEmpty {
                    emptyState
                } else {
                    dinnerList
                }
            }
            .navigationTitle("Cene")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewDinner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewDinner) {
                NewDinnerView { dinner in
                    Task {
                        await viewModel.createDinner(dinner)
                    }
                }
            }
            .sheet(item: $selectedDinner) { dinner in
                DinnerDetailView(dinner: dinner)
            }
            .refreshable {
                await viewModel.loadDinners()
            }
        }
        .task {
            await viewModel.loadDinners()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessuna cena", systemImage: "fork.knife")
        } description: {
            Text("Pianifica la tua prima cena e lascia che l'AI ti suggerisca menu e vini")
        } actions: {
            Button {
                showingNewDinner = true
            } label: {
                Label("Nuova cena", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Dinner List
    
    private var dinnerList: some View {
        List {
            // Upcoming
            let upcoming = viewModel.dinners.filter { 
                $0.date.dateValue() >= Date() && $0.status != .cancelled 
            }
            if !upcoming.isEmpty {
                Section("Prossime") {
                    ForEach(upcoming) { dinner in
                        DinnerRow(dinner: dinner)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDinner = dinner
                            }
                    }
                }
            }
            
            // Past
            let past = viewModel.dinners.filter { 
                $0.date.dateValue() < Date() || $0.status == .cancelled 
            }
            if !past.isEmpty {
                Section("Passate") {
                    ForEach(past) { dinner in
                        DinnerRow(dinner: dinner)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDinner = dinner
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Dinner Row

struct DinnerRow: View {
    let dinner: DinnerEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack {
                Text(dinner.date.dateValue(), format: .dateTime.day())
                    .font(.title2)
                    .fontWeight(.bold)
                Text(dinner.date.dateValue(), format: .dateTime.month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dinner.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(dinner.style.displayName, systemImage: "star")
                    Label(dinner.cookingTime.displayName, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status badge
            StatusBadge(status: dinner.status)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: DinnerStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .planning: return .blue
        case .confirmed: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

// MARK: - New Dinner View

struct NewDinnerView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (DinnerEvent) -> Void
    
    @State private var name = ""
    @State private var date = Date()
    @State private var style: DinnerStyle = .convivial
    @State private var cookingTime: CookingTime = .oneHour
    @State private var budget: BudgetLevel = .standard
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome cena", text: $name)
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Impostazioni") {
                    Picker("Stile", selection: $style) {
                        ForEach(DinnerStyle.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    
                    Picker("Tempo cottura", selection: $cookingTime) {
                        ForEach(CookingTime.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    
                    Picker("Budget vini", selection: $budget) {
                        ForEach(BudgetLevel.allCases, id: \.self) { b in
                            Text(b.displayName).tag(b)
                        }
                    }
                }
                
                Section("Note") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Nuova Cena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") {
                        let dinner = DinnerEvent(
                            id: nil,
                            name: name,
                            date: Timestamp(date: date),
                            time: nil,
                            style: style,
                            cookingTime: cookingTime,
                            budgetLevel: budget,
                            notes: notes.isEmpty ? nil : notes,
                            status: .planning,
                            menuProposal: nil,
                            createdAt: nil,
                            updatedAt: nil
                        )
                        onSave(dinner)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Dinner Detail View

struct DinnerDetailView: View {
    let dinner: DinnerEvent
    @Environment(\.dismiss) var dismiss
    @State private var isGeneratingProposal = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dinner.date.dateValue(), format: .dateTime.weekday(.wide).day().month(.wide))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            StatusBadge(status: dinner.status)
                        }
                        
                        Text(dinner.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding()
                    
                    // Info cards
                    HStack(spacing: 12) {
                        InfoCard(icon: "star", title: "Stile", value: dinner.style.displayName)
                        InfoCard(icon: "clock", title: "Tempo", value: dinner.cookingTime.displayName)
                        InfoCard(icon: "eurosign", title: "Budget", value: dinner.budgetLevel.displayName)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Menu proposal
                    if let menu = dinner.menuProposal {
                        menuSection(menu)
                    } else {
                        generateProposalSection
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
    
    // MARK: - Generate Proposal Section
    
    private var generateProposalSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.purple)

            Text("Genera proposta AI")
                .font(.headline)

            Text("L'AI creerà un menu personalizzato con abbinamenti vino basati sui tuoi ospiti e sulla tua cantina")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                generateProposal()
            } label: {
                if isGeneratingProposal {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Genera menu e vini", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGeneratingProposal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func generateProposal() {
        guard let dinnerId = dinner.id else {
            print("🍷 DINNER: No dinner ID!")
            return
        }

        print("🍷 DINNER: Button pressed, generating proposal for \(dinnerId)")
        isGeneratingProposal = true

        Task {
            do {
                print("🍷 DINNER: Calling FirebaseService.generateMenuProposal...")
                let proposal = try await FirebaseService.shared.generateMenuProposal(dinnerId: dinnerId)
                print("🍷 DINNER: Got proposal: \(proposal)")
                // Note: The dinner object is immutable here, user needs to refresh to see the result
            } catch {
                print("🍷 DINNER ERROR: \(error)")
            }
            isGeneratingProposal = false
        }
    }
    
    // MARK: - Menu Section
    
    private func menuSection(_ menu: MenuProposal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Menu proposto")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(menu.courses) { course in
                CourseCard(course: course)
            }
            
            // Reasoning
            VStack(alignment: .leading, spacing: 8) {
                Text("Perché questa proposta")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(menu.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: MenuCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(course.course.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                ForEach(course.dietaryFlags, id: \.self) { flag in
                    Text(flag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            
            Text(course.name)
                .font(.headline)
            
            Text(course.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "clock")
                Text("\(course.prepTime) min")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - View Model

@MainActor
class DinnerListViewModel: ObservableObject {
    @Published var dinners: [DinnerEvent] = []
    @Published var isLoading = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadDinners() async {
        isLoading = true
        defer { isLoading = false }

        do {
            dinners = try await firebase.getDinners()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createDinner(_ dinner: DinnerEvent) async {
        do {
            _ = try await firebase.createDinner(dinner)
            await loadDinners()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Dinner Detail ViewModel

@MainActor
class DinnerDetailViewModel: ObservableObject {
    @Published var guests: [Friend] = []
    @Published var isGenerating = false
    @Published var error: String?

    private let firebase = FirebaseService.shared

    func loadGuests(for dinnerId: String) async {
        do {
            let guestIds = try await firebase.getDinnerGuests(dinnerId)
            let allFriends = try await firebase.getFriends()
            guests = allFriends.filter { guestIds.contains($0.id ?? "") }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addGuest(_ friend: Friend, to dinnerId: String) async {
        guard let friendId = friend.id else { return }

        do {
            try await firebase.addGuestToDinner(dinnerId, friendId: friendId)
            await loadGuests(for: dinnerId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func generateProposal(for dinnerId: String) async -> MenuProposal? {
        print("🍷 DINNER: generateProposal called for dinner \(dinnerId)")
        isGenerating = true
        defer { isGenerating = false }

        do {
            print("🍷 DINNER: Calling generateMenuProposal...")
            let proposal = try await firebase.generateMenuProposal(dinnerId: dinnerId)
            print("🍷 DINNER: Got proposal, updating dinner...")
            try await firebase.updateDinner(dinnerId, menuProposal: proposal)
            print("🍷 DINNER: Complete!")
            return proposal
        } catch {
            print("🍷 DINNER ERROR: \(error)")
            self.error = error.localizedDescription
            return nil
        }
    }
}

#Preview {
    DinnerListView()
}
