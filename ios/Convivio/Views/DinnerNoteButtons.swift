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
        print("🔵 [NoteButtons] Tapped \(type.rawValue) for dinner \(dinner.stableUUID)")
        print("🔵 [NoteButtons] Total notes in query: \(allNotes.count), for this dinner: \(notes.count)")

        if hasNote(for: type) {
            print("🔵 [NoteButtons] Note exists, showing sheet")
            selectedNoteType = type
            showNoteView = true
            return
        }

        print("🔵 [NoteButtons] Note doesn't exist, generating...")
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
                print("🔵 [NoteButtons] Generation complete, showing sheet")
                // After generation, show the note
                await MainActor.run {
                    selectedNoteType = type
                    showNoteView = true
                }
            } catch {
                print("❌ [NoteButtons] Error generating note: \(error)")
            }
        }
    }

    @ViewBuilder
    private func noteViewSheet(for type: DinnerNoteType) -> some View {
        NavigationStack {
            Group {
                // Debug: fetch note directly from context to ensure fresh data
                let freshNote = notesService.getNote(dinnerID: dinner.stableUUID, type: type, from: modelContext)

                switch type {
                case .cucina:
                    if let note = freshNote ?? getNote(for: .cucina) {
                        if let content = notesService.parseNoteRicette(note) {
                            NoteRicetteView(
                                dinner: dinner,
                                content: content,
                                onRegenerate: { regenerateNote(.cucina) }
                            )
                        } else {
                            noteParseErrorView(type: type, noteExists: true)
                        }
                    } else {
                        noteParseErrorView(type: type, noteExists: false)
                    }

                case .vini:
                    if let note = freshNote ?? getNote(for: .vini) {
                        if let content = notesService.parseNoteVini(note) {
                            NoteViniView(
                                dinner: dinner,
                                content: content,
                                onRegenerate: { regenerateNote(.vini) }
                            )
                        } else {
                            noteParseErrorView(type: type, noteExists: true)
                        }
                    } else {
                        noteParseErrorView(type: type, noteExists: false)
                    }

                case .accoglienza:
                    if let note = freshNote ?? getNote(for: .accoglienza) {
                        if let content = notesService.parseNoteAccoglienza(note) {
                            NoteAccoglienzaView(
                                dinner: dinner,
                                content: content,
                                onRegenerate: { regenerateNote(.accoglienza) }
                            )
                        } else {
                            noteParseErrorView(type: type, noteExists: true)
                        }
                    } else {
                        noteParseErrorView(type: type, noteExists: false)
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

    @ViewBuilder
    private func noteParseErrorView(type: DinnerNoteType, noteExists: Bool) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                noteExists ? "Errore nel formato delle note" : "Note non disponibili",
                systemImage: type.icon,
                description: Text(noteExists ? "Prova a rigenerare le note" : "Impossibile caricare le note")
            )

            if noteExists {
                Button("Rigenera Note") {
                    regenerateNote(type)
                    showNoteView = false
                }
                .buttonStyle(.bordered)
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
