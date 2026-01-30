import SwiftUI
import SwiftData
import CloudKit

// MARK: - Share Management View

/// View for managing cellar sharing and participants
/// Note: Full functionality requires CloudKit to be enabled
struct ShareManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let cellar: Cellar

    @StateObject private var sharingService = SharingService.shared

    @State private var participants: [ShareParticipant] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if FeatureFlags.cloudKitEnabled {
                    sharingContent
                } else {
                    cloudKitDisabledContent
                }
            }
            .navigationTitle("Condivisione")
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

    // MARK: - CloudKit Disabled Content

    private var cloudKitDisabledContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("CloudKit Non Disponibile")
                    .font(.title2.bold())

                Text("La condivisione delle cantine richiede iCloud.\n\nQuesta funzionalità sarà disponibile presto.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Sharing Content

    private var sharingContent: some View {
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
                            ParticipantRow(participant: participant)
                        }
                    }
                } header: {
                    Text("Partecipanti")
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
        .task {
            await loadShareData()
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
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading) {
                    Text("Cantina Privata")
                        .font(.headline)
                    Text("Solo tu puoi accedere")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Button {
                Task {
                    await startSharing()
                }
            } label: {
                Label("Condividi Cantina", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Actions

    private func loadShareData() async {
        isLoading = true
        errorMessage = nil

        let container = modelContext.container
        participants = await sharingService.getParticipants(for: cellar, in: container)

        isLoading = false
    }

    private func startSharing() async {
        errorMessage = nil

        do {
            let container = modelContext.container
            _ = try await sharingService.createShare(for: cellar, in: container)
            await loadShareData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let participant: ShareParticipant

    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(participant.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.purple)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.subheadline)

                HStack(spacing: 4) {
                    Text(participant.role.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if participant.acceptanceStatus == .pending {
                        Text("• In attesa")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Role badge
            Text(participant.role.icon)
                .font(.title3)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Cellar.self, configurations: config)

    let cellar = Cellar(name: "Cantina Test")
    container.mainContext.insert(cellar)

    return ShareManagementView(cellar: cellar)
        .modelContainer(container)
}
