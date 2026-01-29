import Foundation
import SwiftData

// MARK: - Storage Area

/// Represents a storage area (e.g., "Cantina", "Cucina", "Sala")
@Model
final class StorageArea {
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StorageContainer.area)
    var containers: [StorageContainer]?

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.containers = []
    }

    var containerCount: Int {
        containers?.count ?? 0
    }

    var totalBottles: Int {
        containers?.reduce(0) { $0 + ($1.currentBottleCount) } ?? 0
    }
}

// MARK: - Storage Container

/// Represents a storage container within an area (e.g., "Cantinetta Eurocave", "Armadio legno")
@Model
final class StorageContainer {
    var name: String
    var capacity: Int?  // Maximum bottles (optional)
    var notes: String?  // E.g., "temperatura 14°C"
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var area: StorageArea?

    @Relationship(inverse: \Bottle.storageContainer)
    var bottles: [Bottle]?

    init(name: String, capacity: Int? = nil, notes: String? = nil, sortOrder: Int = 0) {
        self.name = name
        self.capacity = capacity
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.bottles = []
    }

    var currentBottleCount: Int {
        bottles?.reduce(0) { $0 + $1.quantity } ?? 0
    }

    var capacityUsage: String? {
        guard let cap = capacity else { return nil }
        return "\(currentBottleCount)/\(cap)"
    }

    var isNearCapacity: Bool {
        guard let cap = capacity, cap > 0 else { return false }
        return Double(currentBottleCount) / Double(cap) >= 0.9
    }

    var fullLocationName: String {
        if let areaName = area?.name {
            return "\(areaName) › \(name)"
        }
        return name
    }

    /// Short display name for list views
    var abbreviatedLocation: String {
        if let areaName = area?.name {
            // Use first letter of area + container name
            let areaAbbrev = String(areaName.prefix(1)).uppercased()
            return "\(areaAbbrev)/\(name)"
        }
        return name
    }
}

// MARK: - Bottle Extension for Storage

extension Bottle {
    /// Full location description including container and position
    var fullLocationDescription: String? {
        var parts: [String] = []

        if let container = storageContainer {
            parts.append(container.fullLocationName)
        }

        if let position = positionInContainer, !position.isEmpty {
            parts.append(position)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    /// Short location for compact list view
    var shortLocation: String? {
        if let container = storageContainer {
            if let position = positionInContainer, !position.isEmpty {
                return "\(container.abbreviatedLocation) (\(position))"
            }
            return container.abbreviatedLocation
        }
        return nil
    }
}

// MARK: - Cellar Sort Options

enum CellarSortOption: String, CaseIterable, Identifiable {
    case quantity = "Quantità"
    case name = "Nome"
    case vintage = "Annata"
    case location = "Posizione"
    case type = "Tipo"
    case recentlyAdded = "Recenti"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quantity: return "number.circle"
        case .name: return "textformat"
        case .vintage: return "calendar"
        case .location: return "mappin.circle"
        case .type: return "wineglass"
        case .recentlyAdded: return "clock"
        }
    }
}

// MARK: - Cellar Filter Options

enum CellarFilterOption: Hashable {
    case wineType(WineType)
    case storageArea(StorageArea)
    case lowStock  // quantity <= 2

    var displayName: String {
        switch self {
        case .wineType(let type):
            return type.displayName
        case .storageArea(let area):
            return area.name
        case .lowStock:
            return "In esaurimento"
        }
    }

    var icon: String {
        switch self {
        case .wineType(let type):
            return type.icon
        case .storageArea:
            return "archivebox"
        case .lowStock:
            return "exclamationmark.triangle"
        }
    }

    // Custom hash implementation for StorageArea
    func hash(into hasher: inout Hasher) {
        switch self {
        case .wineType(let type):
            hasher.combine("wineType")
            hasher.combine(type.rawValue)
        case .storageArea(let area):
            hasher.combine("storageArea")
            hasher.combine(area.name)
        case .lowStock:
            hasher.combine("lowStock")
        }
    }

    static func == (lhs: CellarFilterOption, rhs: CellarFilterOption) -> Bool {
        switch (lhs, rhs) {
        case (.wineType(let l), .wineType(let r)):
            return l == r
        case (.storageArea(let l), .storageArea(let r)):
            return l.name == r.name
        case (.lowStock, .lowStock):
            return true
        default:
            return false
        }
    }
}
