import SwiftUI
import SwiftData
import CloudKit

// MARK: - Share Management View

/// View for managing cellar sharing and participants
struct ShareManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let cellar: Cellar

    @StateObject private var sharingService = SharingService.shared
    @ObservedObject var cellarManager = CellarManager.shared

    @State private var participants: [ShareParticipant] = []
    @State private var isLoading = true
    @State private var showInviteSheet = false
    @State private var showCloudSharingSheet = false
    @State private var shareURL: URL?
    @State private var share: CKShare?
    @State private var errorMessage: String?

    private var isOwner: Bool {
        cellarManager.getUserRole(for: cellar) == .owner
    }

    var body: some View {
        NavigationStack {
            List {
                // Share status section
                Section {
                    shareStatusView
                } header: {
                    Text("Stato Condivisione")
                }

                // Participants section
                if cellar.isShared {
                    Section {
                        if participants.isEmpty && !isLoading {
                            Text("Nessun partecipante")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(participants) { participant in
                                ParticipantRow(
                                    participant: participant,
                                    isOwner: isOwner,
                                    onRoleChange: { newRole in
                                        Task {
                                            await updateParticipantRole(participant, to: newRole)
                                        }
                                    },
                                    onRemove: {
                                        Task {
                                            await removeParticipant(participant)
                                        }
                                    }
                                )
                            }
                        }
                    } header: {
                        Text("Partecipanti")
                    }

                    // Invite section
                    if isOwner {
                        Section {
                            Button {
                                showCloudSharingSheet = true
                            } label: {
                                Label("Invita Partecipanti", systemImage: "person.badge.plus")
                            }

                            if let url = shareURL {
                                ShareLink(item: url) {
                                    Label("Condividi Link", systemImage: "link")
                                }
                            }
                        } header: {
                            Text("Invita")
                        }
                    }
                }

                // Stop sharing section
                if isOwner && cellar.isShared {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await stopSharing()
                            }
                        } label: {
                            Label("Interrompi Condivisione", systemImage: "xmark.circle")
                        }
                    }
                }

                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Condivisione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadShareData()
            }
            .sheet(isPresented: $showCloudSharingSheet) {
                if let share = share {
                    CloudSharingView(
                        share: share,
                        container: CloudKitService.shared.container,
                        cellar: cellar
                    )
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Share Status View

    @ViewBuilder
    private var shareStatusView: some View {
        if cellar.isShared {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("Cantina Condivisa")
                        .font(.headline)
                    Text("\(participants.count) partecipanti")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Cantina Privata")
                        .font(.headline)
                }

                if isOwner {
                    Text("Condividi questa cantina per permettere ad altri di visualizzare e modificare i tuoi vini.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        Task {
                            await startSharing()
                        }
                    } label: {
                        Label("Inizia a Condividere", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sharingService.isProcessingShare)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadShareData() async {
        isLoading = true
        errorMessage = nil

        do {
            let container = modelContext.container
            share = try await sharingService.getShare(for: cellar, in: container)
            participants = try await sharingService.getParticipants(for: cellar, in: container)
            shareURL = try await sharingService.generateShareURL(for: cellar, in: container)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startSharing() async {
        errorMessage = nil

        do {
            let container = modelContext.container
            share = try await sharingService.createShare(for: cellar, in: container)
            showCloudSharingSheet = true
            await loadShareData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopSharing() async {
        errorMessage = nil

        do {
            let container = modelContext.container
            try await sharingService.stopSharing(cellar: cellar, in: container)
            participants = []
            share = nil
            shareURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateParticipantRole(_ participant: ShareParticipant, to role: CellarRole) async {
        errorMessage = nil

        do {
            let container = modelContext.container
            try await sharingService.updatePermission(
                for: participant,
                to: role,
                in: cellar,
                container: container
            )
            await loadShareData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeParticipant(_ participant: ShareParticipant) async {
        errorMessage = nil

        do {
            let container = modelContext.container
            try await sharingService.removeParticipant(participant, from: cellar, in: container)
            await loadShareData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let participant: ShareParticipant
    let isOwner: Bool
    let onRoleChange: (CellarRole) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            // Avatar and info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(participant.name)
                        .font(.headline)
                    if participant.isCurrentUser {
                        Text("(tu)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    // Role badge
                    Label(participant.role.displayName, systemImage: participant.role.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Status badge
                    HStack(spacing: 2) {
                        Image(systemName: participant.statusIcon)
                        Text(participant.acceptanceStatus.rawValue)
                    }
                    .font(.caption2)
                    .foregroundColor(participant.statusColor)
                }
            }

            Spacer()

            // Actions for owner
            if isOwner && !participant.isCurrentUser {
                Menu {
                    // Role options
                    ForEach(CellarRole.allCases.filter { $0 != .owner }) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            HStack {
                                Text(role.displayName)
                                if participant.role == role {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Rimuovi", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ShareManagementView(cellar: Cellar(name: "Test Cantina"))
        .modelContainer(for: Cellar.self, inMemory: true)
}
