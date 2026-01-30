import Foundation
import SwiftData

// MARK: - Collaboration State

/// States for collaborative menu planning
enum CollaborationState: String, Codable, CaseIterable, Identifiable {
    case draft = "draft"                    // Solo owner può modificare
    case openForProposals = "proposals"     // Membri possono proporre piatti
    case voting = "voting"                  // Votazione aperta
    case finalized = "finalized"            // Menu confermato

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Bozza"
        case .openForProposals: return "Proposte Aperte"
        case .voting: return "Votazione"
        case .finalized: return "Finalizzato"
        }
    }

    var description: String {
        switch self {
        case .draft:
            return "Solo il proprietario può modificare il menu"
        case .openForProposals:
            return "I partecipanti possono proporre piatti"
        case .voting:
            return "Vota i piatti preferiti"
        case .finalized:
            return "Menu confermato"
        }
    }

    var icon: String {
        switch self {
        case .draft: return "pencil"
        case .openForProposals: return "plus.bubble"
        case .voting: return "hand.thumbsup"
        case .finalized: return "checkmark.seal"
        }
    }

    var color: String {
        switch self {
        case .draft: return "gray"
        case .openForProposals: return "blue"
        case .voting: return "orange"
        case .finalized: return "green"
        }
    }

    /// Can transition to this state
    func canTransitionTo(_ state: CollaborationState) -> Bool {
        switch (self, state) {
        case (.draft, .openForProposals),
             (.draft, .voting),
             (.draft, .finalized),
             (.openForProposals, .voting),
             (.openForProposals, .finalized),
             (.voting, .finalized),
             (.voting, .openForProposals),
             (.finalized, .draft):
            return true
        default:
            return false
        }
    }
}

// MARK: - Dish Proposal

/// A dish proposed by a participant for a dinner menu
@Model
final class DishProposal {
    var id: String = UUID().uuidString
    var dinnerId: String              // Reference to DinnerEvent
    var courseRaw: String             // CourseType rawValue
    var dishName: String
    var dishDescription: String?
    var proposedById: String          // CloudKit user record ID
    var proposedByName: String
    var wineSuggestion: String?       // Optional wine pairing suggestion
    var statusRaw: String = "pending"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships
    var dinner: DinnerEvent?

    @Relationship(deleteRule: .cascade, inverse: \Vote.proposal)
    var votes: [Vote] = []

    @Relationship(deleteRule: .cascade, inverse: \Comment.proposal)
    var comments: [Comment] = []

    // Computed properties
    var course: CourseType {
        get { CourseType(rawValue: courseRaw) ?? .primo }
        set { courseRaw = newValue.rawValue }
    }

    var status: ProposalStatus {
        get { ProposalStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var upvoteCount: Int {
        votes.filter { $0.isUpvote }.count
    }

    var downvoteCount: Int {
        votes.filter { !$0.isUpvote }.count
    }

    var score: Int {
        upvoteCount - downvoteCount
    }

    var commentCount: Int {
        comments.count
    }

    init(
        dinnerId: String,
        course: CourseType,
        dishName: String,
        dishDescription: String? = nil,
        proposedById: String,
        proposedByName: String,
        wineSuggestion: String? = nil
    ) {
        self.id = UUID().uuidString
        self.dinnerId = dinnerId
        self.courseRaw = course.rawValue
        self.dishName = dishName
        self.dishDescription = dishDescription
        self.proposedById = proposedById
        self.proposedByName = proposedByName
        self.wineSuggestion = wineSuggestion
        self.statusRaw = ProposalStatus.pending.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Check if user has voted
    func hasVoted(userId: String) -> Bool {
        votes.contains { $0.odishProposalId == userId }
    }

    /// Get user's vote
    func getUserVote(userId: String) -> Vote? {
        votes.first { $0.voterId == userId }
    }
}

// MARK: - Proposal Status

enum ProposalStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "In attesa"
        case .accepted: return "Accettata"
        case .rejected: return "Rifiutata"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .rejected: return "red"
        }
    }
}

// MARK: - Vote

/// A vote on a dish proposal
@Model
final class Vote {
    var id: String = UUID().uuidString
    var odishProposalId: String       // Reference to DishProposal (typo kept for compatibility)
    var voterId: String               // CloudKit user record ID
    var voterName: String
    var isUpvote: Bool                // true = 👍, false = 👎
    var createdAt: Date = Date()

    // Relationship
    var proposal: DishProposal?

    init(
        proposalId: String,
        voterId: String,
        voterName: String,
        isUpvote: Bool
    ) {
        self.id = UUID().uuidString
        self.odishProposalId = proposalId
        self.voterId = voterId
        self.voterName = voterName
        self.isUpvote = isUpvote
        self.createdAt = Date()
    }
}

// MARK: - Comment

/// A comment on a dish proposal
@Model
final class Comment {
    var id: String = UUID().uuidString
    var dishProposalId: String        // Reference to DishProposal
    var authorId: String              // CloudKit user record ID
    var authorName: String
    var text: String
    var createdAt: Date = Date()

    // Relationship
    var proposal: DishProposal?

    init(
        proposalId: String,
        authorId: String,
        authorName: String,
        text: String
    ) {
        self.id = UUID().uuidString
        self.dishProposalId = proposalId
        self.authorId = authorId
        self.authorName = authorName
        self.text = text
        self.createdAt = Date()
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Collaboration Summary

/// Summary of collaboration activity for a dinner
struct CollaborationSummary {
    let proposals: [DishProposal]
    let state: CollaborationState

    var totalProposals: Int { proposals.count }

    var pendingProposals: Int {
        proposals.filter { $0.status == .pending }.count
    }

    var acceptedProposals: Int {
        proposals.filter { $0.status == .accepted }.count
    }

    var totalVotes: Int {
        proposals.reduce(0) { $0 + $1.votes.count }
    }

    var totalComments: Int {
        proposals.reduce(0) { $0 + $1.comments.count }
    }

    var proposalsByCourse: [CourseType: [DishProposal]] {
        Dictionary(grouping: proposals) { $0.course }
    }

    var topProposals: [DishProposal] {
        proposals.sorted { $0.score > $1.score }
    }

    /// Get proposals for a specific course, sorted by score
    func proposals(for course: CourseType) -> [DishProposal] {
        proposals
            .filter { $0.course == course }
            .sorted { $0.score > $1.score }
    }

    /// Get the winning proposal for a course (highest score)
    func winningProposal(for course: CourseType) -> DishProposal? {
        proposals(for: course).first
    }
}

// MARK: - Collaboration Permissions

extension CellarRole {
    // canVote, canComment, canPropose are defined in CloudKitModels.swift

    var canAcceptProposals: Bool {
        self == .owner
    }

    var canChangeCollaborationState: Bool {
        self == .owner
    }

    var canDeleteProposals: Bool {
        self == .owner
    }
}
