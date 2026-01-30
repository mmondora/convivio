import SwiftUI
import SwiftData

// MARK: - Collaborative Dish View

/// View showing a dish proposal with voting and comments
struct CollaborativeDishView: View {
    @Environment(\.modelContext) private var modelContext

    let proposal: DishProposal
    let currentUserId: String
    let currentUserName: String
    let userRole: CellarRole

    @State private var showComments = false
    @State private var newComment = ""

    private var userVote: Vote? {
        proposal.getUserVote(userId: currentUserId)
    }

    private var hasUpvoted: Bool {
        userVote?.isUpvote == true
    }

    private var hasDownvoted: Bool {
        userVote?.isUpvote == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dish info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Dish name
                    Text(proposal.dishName)
                        .font(.headline)

                    // Description
                    if let description = proposal.dishDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Proposed by
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text("Proposto da \(proposal.proposedByName)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    // Wine suggestion
                    if let wine = proposal.wineSuggestion {
                        HStack(spacing: 4) {
                            Image(systemName: "wineglass")
                                .font(.caption2)
                            Text(wine)
                                .font(.caption)
                        }
                        .foregroundColor(.purple)
                    }
                }

                Spacer()

                // Status badge
                ProposalStatusBadge(status: proposal.status)
            }

            // Voting section
            if userRole.canVote {
                votingSection
            }

            // Comments preview
            if proposal.commentCount > 0 || userRole.canComment {
                commentsSection
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Voting Section

    private var votingSection: some View {
        HStack(spacing: 16) {
            // Upvote button
            Button {
                toggleVote(isUpvote: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: hasUpvoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(hasUpvoted ? .green : .secondary)
                    Text("\(proposal.upvoteCount)")
                        .font(.subheadline)
                        .foregroundColor(hasUpvoted ? .green : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasUpvoted ? Color.green.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Downvote button
            Button {
                toggleVote(isUpvote: false)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: hasDownvoted ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(hasDownvoted ? .red : .secondary)
                    Text("\(proposal.downvoteCount)")
                        .font(.subheadline)
                        .foregroundColor(hasDownvoted ? .red : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(hasDownvoted ? Color.red.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            // Score
            Text("Punteggio: \(proposal.score)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comments header
            Button {
                withAnimation {
                    showComments.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("\(proposal.commentCount) commenti")
                    Spacer()
                    Image(systemName: showComments ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Comments list
            if showComments {
                VStack(spacing: 8) {
                    ForEach(proposal.comments.sorted { $0.createdAt > $1.createdAt }) { comment in
                        CommentRow(comment: comment)
                    }

                    // Add comment input
                    if userRole.canComment {
                        HStack {
                            TextField("Aggiungi commento...", text: $newComment)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                addComment()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(newComment.isEmpty ? .secondary : .purple)
                            }
                            .disabled(newComment.isEmpty)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Actions

    private func toggleVote(isUpvote: Bool) {
        if let existingVote = userVote {
            if existingVote.isUpvote == isUpvote {
                // Remove vote
                modelContext.delete(existingVote)
            } else {
                // Change vote
                existingVote.isUpvote = isUpvote
            }
        } else {
            // Add new vote
            let vote = Vote(
                proposalId: proposal.id,
                voterId: currentUserId,
                voterName: currentUserName,
                isUpvote: isUpvote
            )
            vote.proposal = proposal
            modelContext.insert(vote)
        }

        try? modelContext.save()
    }

    private func addComment() {
        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let comment = Comment(
            proposalId: proposal.id,
            authorId: currentUserId,
            authorName: currentUserName,
            text: newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        comment.proposal = proposal
        modelContext.insert(comment)

        try? modelContext.save()
        newComment = ""
    }
}

// MARK: - Proposal Status Badge

struct ProposalStatusBadge: View {
    let status: ProposalStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(comment.authorName)
                    .font(.caption.bold())
                Spacer()
                Text(comment.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(comment.text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Compact Proposal Row

/// Compact view for proposal in a list
struct CompactProposalRow: View {
    let proposal: DishProposal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(proposal.dishName)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    Text(proposal.proposedByName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(proposal.upvoteCount)")
                    }
                    .font(.caption)
                    .foregroundColor(.green)

                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsdown")
                        Text("\(proposal.downvoteCount)")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            Spacer()

            ProposalStatusBadge(status: proposal.status)
        }
    }
}

// MARK: - Preview

#Preview {
    let proposal = DishProposal(
        dinnerId: "test",
        course: .primo,
        dishName: "Risotto ai funghi porcini",
        dishDescription: "Cremoso risotto con porcini freschi",
        proposedById: "user1",
        proposedByName: "Marco",
        wineSuggestion: "Nebbiolo d'Alba"
    )

    CollaborativeDishView(
        proposal: proposal,
        currentUserId: "user2",
        currentUserName: "Paolo",
        userRole: .member
    )
    .padding()
}
