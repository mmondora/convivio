import SwiftUI

// MARK: - Prompt Configuration List View

struct PromptConfigurationListView: View {
    @ObservedObject private var promptService = PromptTemplateService.shared
    @State private var showResetAllAlert = false

    var body: some View {
        List {
            Section {
                ForEach(PromptTemplateService.TemplateID.allCases, id: \.rawValue) { templateId in
                    NavigationLink {
                        PromptEditorView(templateId: templateId)
                    } label: {
                        PromptRowView(
                            templateId: templateId,
                            isCustomized: promptService.hasCustomTemplate(for: templateId)
                        )
                    }
                }
            } header: {
                Text("Prompt Configurabili")
            } footer: {
                Text("Personalizza i prompt inviati all'AI per adattarli alle tue esigenze.")
            }

            Section {
                Button(role: .destructive) {
                    showResetAllAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Ripristina tutti i default")
                    }
                }
                .disabled(!hasAnyCustomizations)
            } footer: {
                if hasAnyCustomizations {
                    Text("Hai \(customizationCount) prompt personalizzati.")
                }
            }
        }
        .navigationTitle("Configurazione Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ripristina tutti i default?", isPresented: $showResetAllAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Ripristina", role: .destructive) {
                promptService.resetAllTemplates()
            }
        } message: {
            Text("Vuoi ripristinare tutti i prompt ai valori originali? Le tue modifiche andranno perse.")
        }
    }

    private var hasAnyCustomizations: Bool {
        PromptTemplateService.TemplateID.allCases.contains { templateId in
            promptService.hasCustomTemplate(for: templateId)
        }
    }

    private var customizationCount: Int {
        PromptTemplateService.TemplateID.allCases.filter { templateId in
            promptService.hasCustomTemplate(for: templateId)
        }.count
    }
}

// MARK: - Prompt Row View

struct PromptRowView: View {
    let templateId: PromptTemplateService.TemplateID
    let isCustomized: Bool

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(templateId.displayName)
                    .font(.subheadline)

                Text(templateId.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCustomized {
                Text("Modificato")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch templateId {
        case .menuCompleto:
            return "menucard"
        case .rigeneraPiatto:
            return "arrow.triangle.2.circlepath"
        case .suggerimentoSommelier:
            return "wineglass"
        case .generaInvito:
            return "envelope"
        case .noteRicette:
            return "book"
        case .noteVini:
            return "wineglass.fill"
        case .noteAccoglienza:
            return "person.2"
        }
    }

    private var iconColor: Color {
        switch templateId {
        case .menuCompleto:
            return .purple
        case .rigeneraPiatto:
            return .blue
        case .suggerimentoSommelier:
            return Color(hex: "722F37")
        case .generaInvito:
            return .green
        case .noteRicette:
            return .orange
        case .noteVini:
            return Color(hex: "722F37")
        case .noteAccoglienza:
            return .teal
        }
    }
}

#Preview {
    NavigationStack {
        PromptConfigurationListView()
    }
}
