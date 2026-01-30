import Foundation
import CloudKit
import SwiftUI
import SwiftData

// MARK: - Sharing Service

/// Manages CloudKit sharing for collaborative cellars
/// Note: Full functionality requires CloudKit to be enabled via FeatureFlags
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
    /// Note: Requires CloudKit to be enabled
    func createShare(for cellar: Cellar, in container: ModelContainer) async throws -> CKShare? {
        guard FeatureFlags.cloudKitEnabled else {
            shareError = "CloudKit non è abilitato"
            return nil
        }

        isProcessingShare = true
        shareError = nil
        defer { isProcessingShare = false }

        // CloudKit sharing will be implemented when CloudKit is enabled
        // For now, mark cellar as shared locally
        cellar.isShared = true
        cellar.updatedAt = Date()

        return nil
    }

    /// Get the share for a cellar
    func getShare(for cellar: Cellar, in container: ModelContainer) async throws -> CKShare? {
        guard FeatureFlags.cloudKitEnabled else {
            return nil
        }

        // Will be implemented when CloudKit is enabled
        return nil
    }

    /// Accept a share invitation
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard FeatureFlags.cloudKitEnabled else {
            shareError = "CloudKit non è abilitato"
            return
        }

        isProcessingShare = true
        defer { isProcessingShare = false }

        do {
            let container = cloudKitService.container
            _ = try await container.accept(metadata)
            // Remove from pending
            pendingInvitations.removeAll { $0.share.recordID == metadata.share.recordID }
        } catch {
            shareError = error.localizedDescription
            throw error
        }
    }

    /// Get participants for a cellar
    func getParticipants(for cellar: Cellar, in container: ModelContainer) async -> [ShareParticipant] {
        guard FeatureFlags.cloudKitEnabled else {
            return []
        }

        // Will be implemented when CloudKit is enabled
        return []
    }

    /// Remove a participant from the share
    func removeParticipant(
        _ participant: ShareParticipant,
        from cellar: Cellar,
        in container: ModelContainer
    ) async throws {
        guard FeatureFlags.cloudKitEnabled else {
            shareError = "CloudKit non è abilitato"
            return
        }

        // Will be implemented when CloudKit is enabled
    }

    /// Stop sharing a cellar
    func stopSharing(cellar: Cellar, in container: ModelContainer) async throws {
        cellar.isShared = false
        cellar.shareRecordData = nil
        cellar.updatedAt = Date()
    }

    /// Get role for current user in a cellar
    func getCurrentUserRole(for cellar: Cellar) -> CellarRole {
        // If not using CloudKit, user is always owner of their local cellars
        guard FeatureFlags.cloudKitEnabled else {
            return .owner
        }

        guard let currentUserID = cloudKitService.currentUserRecordID?.recordName else {
            return .guest
        }

        if cellar.ownerId == currentUserID {
            return .owner
        }

        // Would check share participants for actual role
        return .member
    }
}

// MARK: - Share Participant Model

struct ShareParticipant: Identifiable {
    let id: String
    let name: String
    let email: String?
    let role: CellarRole
    let acceptanceStatus: AcceptanceStatus

    enum AcceptanceStatus {
        case pending
        case accepted
        case removed
    }
}

// MARK: - Sharing Errors

enum SharingError: LocalizedError {
    case cloudKitDisabled
    case shareNotFound
    case notOwner
    case userNotFound
    case alreadyShared

    var errorDescription: String? {
        switch self {
        case .cloudKitDisabled:
            return "CloudKit non è abilitato"
        case .shareNotFound:
            return "Condivisione non trovata"
        case .notOwner:
            return "Solo il proprietario può modificare la condivisione"
        case .userNotFound:
            return "Utente non trovato"
        case .alreadyShared:
            return "La cantina è già condivisa"
        }
    }
}

// MARK: - CloudKit Sharing View (UIKit wrapper)

#if canImport(UIKit)
import UIKit

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
    }
}
#endif
