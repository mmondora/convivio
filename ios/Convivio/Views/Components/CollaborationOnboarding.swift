import SwiftUI
import UIKit

// MARK: - Collaboration Onboarding View

/// Onboarding sheet explaining collaboration features
struct CollaborationOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenCollaborationOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Collabora con gli Amici")
                            .font(.title.bold())

                        Text("Condividi la tua cantina e pianifica cene insieme")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Features
                    VStack(spacing: 24) {
                        OnboardingFeatureRow(
                            icon: "square.and.arrow.up",
                            iconColor: .blue,
                            title: "Condividi la Cantina",
                            description: "Invita amici e familiari a vedere e gestire la tua collezione di vini"
                        )

                        OnboardingFeatureRow(
                            icon: "person.2.badge.gearshape",
                            iconColor: .purple,
                            title: "Ruoli e Permessi",
                            description: "Owner, Member o Guest: ogni ruolo ha permessi diversi"
                        )

                        OnboardingFeatureRow(
                            icon: "fork.knife",
                            iconColor: .orange,
                            title: "Cene Collaborative",
                            description: "Proponi piatti, vota le proposte e pianifica il menu insieme"
                        )

                        OnboardingFeatureRow(
                            icon: "bubble.left.and.bubble.right",
                            iconColor: .green,
                            title: "Commenta e Discuti",
                            description: "Lascia commenti sulle proposte per discutere le scelte"
                        )

                        OnboardingFeatureRow(
                            icon: "icloud",
                            iconColor: .cyan,
                            title: "Sync Automatico",
                            description: "Tutto sincronizzato via iCloud tra tutti i partecipanti"
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Inizia") {
                        hasSeenOnboarding = true
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Onboarding Feature Row

struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Collaboration Tip Banner

/// Compact tip banner for collaboration features
struct CollaborationTipBanner: View {
    let tip: CollaborationTip
    var onDismiss: (() -> Void)? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title3)
                .foregroundColor(tip.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(.subheadline.bold())

                Text(tip.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onAction = onAction {
                Button(action: onAction) {
                    Text(tip.actionTitle)
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(tip.color)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(tip.color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Collaboration Tips

enum CollaborationTip: String, CaseIterable {
    case shareFirst
    case inviteFriends
    case proposeFirst
    case startVoting
    case finalizeMenu

    var icon: String {
        switch self {
        case .shareFirst: return "square.and.arrow.up"
        case .inviteFriends: return "person.badge.plus"
        case .proposeFirst: return "plus.bubble"
        case .startVoting: return "hand.thumbsup"
        case .finalizeMenu: return "checkmark.seal"
        }
    }

    var color: Color {
        switch self {
        case .shareFirst: return .blue
        case .inviteFriends: return .purple
        case .proposeFirst: return .orange
        case .startVoting: return .green
        case .finalizeMenu: return .cyan
        }
    }

    var title: String {
        switch self {
        case .shareFirst: return "Condividi la Cantina"
        case .inviteFriends: return "Invita Amici"
        case .proposeFirst: return "Proponi un Piatto"
        case .startVoting: return "Inizia la Votazione"
        case .finalizeMenu: return "Finalizza il Menu"
        }
    }

    var message: String {
        switch self {
        case .shareFirst: return "Condividi la cantina per pianificare cene insieme"
        case .inviteFriends: return "Aggiungi partecipanti alla cantina condivisa"
        case .proposeFirst: return "Sii il primo a proporre un piatto per la cena"
        case .startVoting: return "Le proposte sono pronte, è ora di votare!"
        case .finalizeMenu: return "I voti sono completi, conferma il menu finale"
        }
    }

    var actionTitle: String {
        switch self {
        case .shareFirst: return "Condividi"
        case .inviteFriends: return "Invita"
        case .proposeFirst: return "Proponi"
        case .startVoting: return "Vota"
        case .finalizeMenu: return "Finalizza"
        }
    }
}

// MARK: - Role Explanation Card

/// Card explaining a specific role's permissions
struct RoleExplanationCard: View {
    let role: CellarRole

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: role.icon)
                    .font(.title2)
                    .foregroundColor(roleColor)

                Text(role.displayName)
                    .font(.headline)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                PermissionRow(allowed: role.canEditWines, text: "Aggiungere e modificare vini")
                PermissionRow(allowed: role.canCreateDinners, text: "Creare e gestire cene")
                PermissionRow(allowed: role.canPropose, text: "Proporre piatti per le cene")
                PermissionRow(allowed: role.canVote, text: "Votare le proposte")
                PermissionRow(allowed: role.canComment, text: "Commentare le proposte")
                PermissionRow(allowed: role.canInviteOthers, text: "Invitare altri partecipanti")
                PermissionRow(allowed: role.canDeleteCellar, text: "Eliminare la cantina")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var roleColor: Color {
        switch role {
        case .owner: return .purple
        case .member: return .blue
        case .guest: return .green
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let allowed: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundColor(allowed ? .green : .secondary)

            Text(text)
                .font(.caption)
                .foregroundColor(allowed ? .primary : .secondary)

            Spacer()
        }
    }
}

// MARK: - Roles Overview View

/// Full view explaining all roles
struct RolesOverviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Quando condividi una cantina, puoi assegnare ruoli diversi ai partecipanti")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    ForEach(CellarRole.allCases, id: \.self) { role in
                        RoleExplanationCard(role: role)
                    }
                }
                .padding()
            }
            .navigationTitle("Ruoli e Permessi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    CollaborationOnboardingView()
}

#Preview("Tip Banner") {
    VStack(spacing: 16) {
        CollaborationTipBanner(
            tip: .shareFirst,
            onDismiss: {},
            onAction: {}
        )

        CollaborationTipBanner(
            tip: .proposeFirst,
            onAction: {}
        )
    }
    .padding()
}

#Preview("Role Card") {
    VStack(spacing: 16) {
        RoleExplanationCard(role: .owner)
        RoleExplanationCard(role: .member)
        RoleExplanationCard(role: .guest)
    }
    .padding()
}

#Preview("Roles Overview") {
    RolesOverviewView()
}
