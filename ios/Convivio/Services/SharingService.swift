import Foundation
import CloudKit
import SwiftUI
import SwiftData

// MARK: - Sharing Service

/// Manages CloudKit sharing for collaborative cellars
@MainActor
class SharingService: ObservableObject {
    static let shared = SharingService()

    // MARK: - Published Properties

    @Published var pendingInvitations: [CKShare.Metadata] = []
    @Published var isProcessingShare: Bool = false
    @Published var shareError: String?

    // MARK: - Private Properties

    private var cloudKitService: CloudKitService { CloudKitService.shared }

    // MARK: - Initialization

    private init() {}

    // MARK: - Share Creation

    /// Create a share for a cellar
    func createShare(for cellar: Cellar, in container: ModelContainer) async throws -> CKShare {
        isProcessingShare = true
        shareError = nil

        defer { isProcessingShare = false }

        // Get the persistent identifier for the cellar
        let cellarID = cellar.persistentModelID

        // Create share using SwiftData's built-in sharing
        let (share, _) = try await container.mainContext.share(
            [cellar],
            to: nil  // Create new share
        )

        // Configure share settings
        share.publicPermission = .none  // Only invited participants
        share[CKShare.SystemFieldKey.title] = cellar.name
        share[CKShare.SystemFieldKey.shareType] = "Cantina"

        // Update cellar to mark as shared
        cellar.isShared = true
        cellar.shareRecordData = try? NSKeyedArchiver.archivedData(
            withRootObject: share,
            requiringSecureCoding: true
        )
        cellar.updatedAt = Date()

        try container.mainContext.save()

        return share
    }

    /// Get existing share for a cellar
    func getShare(for cellar: Cellar, in container: ModelContainer) async throws -> CKShare? {
        guard cellar.isShared else { return nil }

        // Try to get share from SwiftData
        let shares = try await container.mainContext.fetchShares(matching: [cellar.persistentModelID])
        return shares[cellar.persistentModelID]
    }

    // MARK: - Share Acceptance

    /// Accept a share invitation
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        isProcessingShare = true
        shareError = nil

        defer { isProcessingShare = false }

        do {
            // Accept the share using CloudKit
            try await cloudKitService.container.accept(metadata)

            // Remove from pending invitations
            pendingInvitations.removeAll { $0.share.recordID == metadata.share.recordID }

        } catch {
            shareError = error.localizedDescription
            throw error
        }
    }

    /// Decline a share invitation
    func declineShare(_ metadata: CKShare.Metadata) {
        pendingInvitations.removeAll { $0.share.recordID == metadata.share.recordID }
    }

    // MARK: - Participant Management

    /// Get participants for a cellar's share
    func getParticipants(for cellar: Cellar, in container: ModelContainer) async throws -> [ShareParticipant] {
        guard let share = try await getShare(for: cellar, in: container) else {
            return []
        }

        return share.participants.map { ckParticipant in
            ShareParticipant(from: ckParticipant)
        }
    }

    /// Invite a participant to a cellar
    func inviteParticipant(
        email: String,
        role: CellarRole,
        to cellar: Cellar,
        in container: ModelContainer
    ) async throws {
        guard let share = try await getShare(for: cellar, in: container) else {
            throw SharingError.shareNotFound
        }

        isProcessingShare = true
        defer { isProcessingShare = false }

        // Look up user by email
        let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)

        do {
            let identities = try await cloudKitService.container.userIdentities(matching: [lookupInfo])

            guard let identity = identities.first?.0,
                  let userRecordID = identity.userRecordID else {
                throw SharingError.userNotFound
            }

            // Create participant
            let participant = CKShare.Participant()
            // Note: In real implementation, you'd need to use the fetched identity

            // Add to share
            share.addParticipant(participant)

            // Save the share
            let database = cloudKitService.privateDatabase
            _ = try await database.save(share)

        } catch {
            shareError = error.localizedDescription
            throw error
        }
    }

    /// Update a participant's permission
    func updatePermission(
        for participant: ShareParticipant,
        to role: CellarRole,
        in cellar: Cellar,
        container: ModelContainer
    ) async throws {
        guard let share = try await getShare(for: cellar, in: container) else {
            throw SharingError.shareNotFound
        }

        isProcessingShare = true
        defer { isProcessingShare = false }

        // Find the CKShare.Participant
        guard let ckParticipant = share.participants.first(where: {
            $0.userIdentity.userRecordID?.recordName == participant.id
        }) else {
            throw SharingError.participantNotFound
        }

        // Update permission
        ckParticipant.permission = role.ckPermission

        // Save the share
        let database = cloudKitService.privateDatabase
        _ = try await database.save(share)
    }

    /// Remove a participant from a cellar
    func removeParticipant(
        _ participant: ShareParticipant,
        from cellar: Cellar,
        in container: ModelContainer
    ) async throws {
        guard let share = try await getShare(for: cellar, in: container) else {
            throw SharingError.shareNotFound
        }

        isProcessingShare = true
        defer { isProcessingShare = false }

        // Find the CKShare.Participant
        guard let ckParticipant = share.participants.first(where: {
            $0.userIdentity.userRecordID?.recordName == participant.id
        }) else {
            throw SharingError.participantNotFound
        }

        // Remove from share
        share.removeParticipant(ckParticipant)

        // Save the share
        let database = cloudKitService.privateDatabase
        _ = try await database.save(share)
    }

    // MARK: - Share Deletion

    /// Stop sharing a cellar
    func stopSharing(cellar: Cellar, in container: ModelContainer) async throws {
        guard let share = try await getShare(for: cellar, in: container) else {
            return
        }

        isProcessingShare = true
        defer { isProcessingShare = false }

        // Delete the share record
        let database = cloudKitService.privateDatabase
        try await database.deleteRecord(withID: share.recordID)

        // Update cellar
        cellar.isShared = false
        cellar.shareRecordData = nil
        cellar.updatedAt = Date()

        try container.mainContext.save()
    }

    // MARK: - Share URL Generation

    /// Generate a share URL for inviting participants
    func generateShareURL(for cellar: Cellar, in container: ModelContainer) async throws -> URL? {
        guard let share = try await getShare(for: cellar, in: container) else {
            throw SharingError.shareNotFound
        }

        return share.url
    }
}

// MARK: - Share Participant

/// Represents a participant in a shared cellar
struct ShareParticipant: Identifiable {
    let id: String
    let name: String
    let email: String?
    let role: CellarRole
    let acceptanceStatus: ParticipantStatus
    let isCurrentUser: Bool

    enum ParticipantStatus: String {
        case pending = "In attesa"
        case accepted = "Accettato"
        case removed = "Rimosso"
        case unknown = "Sconosciuto"
    }

    init(from participant: CKShare.Participant) {
        self.id = participant.userIdentity.userRecordID?.recordName ?? UUID().uuidString

        // Get name from participant
        if let nameComponents = participant.userIdentity.nameComponents {
            let formatter = PersonNameComponentsFormatter()
            self.name = formatter.string(from: nameComponents)
        } else {
            self.name = "Utente"
        }

        self.email = participant.userIdentity.lookupInfo?.emailAddress
        self.role = CellarRole.from(permission: participant.permission)
        self.isCurrentUser = participant.userIdentity.hasiCloudAccount

        switch participant.acceptanceStatus {
        case .pending:
            self.acceptanceStatus = .pending
        case .accepted:
            self.acceptanceStatus = .accepted
        case .removed:
            self.acceptanceStatus = .removed
        @unknown default:
            self.acceptanceStatus = .unknown
        }
    }

    init(
        id: String,
        name: String,
        email: String?,
        role: CellarRole,
        acceptanceStatus: ParticipantStatus,
        isCurrentUser: Bool
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.acceptanceStatus = acceptanceStatus
        self.isCurrentUser = isCurrentUser
    }

    var statusIcon: String {
        switch acceptanceStatus {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .removed: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var statusColor: Color {
        switch acceptanceStatus {
        case .pending: return .orange
        case .accepted: return .green
        case .removed: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Sharing Errors

enum SharingError: LocalizedError {
    case shareNotFound
    case userNotFound
    case participantNotFound
    case notAuthorized
    case networkError

    var errorDescription: String? {
        switch self {
        case .shareNotFound:
            return "Condivisione non trovata"
        case .userNotFound:
            return "Utente non trovato"
        case .participantNotFound:
            return "Partecipante non trovato"
        case .notAuthorized:
            return "Non autorizzato a questa operazione"
        case .networkError:
            return "Errore di rete"
        }
    }
}

// MARK: - UICloudSharingController Wrapper

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let cellar: Cellar

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowReadOnly]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(cellar: cellar)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let cellar: Cellar

        init(cellar: Cellar) {
            self.cellar = cellar
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            cellar.name
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            "Cantina"
        }
    }
}
