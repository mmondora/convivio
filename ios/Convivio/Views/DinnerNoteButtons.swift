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

    // Store parsed content directly to avoid SwiftData sync timing issues
    @State private var ricetteContent: NoteRicetteContent?
    @State private var viniContent: NoteViniContent?
    @State private var accoglienzaContent: NoteAccoglienzaContent?

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

        // Check if we already have parsed content in memory
        if hasParsedContent(for: type) {
            print("🔵 [NoteButtons] Content already in memory, showing sheet")
            selectedNoteType = type
            showNoteView = true
            return
        }

        // Check if note exists in database
        if let note = getNote(for: type) {
            print("🔵 [NoteButtons] Note exists in DB, parsing...")
            if parseAndStoreContent(note: note, type: type) {
                selectedNoteType = type
                showNoteView = true
                return
            }
        }

        print("🔵 [NoteButtons] Note doesn't exist, generating...")
        // Generate note
        Task {
            do {
                let contentJSON = try await notesService.generateAndReturnJSON(
                    type: type,
                    dinner: dinner,
                    menu: dinner.menuResponse,
                    settings: settings,
                    context: modelContext
                )
                print("🔵 [NoteButtons] Generation complete, parsing content...")

                // Parse content immediately from the returned JSON
                await MainActor.run {
                    if parseAndStoreContentFromJSON(json: contentJSON, type: type) {
                        print("✅ [NoteButtons] Content parsed successfully, showing sheet")
                        selectedNoteType = type
                        showNoteView = true
                    } else {
                        print("❌ [NoteButtons] Failed to parse generated content")
                    }
                }
            } catch {
                print("❌ [NoteButtons] Error generating note: \(error)")
            }
        }
    }

    private func hasParsedContent(for type: DinnerNoteType) -> Bool {
        switch type {
        case .cucina: return ricetteContent != nil
        case .vini: return viniContent != nil
        case .accoglienza: return accoglienzaContent != nil
        }
    }

    private func parseAndStoreContent(note: DinnerNote, type: DinnerNoteType) -> Bool {
        return parseAndStoreContentFromJSON(json: note.contentJSON, type: type)
    }

    private func parseAndStoreContentFromJSON(json: String, type: DinnerNoteType) -> Bool {
        guard let data = json.data(using: .utf8) else {
            print("❌ [NoteButtons] Failed to convert JSON to data")
            return false
        }

        do {
            switch type {
            case .cucina:
                ricetteContent = try JSONDecoder().decode(NoteRicetteContent.self, from: data)
                print("✅ [NoteButtons] Parsed ricette content with \(ricetteContent?.ricette.count ?? 0) recipes")
                return true
            case .vini:
                viniContent = try JSONDecoder().decode(NoteViniContent.self, from: data)
                print("✅ [NoteButtons] Parsed vini content with \(viniContent?.schedeVino.count ?? 0) wine cards")
                return true
            case .accoglienza:
                accoglienzaContent = try JSONDecoder().decode(NoteAccoglienzaContent.self, from: data)
                print("✅ [NoteButtons] Parsed accoglienza content")
                return true
            }
        } catch {
            print("❌ [NoteButtons] JSON decode error for \(type.rawValue): \(error)")
            print("❌ [NoteButtons] JSON preview: \(String(json.prefix(500)))")
            return false
        }
    }

    @ViewBuilder
    private func noteViewSheet(for type: DinnerNoteType) -> some View {
        NavigationStack {
            Group {
                switch type {
                case .cucina:
                    if let content = ricetteContent {
                        NoteRicetteView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.cucina) }
                        )
                    } else {
                        noteParseErrorView(type: type, noteExists: false)
                    }

                case .vini:
                    if let content = viniContent {
                        NoteViniView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.vini) }
                        )
                    } else {
                        noteParseErrorView(type: type, noteExists: false)
                    }

                case .accoglienza:
                    if let content = accoglienzaContent {
                        NoteAccoglienzaView(
                            dinner: dinner,
                            content: content,
                            onRegenerate: { regenerateNote(.accoglienza) }
                        )
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
        // Clear cached content
        switch type {
        case .cucina: ricetteContent = nil
        case .vini: viniContent = nil
        case .accoglienza: accoglienzaContent = nil
        }

        // Delete existing note
        if let existingNote = getNote(for: type) {
            modelContext.delete(existingNote)
            try? modelContext.save()
        }

        // Generate new note
        Task {
            do {
                let contentJSON = try await notesService.generateAndReturnJSON(
                    type: type,
                    dinner: dinner,
                    menu: dinner.menuResponse,
                    settings: settings,
                    context: modelContext
                )

                await MainActor.run {
                    if parseAndStoreContentFromJSON(json: contentJSON, type: type) {
                        // Content is already showing, will update automatically
                    }
                }
            } catch {
                print("❌ [NoteButtons] Error regenerating note: \(error)")
            }
        }
    }
}
