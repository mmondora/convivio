import SwiftUI
import SwiftData

// MARK: - Dettaglio Menu View

struct DettaglioMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dinner: DinnerEvent
    let menu: MenuResponse

    @Query private var appSettings: [AppSettings]
    @State private var dettaglio: DettaglioMenuCompleto?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedSections: Set<String> = ["ricette", "timeline"]
    @State private var pdfData: Data?

    @ObservedObject private var promptInterceptionService = PromptInterceptionService.shared

    private var settings: AppSettings? { appSettings.first }
    private var debugEnabled: Bool { settings?.debugModeEnabled ?? false }

    var body: some View {
        ScrollView {
            if isLoading {
                loadingView
            } else if let dettaglio = dettaglio {
                contentView(dettaglio)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                generatePromptView
            }
        }
        .navigationTitle("Dettaglio Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dettaglio != nil, let pdfData = pdfData {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: pdfData,
                        preview: SharePreview(
                            "Menu - \(dinner.title)",
                            image: Image(systemName: "doc.richtext")
                        )
                    ) {
                        Label("Condividi PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }

            // Regenerate button if already exists
            if dettaglio != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        dettaglio = nil
                        pdfData = nil
                        Task { await generateDetailedMenu() }
                    } label: {
                        Label("Rigenera", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $promptInterceptionService.isShowingEditor) {
            PromptEditorSheet()
        }
        .onAppear {
            // Load existing detailed menu if available
            if let existing = dinner.detailedMenu {
                dettaglio = existing
                // Pre-generate PDF for sharing
                pdfData = PDFGenerator.generateMenuPDF(from: existing, dinner: dinner)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Generazione dettagli in corso...")
                .font(.headline)

            Text("Stiamo preparando ricette complete, timeline e lista della spesa")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Generate Prompt View

    private var generatePromptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Genera Dettaglio Menu")
                .font(.title2.bold())

            Text("Genera un documento completo con ricette dettagliate, timeline di preparazione, lista della spesa e consigli di servizio.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await generateDetailedMenu() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Genera Dettaglio")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(settings?.openAIApiKey == nil)

            if settings?.openAIApiKey == nil {
                Text("Configura l'API key OpenAI in Profilo")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(40)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Errore")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                errorMessage = nil
            } label: {
                Text("Riprova")
                    .padding()
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    // MARK: - Content View

    private func contentView(_ dettaglio: DettaglioMenuCompleto) -> some View {
        LazyVStack(spacing: 16) {
            // Header
            headerSection(dettaglio)

            // Recipes Section
            DisclosureGroup(
                isExpanded: bindingFor("ricette"),
                content: {
                    RecipesSectionView(portate: dettaglio.portate)
                },
                label: {
                    sectionHeader("Ricette", systemImage: "book.closed.fill", count: dettaglio.portate.count)
                }
            )
            .sectionStyle()

            // Timeline Section
            DisclosureGroup(
                isExpanded: bindingFor("timeline"),
                content: {
                    TimelineSectionView(steps: dettaglio.timeline)
                },
                label: {
                    sectionHeader("Timeline Preparazione", systemImage: "clock.fill", count: dettaglio.timeline.count)
                }
            )
            .sectionStyle()

            // Wine Service Section
            if !dettaglio.wineService.isEmpty {
                DisclosureGroup(
                    isExpanded: bindingFor("vini"),
                    content: {
                        WineServiceSectionView(advice: dettaglio.wineService)
                    },
                    label: {
                        sectionHeader("Servizio Vini", systemImage: "wineglass.fill", count: dettaglio.wineService.count)
                    }
                )
                .sectionStyle()
            }

            // Shopping List Section
            DisclosureGroup(
                isExpanded: bindingFor("spesa"),
                content: {
                    ShoppingListSectionView(categories: dettaglio.shoppingList)
                },
                label: {
                    sectionHeader("Lista della Spesa", systemImage: "cart.fill", count: dettaglio.shoppingList.reduce(0) { $0 + $1.items.count })
                }
            )
            .sectionStyle()

            // Mise en Place Section
            DisclosureGroup(
                isExpanded: bindingFor("mise"),
                content: {
                    MiseEnPlaceSectionView(miseEnPlace: dettaglio.miseEnPlace)
                },
                label: {
                    sectionHeader("Mise en Place", systemImage: "fork.knife", count: nil)
                }
            )
            .sectionStyle()

            // Etiquette Section
            if !dettaglio.etiquette.isEmpty {
                DisclosureGroup(
                    isExpanded: bindingFor("etiquette"),
                    content: {
                        EtiquetteSectionView(tips: dettaglio.etiquette)
                    },
                    label: {
                        sectionHeader("Galateo", systemImage: "sparkles", count: dettaglio.etiquette.count)
                    }
                )
                .sectionStyle()
            }
        }
        .padding()
    }

    // MARK: - Header Section

    private func headerSection(_ dettaglio: DettaglioMenuCompleto) -> some View {
        VStack(spacing: 8) {
            Text(dettaglio.dinnerTitle)
                .font(.title2.bold())

            HStack(spacing: 16) {
                Label(formatDate(dettaglio.dinnerDate), systemImage: "calendar")
                Label("\(dettaglio.guestCount) persone", systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String, count: Int?) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
        }
    }

    private func bindingFor(_ section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }

    // MARK: - Generate Action

    private func generateDetailedMenu() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let result = try await MenuGeneratorService.shared.generateDetailedMenu(
                for: dinner,
                menu: menu,
                debugEnabled: debugEnabled
            )

            await MainActor.run {
                dettaglio = result
                // Pre-generate PDF for sharing
                pdfData = PDFGenerator.generateMenuPDF(from: result, dinner: dinner)
                // Save to dinner for persistence
                dinner.detailedMenu = result
                dinner.updatedAt = Date()
                try? modelContext.save()
                isLoading = false
            }
        } catch PromptInterceptionError.cancelled {
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Section Style Modifier

extension View {
    func sectionStyle() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
    }
}

// MARK: - Recipes Section View

struct RecipesSectionView: View {
    let portate: [PortataDettagliata]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(portate) { portata in
                RecipeCardView(portata: portata)
            }
        }
        .padding(.top, 8)
    }
}

struct RecipeCardView: View {
    let portata: PortataDettagliata
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(portata.courseName)
                            .font(.caption.bold())
                            .foregroundColor(.purple)
                        Text(portata.dishName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Label("\(portata.recipe.totalTime) min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredienti (\(portata.recipe.servings) persone)")
                        .font(.subheadline.bold())

                    ForEach(portata.recipe.ingredients) { ingredient in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundColor(.purple)
                            Text(ingredient.displayText)
                                .font(.caption)
                        }
                    }
                }

                Divider()

                // Procedure
                VStack(alignment: .leading, spacing: 8) {
                    Text("Procedimento")
                        .font(.subheadline.bold())

                    ForEach(Array(portata.recipe.procedure.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 20, height: 20)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)

                            Text(step)
                                .font(.caption)
                        }
                    }
                }

                // Chef Tips
                if let tips = portata.recipe.chefTips, !tips.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Consigli dello Chef", systemImage: "lightbulb.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)

                        ForEach(tips, id: \.self) { tip in
                            Text("• \(tip)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Wine Note
                if let wineNote = portata.wineNote {
                    Divider()

                    HStack {
                        Image(systemName: "wineglass")
                            .foregroundColor(.red)
                        Text(wineNote)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Timeline Section View

struct TimelineSectionView: View {
    let steps: [TimelineStep]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.sorted { $0.timeOffset < $1.timeOffset }.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    // Time indicator
                    VStack {
                        Circle()
                            .fill(step.timeOffset == 0 ? Color.green : Color.purple)
                            .frame(width: 12, height: 12)

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.formattedTime)
                            .font(.caption.bold())
                            .foregroundColor(step.timeOffset == 0 ? .green : .purple)

                        Text(step.description)
                            .font(.subheadline)

                        if let dish = step.relatedDish {
                            Text(dish)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 16)

                    Spacer()
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Wine Service Section View

struct WineServiceSectionView: View {
    let advice: [WineServiceAdvice]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(advice.sorted { $0.servingOrder < $1.servingOrder }) { wine in
                HStack(alignment: .top) {
                    Text("\(wine.servingOrder)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(wine.wineName)
                            .font(.subheadline.bold())

                        HStack(spacing: 16) {
                            Label(wine.formattedTemp, systemImage: "thermometer.medium")
                            Label(wine.glassType, systemImage: "wineglass")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if let decant = wine.decantTime {
                            Label("Decantare \(decant)", systemImage: "hourglass")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Text("Con: \(wine.pairedWith)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Shopping List Section View

struct ShoppingListSectionView: View {
    let categories: [ShoppingCategory]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(.green)
                        Text(category.category)
                            .font(.subheadline.bold())
                    }

                    ForEach(category.items) { item in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(item.quantity) \(item.name)")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Mise en Place Section View

struct MiseEnPlaceSectionView: View {
    let miseEnPlace: MiseEnPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Table Settings
            if !miseEnPlace.tableSettings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Disposizione Tavola", systemImage: "tablecells")
                        .font(.subheadline.bold())

                    ForEach(miseEnPlace.tableSettings, id: \.self) { setting in
                        Text("• \(setting)")
                            .font(.caption)
                    }
                }
            }

            // Serving Order
            if !miseEnPlace.servingOrder.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ordine di Servizio", systemImage: "list.number")
                        .font(.subheadline.bold())

                    ForEach(Array(miseEnPlace.servingOrder.enumerated()), id: \.offset) { index, order in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                            Text(order)
                                .font(.caption)
                        }
                    }
                }
            }

            // General Tips
            if !miseEnPlace.generalTips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Consigli", systemImage: "lightbulb")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)

                    ForEach(miseEnPlace.generalTips, id: \.self) { tip in
                        Text("• \(tip)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Etiquette Section View

struct EtiquetteSectionView: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkle")
                        .foregroundColor(.yellow)

                    Text(tip)
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        Text("Preview not available")
    }
}
