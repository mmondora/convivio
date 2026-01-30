import Foundation
import SwiftData
import CloudKit

// MARK: - Cellar

/// Top-level container for wines, storage areas, and dinners.
/// Supports CloudKit sharing for collaborative cellars.
@Model
final class Cellar {
    var id: String = UUID().uuidString
    var name: String = "La Mia Cantina"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var ownerId: String = ""  // CloudKit user record ID
    var isShared: Bool = false
    var shareRecordData: Data?  // Serialized CKShare for sharing info

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Wine.cellar)
    var wines: [Wine] = []

    @Relationship(deleteRule: .cascade, inverse: \StorageArea.cellar)
    var storageAreas: [StorageArea] = []

    @Relationship(deleteRule: .cascade, inverse: \DinnerEvent.cellar)
    var dinners: [DinnerEvent] = []

    init(name: String = "La Mia Cantina", ownerId: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.ownerId = ownerId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var totalWines: Int {
        wines.count
    }

    var totalBottles: Int {
        wines.reduce(0) { total, wine in
            total + (wine.bottles?.reduce(0) { $0 + $1.quantity } ?? 0)
        }
    }

    var upcomingDinners: [DinnerEvent] {
        dinners
            .filter { $0.date > Date() && $0.status != .cancelled }
            .sorted { $0.date < $1.date }
    }

    var displayIcon: String {
        isShared ? "person.2.fill" : "archivebox.fill"
    }
}

// MARK: - Cellar Role

/// Permission levels for cellar participants
enum CellarRole: String, Codable, CaseIterable, Identifiable {
    case owner = "owner"
    case member = "member"
    case guest = "guest"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owner: return "Proprietario"
        case .member: return "Membro"
        case .guest: return "Ospite"
        }
    }

    var description: String {
        switch self {
        case .owner: return "Controllo completo sulla cantina"
        case .member: return "Può aggiungere e modificare vini e cene"
        case .guest: return "Può solo visualizzare e votare sui menu"
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .member: return "person.fill"
        case .guest: return "eye.fill"
        }
    }

    // MARK: - Permissions

    var canEditWines: Bool {
        self != .guest
    }

    var canAddWines: Bool {
        self != .guest
    }

    var canDeleteWines: Bool {
        self == .owner || self == .member
    }

    var canCreateDinners: Bool {
        self != .guest
    }

    var canEditDinners: Bool {
        self != .guest
    }

    var canDeleteDinners: Bool {
        self == .owner
    }

    var canVote: Bool {
        true  // All roles can vote
    }

    var canComment: Bool {
        true  // All roles can comment
    }

    var canPropose: Bool {
        self != .guest
    }

    var canManageParticipants: Bool {
        self == .owner
    }

    var canInviteOthers: Bool {
        self == .owner || self == .member
    }

    var canDeleteCellar: Bool {
        self == .owner
    }

    var canShareCellar: Bool {
        self == .owner
    }

    /// Convert from CKShare.ParticipantPermission
    static func from(permission: CKShare.ParticipantPermission) -> CellarRole {
        switch permission {
        case .readWrite:
            return .member
        case .readOnly:
            return .guest
        default:
            return .guest
        }
    }

    /// Convert to CKShare.ParticipantPermission
    var ckPermission: CKShare.ParticipantPermission {
        switch self {
        case .owner:
            return .readWrite
        case .member:
            return .readWrite
        case .guest:
            return .readOnly
        }
    }
}

// MARK: - Cellar Participant

/// Represents a participant in a shared cellar
struct CellarParticipant: Identifiable, Codable {
    let id: String  // CloudKit user record ID
    var name: String
    var email: String?
    var role: CellarRole
    var joinedAt: Date
    var acceptanceStatus: AcceptanceStatus

    enum AcceptanceStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case removed = "removed"
    }

    init(
        id: String,
        name: String,
        email: String? = nil,
        role: CellarRole,
        joinedAt: Date = Date(),
        acceptanceStatus: AcceptanceStatus = .pending
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.joinedAt = joinedAt
        self.acceptanceStatus = acceptanceStatus
    }
}

// MARK: - Sync Metadata

/// Tracks sync status for conflict resolution
struct SyncMetadata: Codable {
    var lastSyncedAt: Date?
    var lastModifiedAt: Date
    var localVersion: Int
    var serverVersion: Int
    var conflictResolved: Bool

    init(
        lastSyncedAt: Date? = nil,
        lastModifiedAt: Date = Date(),
        localVersion: Int = 1,
        serverVersion: Int = 0,
        conflictResolved: Bool = false
    ) {
        self.lastSyncedAt = lastSyncedAt
        self.lastModifiedAt = lastModifiedAt
        self.localVersion = localVersion
        self.serverVersion = serverVersion
        self.conflictResolved = conflictResolved
    }

    var needsSync: Bool {
        guard let lastSync = lastSyncedAt else { return true }
        return lastModifiedAt > lastSync
    }

    mutating func markSynced() {
        lastSyncedAt = Date()
        serverVersion = localVersion
        conflictResolved = false
    }

    mutating func incrementVersion() {
        localVersion += 1
        lastModifiedAt = Date()
    }
}

// MARK: - Migration Status

/// Tracks migration from local-only to CloudKit
enum MigrationStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .notStarted: return "Non iniziata"
        case .inProgress: return "In corso"
        case .completed: return "Completata"
        case .failed: return "Fallita"
        }
    }
}
