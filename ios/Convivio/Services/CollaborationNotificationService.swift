import Foundation
import UserNotifications
import SwiftUI

// MARK: - Collaboration Notification Service

/// Handles local notifications for collaboration events
@MainActor
class CollaborationNotificationService: ObservableObject {
    static let shared = CollaborationNotificationService()

    // MARK: - Notification Categories

    enum NotificationCategory: String {
        case newProposal = "NEW_PROPOSAL"
        case newVote = "NEW_VOTE"
        case newComment = "NEW_COMMENT"
        case stateChanged = "STATE_CHANGED"
        case shareInvitation = "SHARE_INVITATION"
    }

    // MARK: - Published Properties

    @Published var pendingNotificationsCount: Int = 0
    @Published var hasPermission: Bool = false

    // MARK: - Initialization

    private init() {
        Task {
            await checkPermission()
        }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            hasPermission = granted
            if granted {
                await registerCategories()
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasPermission = settings.authorizationStatus == .authorized
    }

    // MARK: - Register Categories

    private func registerCategories() async {
        // New proposal category
        let viewProposalAction = UNNotificationAction(
            identifier: "VIEW_PROPOSAL",
            title: "Visualizza",
            options: [.foreground]
        )
        let proposalCategory = UNNotificationCategory(
            identifier: NotificationCategory.newProposal.rawValue,
            actions: [viewProposalAction],
            intentIdentifiers: []
        )

        // Vote category
        let upvoteAction = UNNotificationAction(
            identifier: "UPVOTE",
            title: "👍",
            options: []
        )
        let downvoteAction = UNNotificationAction(
            identifier: "DOWNVOTE",
            title: "👎",
            options: []
        )
        let voteCategory = UNNotificationCategory(
            identifier: NotificationCategory.newVote.rawValue,
            actions: [upvoteAction, downvoteAction],
            intentIdentifiers: []
        )

        // Comment category
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY",
            title: "Rispondi",
            options: [],
            textInputButtonTitle: "Invia",
            textInputPlaceholder: "Scrivi un commento..."
        )
        let commentCategory = UNNotificationCategory(
            identifier: NotificationCategory.newComment.rawValue,
            actions: [replyAction],
            intentIdentifiers: []
        )

        // Share invitation category
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_SHARE",
            title: "Accetta",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_SHARE",
            title: "Rifiuta",
            options: [.destructive]
        )
        let shareCategory = UNNotificationCategory(
            identifier: NotificationCategory.shareInvitation.rawValue,
            actions: [acceptAction, declineAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            proposalCategory,
            voteCategory,
            commentCategory,
            shareCategory
        ])
    }

    // MARK: - Send Notifications

    /// Notify about a new proposal
    func notifyNewProposal(
        proposalId: String,
        dishName: String,
        proposedBy: String,
        dinnerTitle: String
    ) async {
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "Nuova Proposta"
        content.subtitle = dinnerTitle
        content.body = "\(proposedBy) ha proposto: \(dishName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newProposal.rawValue
        content.userInfo = [
            "type": "proposal",
            "proposalId": proposalId,
            "dinnerTitle": dinnerTitle
        ]

        await scheduleNotification(content: content, identifier: "proposal-\(proposalId)")
    }

    /// Notify about a vote on your proposal
    func notifyNewVote(
        proposalId: String,
        dishName: String,
        voterName: String,
        isUpvote: Bool
    ) async {
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = isUpvote ? "👍 Nuovo voto positivo" : "👎 Nuovo voto"
        content.body = "\(voterName) ha votato \(isUpvote ? "positivamente" : "negativamente") per \(dishName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newVote.rawValue
        content.userInfo = [
            "type": "vote",
            "proposalId": proposalId,
            "isUpvote": isUpvote
        ]

        await scheduleNotification(content: content, identifier: "vote-\(UUID().uuidString)")
    }

    /// Notify about a new comment
    func notifyNewComment(
        proposalId: String,
        dishName: String,
        authorName: String,
        commentPreview: String
    ) async {
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "Nuovo Commento"
        content.subtitle = dishName
        content.body = "\(authorName): \(commentPreview)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newComment.rawValue
        content.userInfo = [
            "type": "comment",
            "proposalId": proposalId
        ]

        await scheduleNotification(content: content, identifier: "comment-\(UUID().uuidString)")
    }

    /// Notify about collaboration state change
    func notifyStateChanged(
        dinnerTitle: String,
        newState: CollaborationState,
        changedBy: String
    ) async {
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = dinnerTitle
        content.body = stateChangeMessage(newState: newState, changedBy: changedBy)
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.stateChanged.rawValue

        await scheduleNotification(content: content, identifier: "state-\(UUID().uuidString)")
    }

    /// Notify about share invitation
    func notifyShareInvitation(
        cellarName: String,
        inviterName: String
    ) async {
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "Invito alla Cantina"
        content.body = "\(inviterName) ti ha invitato a collaborare su \"\(cellarName)\""
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.shareInvitation.rawValue

        await scheduleNotification(content: content, identifier: "share-\(UUID().uuidString)")
    }

    // MARK: - Helper Methods

    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    private func stateChangeMessage(newState: CollaborationState, changedBy: String) -> String {
        switch newState {
        case .draft:
            return "\(changedBy) ha riportato il menu in bozza"
        case .openForProposals:
            return "\(changedBy) ha aperto le proposte - proponi i tuoi piatti!"
        case .voting:
            return "\(changedBy) ha aperto la votazione - vota i piatti preferiti!"
        case .finalized:
            return "\(changedBy) ha finalizzato il menu"
        }
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func clearNotifications(for proposalId: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
            "proposal-\(proposalId)"
        ])
    }
}

// MARK: - Notification Action Handler

extension CollaborationNotificationService {
    func handleNotificationAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any],
        responseText: String? = nil
    ) async {
        switch actionIdentifier {
        case "VIEW_PROPOSAL":
            // Navigate to proposal - handled by app
            break

        case "UPVOTE", "DOWNVOTE":
            // Vote action - would need context to perform
            if let proposalId = userInfo["proposalId"] as? String {
                print("Vote action for proposal: \(proposalId)")
                // This would need access to ModelContext to actually vote
            }

        case "REPLY":
            // Reply with text
            if let proposalId = userInfo["proposalId"] as? String,
               let text = responseText {
                print("Reply to proposal \(proposalId): \(text)")
                // This would need access to ModelContext to add comment
            }

        case "ACCEPT_SHARE":
            // Accept share invitation
            print("Accept share invitation")
            // Handled by SharingService

        case "DECLINE_SHARE":
            // Decline share invitation
            print("Decline share invitation")
            // Handled by SharingService

        default:
            break
        }
    }
}
