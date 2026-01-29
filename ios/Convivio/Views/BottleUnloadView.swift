import SwiftUI
import SwiftData

struct BottleUnloadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var bottles: [Bottle]

    @Bindable var dinner: DinnerEvent

    @State private var consumedQuantities: [UUID: Int] = [:]
    @State private var isProcessing = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    private var cellarWines: [ConfirmedWine] {
        dinner.confirmedWines.filter { $0.isFromCellar }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Dinner summary
                    dinnerSummarySection

                    // Menu preview
                    if dinner.menuResponse != nil {
                        menuPreviewSection
                    }

                    // Bottles to unload
                    if cellarWines.isEmpty {
                        emptyStateView
                    } else {
                        bottlesSection
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

                    // Confirm button
                    if !cellarWines.isEmpty {
                        confirmButtonSection
                    }
                }
                .padding()
            }
            .navigationTitle("Scarico Bottiglie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onAppear {
                initializeQuantities()
            }
            .alert("Conferma Scarico", isPresented: $showConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Conferma") {
                    Task { await processUnload() }
                }
            } message: {
                Text("Le quantità verranno scalate dalla cantina. Questa azione non può essere annullata.")
            }
        }
    }

    // MARK: - Dinner Summary Section

    private var dinnerSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wineglass.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Com'è andata la cena?")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(dinner.title)
                        .font(.title3.bold())
                    Spacer()
                }

                HStack {
                    Label(formatDate(dinner.date), systemImage: "calendar")
                    Spacer()
                    if let occasion = dinner.occasion {
                        Text(occasion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                HStack {
                    Label("\(dinner.guestCount) ospiti", systemImage: "person.2")
                    Spacer()
                    Text(dinner.status.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch dinner.status {
        case .planning: return .orange
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .red
        }
    }

    // MARK: - Menu Preview Section

    private var menuPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Menu della serata", systemImage: "menucard")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            if let menu = dinner.menuResponse {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(menu.menu.allCourses, id: \.name) { course in
                        HStack(alignment: .top) {
                            Text(course.name + ":")
                                .font(.caption.bold())
                                .frame(width: 70, alignment: .leading)
                            Text(course.dishes.map { $0.nome }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Nessuna bottiglia dalla cantina")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("I vini per questa cena erano tutti da acquistare.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Segna come completata") {
                Task { await markAsCompleted() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Bottles Section

    private var bottlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bottiglie consumate", systemImage: "arrow.down.circle")
                .font(.headline)

            Text("Modifica le quantità se necessario")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(cellarWines) { wine in
                BottleUnloadRow(
                    wine: wine,
                    consumedQuantity: binding(for: wine.id),
                    maxAvailable: maxAvailableQuantity(for: wine)
                )
            }

            // Summary
            HStack {
                Text("Totale bottiglie da scaricare:")
                    .font(.subheadline)
                Spacer()
                Text("\(totalConsumed)")
                    .font(.subheadline.bold())
                    .foregroundColor(.purple)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Confirm Button Section

    private var confirmButtonSection: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle")
                }
                Text(isProcessing ? "Elaborazione..." : "Conferma Scarico")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isProcessing ? Color.gray : Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
    }

    // MARK: - Helpers

    private func initializeQuantities() {
        for wine in cellarWines {
            consumedQuantities[wine.id] = wine.quantity
        }
    }

    private func binding(for wineId: UUID) -> Binding<Int> {
        Binding(
            get: { consumedQuantities[wineId] ?? 0 },
            set: { consumedQuantities[wineId] = $0 }
        )
    }

    private func maxAvailableQuantity(for wine: ConfirmedWine) -> Int {
        // Find the matching bottle in cellar
        guard let wineId = wine.wineId else { return wine.quantity }

        // Search for bottles that match this wine
        let matchingBottles = bottles.filter { bottle in
            guard let bottleWine = bottle.wine else { return false }
            // Try to match by name and producer
            return bottleWine.name.lowercased() == wine.wineName.lowercased() ||
                   (bottleWine.producer?.lowercased() == wine.producer?.lowercased() &&
                    bottleWine.name.lowercased().contains(wine.wineName.lowercased()))
        }

        let totalAvailable = matchingBottles.reduce(0) { $0 + $1.quantity }
        return max(totalAvailable, wine.quantity)
    }

    private var totalConsumed: Int {
        consumedQuantities.values.reduce(0, +)
    }

    // MARK: - Actions

    private func processUnload() async {
        isProcessing = true
        errorMessage = nil

        await MainActor.run {
            // Process each wine's consumed quantity
            for wine in cellarWines {
                let consumed = consumedQuantities[wine.id] ?? 0
                if consumed > 0 {
                    decrementBottleQuantity(for: wine, by: consumed)
                }
            }

            // Update dinner status
            dinner.status = .completed
            dinner.updatedAt = Date()

            // Cancel post-dinner notification since we're done
            if let notificationId = dinner.postDinnerNotificationId {
                Task {
                    NotificationService.shared.cancelPostDinnerNotification(for: dinner)
                }
                dinner.postDinnerNotificationId = nil
            }

            try? modelContext.save()
            isProcessing = false
            dismiss()
        }
    }

    private func markAsCompleted() async {
        await MainActor.run {
            dinner.status = .completed
            dinner.updatedAt = Date()

            if dinner.postDinnerNotificationId != nil {
                Task {
                    NotificationService.shared.cancelPostDinnerNotification(for: dinner)
                }
                dinner.postDinnerNotificationId = nil
            }

            try? modelContext.save()
            dismiss()
        }
    }

    private func decrementBottleQuantity(for wine: ConfirmedWine, by amount: Int) {
        var remaining = amount

        // Find matching bottles and decrement quantities
        let matchingBottles = bottles.filter { bottle in
            guard let bottleWine = bottle.wine, bottle.quantity > 0 else { return false }
            // Match by name (case insensitive)
            let nameMatch = bottleWine.name.lowercased() == wine.wineName.lowercased()
            let producerMatch = wine.producer == nil ||
                               bottleWine.producer?.lowercased() == wine.producer?.lowercased()
            return nameMatch && producerMatch
        }.sorted { $0.quantity < $1.quantity } // Consume from smaller quantities first

        for bottle in matchingBottles {
            guard remaining > 0 else { break }

            let toDeduct = min(bottle.quantity, remaining)
            bottle.quantity -= toDeduct
            remaining -= toDeduct

            // If bottle is empty, mark as consumed
            if bottle.quantity == 0 {
                bottle.status = .consumed
            }
        }

        if remaining > 0 {
            // Couldn't find enough bottles - log warning but continue
            print("Warning: Could not find enough bottles for \(wine.displayName). Remaining: \(remaining)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Bottle Unload Row

struct BottleUnloadRow: View {
    let wine: ConfirmedWine
    @Binding var consumedQuantity: Int
    let maxAvailable: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Wine info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.displayName)
                        .font(.subheadline.bold())

                    HStack {
                        Text(wine.course.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Previste: \(wine.quantity)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                // Quantity stepper
                HStack(spacing: 12) {
                    Button {
                        if consumedQuantity > 0 {
                            consumedQuantity -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(consumedQuantity > 0 ? .purple : .gray)
                    }
                    .disabled(consumedQuantity <= 0)

                    Text("\(consumedQuantity)")
                        .font(.title3.bold())
                        .frame(minWidth: 30)

                    Button {
                        if consumedQuantity < maxAvailable {
                            consumedQuantity += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(consumedQuantity < maxAvailable ? .purple : .gray)
                    }
                    .disabled(consumedQuantity >= maxAvailable)
                }
            }

            // Warning if quantity differs from expected
            if consumedQuantity != wine.quantity {
                HStack {
                    Image(systemName: consumedQuantity < wine.quantity ? "info.circle" : "exclamationmark.triangle")
                        .font(.caption)
                    Text(consumedQuantity < wine.quantity ?
                         "Meno del previsto" :
                         "Più del previsto")
                        .font(.caption)
                }
                .foregroundColor(consumedQuantity < wine.quantity ? .blue : .orange)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}
