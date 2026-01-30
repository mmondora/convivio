import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Cellar Manager

/// Manages the currently selected cellar across the app
@MainActor
class CellarManager: ObservableObject {
    static let shared = CellarManager()

    // MARK: - Published Properties

    @Published var selectedCellarId: String?
    @Published var selectedCellar: Cellar?
    @Published var availableCellars: [Cellar] = []
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let selectedCellarKey = "SelectedCellarId"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load saved selection
        selectedCellarId = UserDefaults.standard.string(forKey: selectedCellarKey)
    }

    // MARK: - Public Methods

    /// Load cellars from the model context
    func loadCellars(from context: ModelContext) {
        isLoading = true

        do {
            let descriptor = FetchDescriptor<Cellar>(
                sortBy: [SortDescriptor(\.name)]
            )
            availableCellars = try context.fetch(descriptor)

            // Auto-select if needed
            if selectedCellar == nil {
                selectDefaultCellar()
            }

            // Verify selected cellar still exists
            if let id = selectedCellarId,
               !availableCellars.contains(where: { $0.id == id }) {
                selectDefaultCellar()
            }

            // Update selected cellar reference
            if let id = selectedCellarId {
                selectedCellar = availableCellars.first { $0.id == id }
            }

        } catch {
            print("Failed to load cellars: \(error)")
        }

        isLoading = false
    }

    /// Select a cellar
    func selectCellar(_ cellar: Cellar) {
        selectedCellarId = cellar.id
        selectedCellar = cellar
        UserDefaults.standard.set(cellar.id, forKey: selectedCellarKey)
    }

    /// Select cellar by ID
    func selectCellar(id: String) {
        selectedCellarId = id
        selectedCellar = availableCellars.first { $0.id == id }
        UserDefaults.standard.set(id, forKey: selectedCellarKey)
    }

    /// Create a new cellar
    func createCellar(name: String, in context: ModelContext) -> Cellar {
        let cellar = Cellar(name: name)

        // Set owner ID if available
        if let userRecordID = CloudKitService.shared.currentUserRecordID {
            cellar.ownerId = userRecordID.recordName
        }

        context.insert(cellar)
        try? context.save()

        // Reload and select
        loadCellars(from: context)
        selectCellar(cellar)

        return cellar
    }

    /// Delete a cellar
    func deleteCellar(_ cellar: Cellar, from context: ModelContext) throws {
        guard cellar.id != selectedCellarId || availableCellars.count > 1 else {
            throw CellarError.cannotDeleteLastCellar
        }

        context.delete(cellar)
        try context.save()

        // If deleted cellar was selected, select another
        if cellar.id == selectedCellarId {
            loadCellars(from: context)
            selectDefaultCellar()
        } else {
            loadCellars(from: context)
        }
    }

    /// Rename a cellar
    func renameCellar(_ cellar: Cellar, to newName: String, in context: ModelContext) {
        cellar.name = newName
        cellar.updatedAt = Date()
        try? context.save()
        loadCellars(from: context)
    }

    /// Get the user's role in a cellar
    func getUserRole(for cellar: Cellar) -> CellarRole {
        guard let currentUserRecordName = CloudKitService.shared.currentUserRecordID?.recordName else {
            return .guest
        }

        if cellar.ownerId == currentUserRecordName || cellar.ownerId.isEmpty {
            return .owner
        }

        // For shared cellars, we'd check the CKShare participants
        // For now, return member for shared, owner for owned
        return cellar.isShared ? .member : .owner
    }

    // MARK: - Private Methods

    private func selectDefaultCellar() {
        if let first = availableCellars.first {
            selectCellar(first)
        } else {
            selectedCellarId = nil
            selectedCellar = nil
            UserDefaults.standard.removeObject(forKey: selectedCellarKey)
        }
    }
}

// MARK: - Cellar Errors

enum CellarError: LocalizedError {
    case cannotDeleteLastCellar
    case cellarNotFound
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .cannotDeleteLastCellar:
            return "Non puoi eliminare l'ultima cantina"
        case .cellarNotFound:
            return "Cantina non trovata"
        case .notAuthorized:
            return "Non hai i permessi per questa operazione"
        }
    }
}

// MARK: - Environment Key

struct SelectedCellarKey: EnvironmentKey {
    static let defaultValue: Cellar? = nil
}

extension EnvironmentValues {
    var selectedCellar: Cellar? {
        get { self[SelectedCellarKey.self] }
        set { self[SelectedCellarKey.self] = newValue }
    }
}
