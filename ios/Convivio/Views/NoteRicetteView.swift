import SwiftUI

// MARK: - Note Ricette View

struct NoteRicetteView: View {
    let dinner: DinnerEvent
    let content: NoteRicetteContent
    let onRegenerate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = ["timeline", "ricette"]
    @State private var expandedRecipes: Set<String> = []
    @State private var checkedItems: Set<String> = []
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Timeline Cucina
                timelineSection

                // Ricette
                ricetteSection

                // Lista Spesa
                listaSpesaSection

                // Consigli Chef
                consigliSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Note Cucina")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        onRegenerate()
                        dismiss()
                    } label: {
                        Label("Rigenera", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(content: DinnerNotesService.shared.exportNoteRicetteAsText(content, dinner: dinner))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(dinner.title)
                .font(.headline)

            Text(formatDate(dinner.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        ExpandableSection(
            title: "Timeline Cucina",
            icon: "clock",
            iconColor: .blue,
            isExpanded: expandedSections.contains("timeline"),
            onToggle: { toggleSection("timeline") }
        ) {
            VStack(spacing: 12) {
                ForEach(content.timelineCucina.sorted(by: { $0.quandoMinuti < $1.quandoMinuti })) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(step.quandoLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(width: 80, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.descrizione)
                                .font(.subheadline)

                            if let piatto = step.piattoCorrelato {
                                Text(piatto)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if step.id != content.timelineCucina.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Ricette Section

    private var ricetteSection: some View {
        ExpandableSection(
            title: "Ricette",
            icon: "fork.knife",
            iconColor: .orange,
            isExpanded: expandedSections.contains("ricette"),
            onToggle: { toggleSection("ricette") }
        ) {
            VStack(spacing: 16) {
                ForEach(content.ricette) { ricetta in
                    RecipeCard(
                        ricetta: ricetta,
                        isExpanded: expandedRecipes.contains(ricetta.id),
                        onToggle: { toggleRecipe(ricetta.id) }
                    )
                }
            }
        }
    }

    // MARK: - Lista Spesa Section

    private var listaSpesaSection: some View {
        ExpandableSection(
            title: "Lista Spesa",
            icon: "cart",
            iconColor: .green,
            isExpanded: expandedSections.contains("spesa"),
            onToggle: { toggleSection("spesa") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(content.listaSpesa) { categoria in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(categoria.categoria)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(categoria.items) { item in
                            HStack {
                                Button {
                                    toggleChecked(item.id)
                                } label: {
                                    Image(systemName: checkedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(checkedItems.contains(item.id) ? .green : .secondary)
                                }

                                Text(item.nome)
                                    .strikethrough(checkedItems.contains(item.id))
                                    .foregroundColor(checkedItems.contains(item.id) ? .secondary : .primary)

                                Spacer()

                                Text(item.quantita)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Button {
                    copyShoppingList()
                } label: {
                    Label("Copia lista", systemImage: "doc.on.doc")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Consigli Section

    private var consigliSection: some View {
        Group {
            if !content.consigliChef.isEmpty {
                ExpandableSection(
                    title: "Consigli Chef",
                    icon: "lightbulb",
                    iconColor: .yellow,
                    isExpanded: expandedSections.contains("consigli"),
                    onToggle: { toggleSection("consigli") }
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(content.consigliChef, id: \.self) { consiglio in
                            HStack(alignment: .top, spacing: 8) {
                                Text("💡")
                                Text(consiglio)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func toggleRecipe(_ id: String) {
        if expandedRecipes.contains(id) {
            expandedRecipes.remove(id)
        } else {
            expandedRecipes.insert(id)
        }
    }

    private func toggleChecked(_ id: String) {
        if checkedItems.contains(id) {
            checkedItems.remove(id)
        } else {
            checkedItems.insert(id)
        }
    }

    private func copyShoppingList() {
        var text = "Lista Spesa - \(dinner.title)\n\n"
        for categoria in content.listaSpesa {
            text += "\(categoria.categoria):\n"
            for item in categoria.items {
                text += "- \(item.nome) (\(item.quantita))\n"
            }
            text += "\n"
        }
        UIPasteboard.general.string = text
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let ricetta: RicettaDettagliata
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ricetta.nome)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Text(ricetta.categoria)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)

                            difficultyBadge

                            if ricetta.canPrepareAhead {
                                Text("Anticipabile")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    // Times
                    HStack(spacing: 20) {
                        Label("\(ricetta.prepTime) min prep", systemImage: "clock")
                        Label("\(ricetta.cookTime) min cottura", systemImage: "flame")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // Ingredienti
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredienti")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(ricetta.ingredienti) { ing in
                            HStack {
                                Text("•")
                                Text(ing.nome)
                                Spacer()
                                Text("\(ing.quantita)\(ing.unita.map { " \($0)" } ?? "")")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }

                    // Procedimento
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Procedimento")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(Array(ricetta.procedimento.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Text(step)
                            }
                            .font(.subheadline)
                        }
                    }

                    // Impiattamento
                    if let impiattamento = ricetta.impiattamento {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Impiattamento")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(impiattamento.descrizione)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Consigli
                    if let consigli = ricetta.consigli {
                        HStack(alignment: .top, spacing: 8) {
                            Text("💡")
                            Text(consigli)
                                .font(.caption)
                                .italic()
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var difficultyBadge: some View {
        let (color, text) = difficultyInfo
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private var difficultyInfo: (Color, String) {
        switch ricetta.difficolta.lowercased() {
        case "facile": return (.green, "Facile")
        case "media": return (.orange, "Media")
        case "difficile": return (.red, "Difficile")
        default: return (.gray, ricetta.difficolta)
        }
    }
}

// MARK: - Expandable Section

struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            if isExpanded {
                Divider()
                content()
                    .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct ShareSheetView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Condividi Note")
                    .font(.headline)

                Button {
                    UIPasteboard.general.string = content
                    dismiss()
                } label: {
                    Label("Copia testo", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    // Share as activity
                    let av = UIActivityViewController(activityItems: [content], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.present(av, animated: true)
                    }
                    dismiss()
                } label: {
                    Label("Condividi...", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
