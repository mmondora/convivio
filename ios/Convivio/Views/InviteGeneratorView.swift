import SwiftUI

struct InviteGeneratorView: View {
    @Environment(\.dismiss) private var dismiss

    let dinner: DinnerEvent

    @State private var inviteMessage: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var includeMenu = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Options
                    optionsSection

                    // Generated invite
                    if !inviteMessage.isEmpty {
                        invitePreviewSection
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Genera Invito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [inviteMessage])
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Invito per \(dinner.title)")
                .font(.headline)

            HStack {
                Label(formatDate(dinner.date), systemImage: "calendar")
                Label(formatTime(dinner.date), systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opzioni")
                .font(.headline)

            Toggle(isOn: $includeMenu) {
                VStack(alignment: .leading) {
                    Text("Includi anteprima menu")
                        .font(.subheadline)
                    Text("Aggiunge un accenno ai piatti previsti")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Invite Preview Section

    private var invitePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Anteprima Invito")
                    .font(.headline)

                Spacer()

                Button {
                    UIPasteboard.general.string = inviteMessage
                } label: {
                    Label("Copia", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .tint(.blue)
            }

            Text(inviteMessage)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Generate button
            Button {
                Task { await generateInvite() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: inviteMessage.isEmpty ? "sparkles" : "arrow.clockwise")
                    }
                    Text(isGenerating ? "Generazione..." : (inviteMessage.isEmpty ? "Genera Invito" : "Rigenera Invito"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGenerating ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isGenerating)

            // Share button (only if invite exists)
            if !inviteMessage.isEmpty {
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Condividi Invito")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Actions

    private func generateInvite() async {
        isGenerating = true
        errorMessage = nil

        do {
            let menu = includeMenu ? dinner.menuResponse : nil
            let message = try await MenuGeneratorService.shared.generateInviteMessage(
                for: dinner,
                menu: menu
            )

            await MainActor.run {
                inviteMessage = message
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
