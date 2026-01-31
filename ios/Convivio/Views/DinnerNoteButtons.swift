import SwiftUI
import SwiftData

// MARK: - Dinner Note Buttons

struct DinnerNoteButtons: View {
    let dinner: DinnerEvent
    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [DinnerNote]
    @Query private var appSettings: [AppSettings]
    @ObservedObject private var notesService = DinnerNotesService.shared

    private var settings: AppSettings? { appSettings.first }

    /// Filter notes for this dinner
    private var notes: [DinnerNote] {
        allNotes.filter { $0.dinnerID == dinner.stableUUID }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DinnerNoteType.allCases, id: \.self) { noteType in
                NoteButton(
                    noteType: noteType,
                    hasNote: hasNote(for: noteType),
                    isGenerating: isGenerating(noteType),
                    action: { handleNoteTap(noteType) }
                )
            }
        }
    }

    private func hasNote(for type: DinnerNoteType) -> Bool {
        notes.contains { $0.noteType == type.rawValue }
    }

    private func isGenerating(_ type: DinnerNoteType) -> Bool {
        notesService.generatingNotes[dinner.stableUUID]?.contains(type) ?? false
    }

    private func getNote(for type: DinnerNoteType) -> DinnerNote? {
        notes.first { $0.noteType == type.rawValue }
    }

    private func handleNoteTap(_ type: DinnerNoteType) {
        if hasNote(for: type) {
            // Note exists, navigate will be handled by NavigationLink
            return
        }

        // Generate note
        Task {
            do {
                try await notesService.generateNote(
                    type: type,
                    dinner: dinner,
                    menu: dinner.menuResponse,
                    settings: settings,
                    context: modelContext
                )
            } catch {
                print("Error generating note: \(error)")
            }
        }
    }
}

// MARK: - Note Button

struct NoteButton: View {
    let noteType: DinnerNoteType
    let hasNote: Bool
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(hasNote ? .white : .primary)
                } else {
                    Text(noteType.buttonIcon)
                        .font(.system(size: 12))
                }

                Text(noteType.buttonLabel)
                    .font(.caption2)
                    .fontWeight(.medium)

                if hasNote && !isGenerating {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(hasNote ? backgroundColor : Color(.tertiarySystemBackground))
            .foregroundColor(hasNote ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hasNote ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    private var backgroundColor: Color {
        switch noteType {
        case .cucina: return .orange
        case .vini: return Color(hex: "722F37")
        case .accoglienza: return .teal
        }
    }
}

// MARK: - Dinner Note Buttons with Navigation

struct DinnerNoteButtonsWithNavigation: View {
    let dinner: DinnerEvent
    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [DinnerNote]
    @Query private var appSettings: [AppSettings]
    @ObservedObject private var notesService = DinnerNotesService.shared

    @State private var selectedNoteType: DinnerNoteType?
    @State private var showNoteView = false

    private var settings: AppSettings? { appSettings.first }

    /// Filter notes for this dinner
    private var notes: [DinnerNote] {
        allNotes.filter { $0.dinnerID == dinner.stableUUID }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DinnerNoteType.allCases, id: \.self) { noteType in
                NoteButton(
                    noteType: noteType,
                    hasNote: hasNote(for: noteType),
                    isGenerating: isGenerating(noteType),
                    action: { handleNoteTap(noteType) }
                )
            }
        }
        .sheet(isPresented: $showNoteView) {
            if let noteType = selectedNoteType {
                noteViewSheet(for: noteType)
            }
        }
    }

    private func hasNote(for type: DinnerNoteType) -> Bool {
        notes.contains { $0.noteType == type.rawValue }
    }

    private func isGenerating(_ type: DinnerNoteType) -> Bool {
        notesService.generatingNotes[dinner.stableUUID]?.contains(type) ?? false
    }

    private func getNote(for type: DinnerNoteType) -> DinnerNote? {
        notes.first { $0.noteType == type.rawValue }
    }

    private func handleNoteTap(_ type: DinnerNoteType) {
        if hasNote(for: type) {
            selectedNoteType = type
            showNoteView = true
            return
        }

        // Generate note
        Task {
            do {
                try await notesService.generateNote(
                    type: type,
                    dinner: dinner,
                    menu: dinner.menuResponse,
                    settings: settings,
                    context: modelContext
                )
                // After generation, show the note
                await MainActor.run {
                    selectedNoteType = type
                    showNoteView = true
                }
            } catch {
                print("Error generating note: \(error)")
            }
        }
    }

    @ViewBuilder
    private func noteViewSheet(for type: DinnerNoteType) -> some View {
        NavigationStack {
            Group {
                switch type {
                case .cucina:
                    if let note = getNote(for: .cucina),
                       let content = notesService.parseNoteRicette(note) {
                        NoteRicetteView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.cucina) }
                        )
                    } else {
                        ContentUnavailableView(
                            "Note non disponibili",
                            systemImage: "book",
                            description: Text("Impossibile caricare le note ricette")
                        )
                    }

                case .vini:
                    if let note = getNote(for: .vini),
                       let content = notesService.parseNoteVini(note) {
                        NoteViniView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.vini) }
                        )
                    } else {
                        ContentUnavailableView(
                            "Note non disponibili",
                            systemImage: "wineglass",
                            description: Text("Impossibile caricare le note vini")
                        )
                    }

                case .accoglienza:
                    if let note = getNote(for: .accoglienza),
                       let content = notesService.parseNoteAccoglienza(note) {
                        NoteAccoglienzaView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.accoglienza) }
                        )
                    } else {
                        ContentUnavailableView(
                            "Note non disponibili",
                            systemImage: "person.2",
                            description: Text("Impossibile caricare le note accoglienza")
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        showNoteView = false
                    }
                }
            }
        }
    }

    private func regenerateNote(_ type: DinnerNoteType) {
        // Delete existing note
        if let existingNote = getNote(for: type) {
            modelContext.delete(existingNote)
            try? modelContext.save()
        }

        // Generate new note
        Task {
            do {
                try await notesService.generateNote(
                    type: type,
                    dinner: dinner,
                    menu: dinner.menuResponse,
                    settings: settings,
                    context: modelContext
                )
            } catch {
                print("Error regenerating note: \(error)")
            }
        }
    }
}
