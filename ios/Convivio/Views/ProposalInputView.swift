import SwiftUI
import SwiftData

// MARK: - Proposal Input View

/// Form for proposing a new dish for a dinner
struct ProposalInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dinner: DinnerEvent
    let currentUserId: String
    let currentUserName: String

    @State private var selectedCourse: CourseType = .primo
    @State private var dishName = ""
    @State private var dishDescription = ""
    @State private var wineSuggestion = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                // Course selection
                Section("Portata") {
                    Picker("Portata", selection: $selectedCourse) {
                        ForEach(CourseType.allCases, id: \.self) { course in
                            HStack {
                                Text(course.icon)
                                Text(course.displayName)
                            }
                            .tag(course)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Dish details
                Section("Piatto") {
                    TextField("Nome piatto", text: $dishName)
                        .textInputAutocapitalization(.words)

                    TextField("Descrizione (opzionale)", text: $dishDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Wine suggestion
                Section("Abbinamento Vino") {
                    TextField("Suggerimento vino (opzionale)", text: $wineSuggestion)
                        .textInputAutocapitalization(.words)

                    Text("Suggerisci un vino che si abbini bene a questo piatto")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Preview
                if !dishName.isEmpty {
                    Section("Anteprima") {
                        proposalPreview
                    }
                }
            }
            .navigationTitle("Proponi Piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Proponi") {
                        submitProposal()
                    }
                    .disabled(dishName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    // MARK: - Preview

    private var proposalPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedCourse.icon)
                Text(selectedCourse.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(dishName)
                .font(.headline)

            if !dishDescription.isEmpty {
                Text(dishDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                Text("Proposto da \(currentUserName)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            if !wineSuggestion.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "wineglass")
                        .font(.caption2)
                    Text(wineSuggestion)
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Submit

    private func submitProposal() {
        guard !dishName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSubmitting = true

        let proposal = DishProposal(
            dinnerId: dinner.title,  // Using title as ID for now
            course: selectedCourse,
            dishName: dishName.trimmingCharacters(in: .whitespaces),
            dishDescription: dishDescription.isEmpty ? nil : dishDescription.trimmingCharacters(in: .whitespaces),
            proposedById: currentUserId,
            proposedByName: currentUserName,
            wineSuggestion: wineSuggestion.isEmpty ? nil : wineSuggestion.trimmingCharacters(in: .whitespaces)
        )

        proposal.dinner = dinner
        modelContext.insert(proposal)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving proposal: \(error)")
            isSubmitting = false
        }
    }
}

// MARK: - Quick Proposal Button

/// Button to quickly add a proposal
struct QuickProposalButton: View {
    let dinner: DinnerEvent
    let currentUserId: String
    let currentUserName: String

    @State private var showProposalForm = false

    var body: some View {
        Button {
            showProposalForm = true
        } label: {
            Label("Proponi Piatto", systemImage: "plus.bubble")
        }
        .sheet(isPresented: $showProposalForm) {
            ProposalInputView(
                dinner: dinner,
                currentUserId: currentUserId,
                currentUserName: currentUserName
            )
        }
    }
}

// MARK: - Collaboration State Picker

/// Picker for changing collaboration state
struct CollaborationStatePicker: View {
    @Binding var state: CollaborationState
    let canChange: Bool

    var body: some View {
        if canChange {
            Menu {
                ForEach(CollaborationState.allCases) { newState in
                    if state.canTransitionTo(newState) || state == newState {
                        Button {
                            state = newState
                        } label: {
                            HStack {
                                Image(systemName: newState.icon)
                                Text(newState.displayName)
                                if state == newState {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                CollaborationStateBadge(state: state)
            }
        } else {
            CollaborationStateBadge(state: state)
        }
    }
}

// MARK: - Collaboration State Badge

struct CollaborationStateBadge: View {
    let state: CollaborationState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
            Text(state.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(stateColor.opacity(0.1))
        .foregroundColor(stateColor)
        .cornerRadius(12)
    }

    private var stateColor: Color {
        switch state {
        case .draft: return .gray
        case .openForProposals: return .blue
        case .voting: return .orange
        case .finalized: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    ProposalInputView(
        dinner: DinnerEvent(title: "Cena Test", date: Date()),
        currentUserId: "user1",
        currentUserName: "Marco"
    )
}
