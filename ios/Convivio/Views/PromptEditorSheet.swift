import SwiftUI

// MARK: - Prompt Editor Sheet

/// Sheet view for editing prompts in debug mode
struct PromptEditorSheet: View {
    @ObservedObject var interceptionService = PromptInterceptionService.shared
    @State private var editedSystemPrompt: String = ""
    @State private var editedUserPrompt: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // System Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("System Prompt", systemImage: "gearshape")
                                .font(.headline)
                            Spacer()
                            Text("\(editedSystemPrompt.count) chars")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        TextEditor(text: $editedSystemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // User Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("User Prompt", systemImage: "text.bubble")
                                .font(.headline)
                            Spacer()
                            Text("\(editedUserPrompt.count) chars")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        TextEditor(text: $editedUserPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 250)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Info section
                    if let identifier = interceptionService.currentIdentifier {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Tipo: \(identifier.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        interceptionService.cancelPrompt()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invia") {
                        let config = PromptConfiguration(
                            systemPrompt: editedSystemPrompt,
                            userPrompt: editedUserPrompt
                        )
                        interceptionService.submitPrompt(config)
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            resetToDefault()
                        } label: {
                            Label("Ripristina default", systemImage: "arrow.counterclockwise")
                        }

                        Spacer()

                        // Modified indicator
                        if isModified {
                            Label("Modificato", systemImage: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .onAppear {
                loadCurrentPrompt()
            }
            .onChange(of: interceptionService.currentPrompt) {
                loadCurrentPrompt()
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(true)
    }

    // MARK: - Private Methods

    private func loadCurrentPrompt() {
        if let prompt = interceptionService.currentPrompt {
            editedSystemPrompt = prompt.systemPrompt
            editedUserPrompt = prompt.userPrompt
        }
    }

    private func resetToDefault() {
        interceptionService.resetToDefault()
        loadCurrentPrompt()
    }

    private var isModified: Bool {
        guard let original = interceptionService.currentPrompt else { return false }
        return editedSystemPrompt != original.systemPrompt || editedUserPrompt != original.userPrompt
    }
}

#Preview {
    PromptEditorSheet()
}
