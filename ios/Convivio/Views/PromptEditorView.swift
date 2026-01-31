import SwiftUI

// MARK: - Prompt Editor View

struct PromptEditorView: View {
    let templateId: PromptTemplateService.TemplateID

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var promptService = PromptTemplateService.shared

    @State private var systemPrompt: String = ""
    @State private var userPrompt: String = ""
    @State private var showResetAlert = false
    @State private var showDiscardAlert = false
    @State private var showPlaceholders = false
    @State private var copiedPlaceholder: String?

    private var isCustomized: Bool {
        promptService.hasCustomTemplate(for: templateId)
    }

    private var hasChanges: Bool {
        let current = promptService.getTemplate(for: templateId)
        return systemPrompt != current.systemPrompt || userPrompt != current.userPromptTemplate
    }

    var body: some View {
        Form {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(templateId.displayName)
                        .font(.headline)

                    Text(templateId.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Label(templateId.recommendedModel, systemImage: "cpu")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if isCustomized {
                            Spacer()
                            Text("Personalizzato")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // System Prompt
            Section {
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 150)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("System Prompt")
            } footer: {
                Text("Istruzioni generali per l'AI. Definisce personalità e regole.")
            }

            // User Prompt Template
            Section {
                TextEditor(text: $userPrompt)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("User Prompt Template")
            } footer: {
                Text("Template con placeholder {variabile} sostituiti al runtime.")
            }

            // Available Placeholders
            Section {
                DisclosureGroup("Variabili disponibili", isExpanded: $showPlaceholders) {
                    ForEach(placeholders, id: \.name) { placeholder in
                        Button {
                            copyPlaceholder(placeholder.name)
                        } label: {
                            HStack {
                                Text("{\(placeholder.name)}")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(.purple)

                                Spacer()

                                Text(placeholder.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                if copiedPlaceholder == placeholder.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            } footer: {
                Text("Tap su una variabile per copiarla negli appunti.")
            }

            // Reset button (only if customized)
            if isCustomized {
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Ripristina default")
                        }
                    }
                } footer: {
                    Text("Ripristina il prompt ai valori originali.")
                }
            }
        }
        .navigationTitle("Editor Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        showDiscardAlert = true
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    savePrompt()
                }
                .disabled(!hasChanges)
                .fontWeight(.semibold)
            }
        }
        .alert("Ripristina default?", isPresented: $showResetAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina", role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text("Vuoi ripristinare questo prompt ai valori originali?")
        }
        .alert("Modifiche non salvate", isPresented: $showDiscardAlert) {
            Button("Continua a modificare", role: .cancel) {}
            Button("Scarta modifiche", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Hai delle modifiche non salvate. Vuoi scartarle?")
        }
        .onAppear {
            loadCurrentPrompt()
        }
    }

    // MARK: - Actions

    private func loadCurrentPrompt() {
        let template = promptService.getTemplate(for: templateId)
        systemPrompt = template.systemPrompt
        userPrompt = template.userPromptTemplate
    }

    private func savePrompt() {
        let template = PromptTemplateService.PromptTemplateData(
            systemPrompt: systemPrompt,
            userPromptTemplate: userPrompt
        )
        promptService.saveCustomTemplate(template, for: templateId)
        dismiss()
    }

    private func resetToDefault() {
        promptService.resetTemplate(for: templateId)
        loadCurrentPrompt()
    }

    private func copyPlaceholder(_ name: String) {
        UIPasteboard.general.string = "{\(name)}"
        copiedPlaceholder = name

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedPlaceholder == name {
                copiedPlaceholder = nil
            }
        }
    }

    // MARK: - Placeholders

    private struct PlaceholderInfo {
        let name: String
        let description: String
    }

    private var placeholders: [PlaceholderInfo] {
        switch templateId {
        case .menuCompleto:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "numeroOspiti", description: "Numero di ospiti"),
                PlaceholderInfo(name: "tipoCucina", description: "Tipo di cucina"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni alimentari"),
                PlaceholderInfo(name: "note", description: "Note aggiuntive"),
                PlaceholderInfo(name: "listaVini", description: "Vini in cantina")
            ]

        case .rigeneraPiatto:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "numeroOspiti", description: "Numero di ospiti"),
                PlaceholderInfo(name: "tipoCucina", description: "Tipo di cucina"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni alimentari"),
                PlaceholderInfo(name: "note", description: "Note aggiuntive"),
                PlaceholderInfo(name: "stagione", description: "Stagione corrente"),
                PlaceholderInfo(name: "categoria", description: "Categoria portata"),
                PlaceholderInfo(name: "nomePiatto", description: "Nome piatto da sostituire"),
                PlaceholderInfo(name: "listaAltriPiatti", description: "Altri piatti nel menu"),
                PlaceholderInfo(name: "listaVini", description: "Vini abbinati")
            ]

        case .suggerimentoSommelier:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "richiesta", description: "Piatto o occasione"),
                PlaceholderInfo(name: "preferenze", description: "Preferenze utente"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni"),
                PlaceholderInfo(name: "listaVini", description: "Vini in cantina")
            ]

        case .generaInvito:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "luogo", description: "Luogo della cena"),
                PlaceholderInfo(name: "dressCode", description: "Dress code"),
                PlaceholderInfo(name: "stile", description: "Stile invito"),
                PlaceholderInfo(name: "anticipazioni", description: "Anticipazioni menu"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni alimentari")
            ]

        case .noteRicette:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "numeroOspiti", description: "Numero di ospiti"),
                PlaceholderInfo(name: "tipoCucina", description: "Tipo di cucina"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni alimentari"),
                PlaceholderInfo(name: "note", description: "Note aggiuntive"),
                PlaceholderInfo(name: "menuCompleto", description: "Menu completo")
            ]

        case .noteVini:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "numeroOspiti", description: "Numero di ospiti"),
                PlaceholderInfo(name: "menuRiepilogo", description: "Riepilogo menu"),
                PlaceholderInfo(name: "listaViniConfermati", description: "Vini confermati")
            ]

        case .noteAccoglienza:
            return [
                PlaceholderInfo(name: "lingua", description: "Lingua dell'utente"),
                PlaceholderInfo(name: "citta", description: "Città dell'utente"),
                PlaceholderInfo(name: "paese", description: "Paese dell'utente"),
                PlaceholderInfo(name: "dataOra", description: "Data e ora della cena"),
                PlaceholderInfo(name: "numeroOspiti", description: "Numero di ospiti"),
                PlaceholderInfo(name: "tipoCucina", description: "Tipo di cucina"),
                PlaceholderInfo(name: "dressCode", description: "Dress code"),
                PlaceholderInfo(name: "restrizioni", description: "Restrizioni"),
                PlaceholderInfo(name: "note", description: "Note aggiuntive"),
                PlaceholderInfo(name: "menuRiepilogo", description: "Riepilogo menu")
            ]
        }
    }
}

#Preview {
    NavigationStack {
        PromptEditorView(templateId: .menuCompleto)
    }
}
