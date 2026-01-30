import Foundation
import CloudKit
import SwiftUI
import Combine

// MARK: - CloudKit Service

/// Manages CloudKit container, sync status, and subscriptions
@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    // MARK: - Published Properties

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var iCloudAvailable: Bool = false
    @Published var currentUserRecordID: CKRecord.ID?
    @Published var currentUserName: String?

    // MARK: - Private Properties

    private let containerIdentifier = "iCloud.com.mikesoft.convivio"
    private(set) lazy var container = CKContainer(identifier: containerIdentifier)
    private(set) lazy var privateDatabase = container.privateCloudDatabase
    private(set) lazy var sharedDatabase = container.sharedCloudDatabase

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case error(String)
        case offline

        var displayName: String {
            switch self {
            case .idle: return "In attesa"
            case .syncing: return "Sincronizzazione..."
            case .synced: return "Sincronizzato"
            case .error(let message): return "Errore: \(message)"
            case .offline: return "Offline"
            }
        }

        var icon: String {
            switch self {
            case .idle: return "cloud"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .offline: return "icloud.slash"
            }
        }

        var color: Color {
            switch self {
            case .idle: return .secondary
            case .syncing: return .orange
            case .synced: return .green
            case .error: return .red
            case .offline: return .gray
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Only setup notifications if CloudKit is enabled
        if FeatureFlags.cloudKitEnabled {
            setupNotifications()
        } else {
            syncStatus = .offline
        }
    }

    // MARK: - Public Methods

    /// Check iCloud account status
    func checkiCloudStatus() async {
        // Skip if CloudKit is disabled
        guard FeatureFlags.cloudKitEnabled else {
            iCloudAvailable = false
            syncStatus = .offline
            return
        }

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                iCloudAvailable = true
                syncStatus = .idle
                await fetchCurrentUser()
            case .noAccount:
                iCloudAvailable = false
                syncStatus = .error("Nessun account iCloud")
            case .restricted:
                iCloudAvailable = false
                syncStatus = .error("iCloud limitato")
            case .couldNotDetermine:
                iCloudAvailable = false
                syncStatus = .error("Stato iCloud sconosciuto")
            case .temporarilyUnavailable:
                iCloudAvailable = false
                syncStatus = .offline
            @unknown default:
                iCloudAvailable = false
                syncStatus = .error("Stato iCloud non supportato")
            }
        } catch {
            iCloudAvailable = false
            syncStatus = .error(error.localizedDescription)
            print("CloudKit error: \(error)")
        }
    }

    /// Get current user's CloudKit record ID
    func getCurrentUserRecordID() async throws -> CKRecord.ID {
        let recordID = try await container.userRecordID()
        currentUserRecordID = recordID
        return recordID
    }

    /// Fetch current user info
    func fetchCurrentUser() async {
        do {
            let recordID = try await getCurrentUserRecordID()

            // Try to get user's name from CloudKit
            let identity = try await container.userIdentity(forUserRecordID: recordID)
            if let nameComponents = identity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                currentUserName = formatter.string(from: nameComponents)
            }
        } catch {
            print("Could not fetch user info: \(error)")
        }
    }

    /// Subscribe to CloudKit changes for delta sync
    func subscribeToChanges() async throws {
        // Subscribe to private database changes
        let privateSubscription = CKDatabaseSubscription(subscriptionID: "private-changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        privateSubscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(privateSubscription)
            print("Subscribed to private database changes")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription might already exist
            print("Subscription might already exist: \(error)")
        }

        // Subscribe to shared database changes
        let sharedSubscription = CKDatabaseSubscription(subscriptionID: "shared-changes")
        sharedSubscription.notificationInfo = notificationInfo

        do {
            _ = try await sharedDatabase.save(sharedSubscription)
            print("Subscribed to shared database changes")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            print("Shared subscription might already exist: \(error)")
        }
    }

    /// Subscribe to collaboration-specific notifications
    func subscribeToCollaborationChanges() async throws {
        // These subscriptions will trigger local notifications for collaboration events
        // SwiftData + CloudKit handles the actual data sync automatically

        // Subscription for new proposals in shared dinners
        try await createSubscriptionIfNeeded(
            subscriptionID: "new-proposals",
            recordType: "CD_DishProposal",
            alertTitle: "Nuova Proposta",
            alertBody: "Qualcuno ha proposto un nuovo piatto"
        )

        // Subscription for new votes
        try await createSubscriptionIfNeeded(
            subscriptionID: "new-votes",
            recordType: "CD_Vote",
            alertTitle: "Nuovo Voto",
            alertBody: "Qualcuno ha votato una proposta"
        )

        // Subscription for new comments
        try await createSubscriptionIfNeeded(
            subscriptionID: "new-comments",
            recordType: "CD_Comment",
            alertTitle: "Nuovo Commento",
            alertBody: "Qualcuno ha commentato una proposta"
        )
    }

    private func createSubscriptionIfNeeded(
        subscriptionID: String,
        recordType: String,
        alertTitle: String,
        alertBody: String
    ) async throws {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertLocalizationKey = alertTitle
        notificationInfo.alertBody = alertBody
        notificationInfo.soundName = "default"

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await sharedDatabase.save(subscription)
            print("Created subscription: \(subscriptionID)")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists
            print("Subscription \(subscriptionID) already exists")
        }
    }

    /// Handle incoming CloudKit notification
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }

        switch notification.notificationType {
        case .database:
            // Database changed, trigger sync
            Task {
                await triggerSync()
            }
        case .recordZone:
            // Zone changed
            Task {
                await triggerSync()
            }
        default:
            break
        }
    }

    /// Manually trigger a sync
    func triggerSync() async {
        guard iCloudAvailable else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        // SwiftData with CloudKit handles sync automatically
        // This is mainly for UI feedback and manual refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second visual feedback

        lastSyncDate = Date()
        syncStatus = .synced

        // Reset to idle after a few seconds
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if case .synced = syncStatus {
            syncStatus = .idle
        }
    }

    /// Get record zone for a cellar
    func getRecordZone(for cellarId: String) -> CKRecordZone {
        CKRecordZone(zoneName: "cellar-\(cellarId)")
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        // Listen for account status changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.checkiCloudStatus()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - CloudKit Error Helpers

extension CKError {
    var isRetryable: Bool {
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .zoneBusy, .requestRateLimited:
            return true
        default:
            return false
        }
    }

    var retryAfterSeconds: Double? {
        userInfo[CKErrorRetryAfterKey] as? Double
    }

    var localizedUserMessage: String {
        switch code {
        case .networkUnavailable, .networkFailure:
            return "Connessione non disponibile"
        case .notAuthenticated:
            return "Accedi a iCloud per sincronizzare"
        case .quotaExceeded:
            return "Spazio iCloud esaurito"
        case .serverRejectedRequest:
            return "Richiesta rifiutata dal server"
        case .assetFileNotFound:
            return "File non trovato"
        case .incompatibleVersion:
            return "Aggiorna l'app per continuare"
        default:
            return localizedDescription
        }
    }
}
