import SwiftUI

// MARK: - Generic Empty State View

/// Reusable empty state view for various contexts
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - Shared Cellar Empty State

/// Empty state for a shared cellar with no wines yet
struct SharedCellarEmptyState: View {
    let cellarName: String
    let isOwner: Bool
    var onAddWine: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Collaborative icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }

            VStack(spacing: 8) {
                Text("Cantina Condivisa")
                    .font(.title3.bold())

                Text(cellarName)
                    .font(.headline)
                    .foregroundColor(.purple)

                if isOwner {
                    Text("Aggiungi i primi vini per iniziare a costruire la cantina insieme ai tuoi collaboratori")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("L'owner non ha ancora aggiunto vini. Torna più tardi o chiedi all'owner di aggiungere qualche bottiglia!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if isOwner, let onAddWine = onAddWine {
                Button(action: onAddWine) {
                    Label("Aggiungi Vino", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - Collaboration Empty State

/// Empty state for dinner with no proposals yet
struct CollaborationEmptyState: View {
    let canPropose: Bool
    var onPropose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.orange.opacity(0.6))

            VStack(spacing: 8) {
                Text("Nessuna Proposta")
                    .font(.headline)

                if canPropose {
                    Text("Sii il primo a proporre un piatto per questa cena!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Non ci sono ancora proposte per questa cena")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if canPropose, let onPropose = onPropose {
                Button(action: onPropose) {
                    Label("Proponi Piatto", systemImage: "plus.bubble")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - No Shared Cellars Empty State

/// Empty state when user has no shared cellars
struct NoSharedCellarsEmptyState: View {
    var onCreateCellar: (() -> Void)? = nil
    var onLearnMore: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 12) {
                Text("Condividi la Tua Cantina")
                    .font(.title2.bold())

                Text("Invita amici e familiari a collaborare sulla cantina. Potrete gestire insieme i vini e pianificare cene collaborative.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if let onCreateCellar = onCreateCellar {
                    Button(action: onCreateCellar) {
                        Label("Condividi Cantina", systemImage: "person.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }

                if let onLearnMore = onLearnMore {
                    Button(action: onLearnMore) {
                        Text("Scopri di più")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(32)
    }
}

// MARK: - Offline Empty State

/// Empty state when offline and no local data
struct OfflineEmptyState: View {
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("Sei Offline")
                    .font(.headline)

                Text("Connettiti a Internet per sincronizzare i dati con iCloud")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label("Riprova", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
    }
}

// MARK: - Sync Error State

/// Error state for sync issues with retry
struct SyncErrorState: View {
    let errorMessage: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 48))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Errore di Sincronizzazione")
                    .font(.headline)

                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label("Riprova", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "wineglass",
        title: "Nessun Vino",
        message: "La tua cantina è vuota. Aggiungi il primo vino!",
        actionTitle: "Aggiungi Vino"
    ) {
        print("Add wine")
    }
}

#Preview("Shared Cellar Empty") {
    SharedCellarEmptyState(
        cellarName: "Cantina Famiglia",
        isOwner: true
    ) {
        print("Add wine")
    }
}

#Preview("Collaboration Empty") {
    CollaborationEmptyState(
        canPropose: true
    ) {
        print("Propose")
    }
    .padding()
}

#Preview("No Shared Cellars") {
    NoSharedCellarsEmptyState(
        onCreateCellar: { print("Create") },
        onLearnMore: { print("Learn") }
    )
}

#Preview("Offline") {
    OfflineEmptyState {
        print("Retry")
    }
}

#Preview("Sync Error") {
    SyncErrorState(
        errorMessage: "Impossibile connettersi a iCloud"
    ) {
        print("Retry")
    }
}
