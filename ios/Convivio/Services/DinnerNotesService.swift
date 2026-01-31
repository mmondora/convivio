import Foundation
import SwiftData

// MARK: - Dinner Notes Service

@MainActor
class DinnerNotesService: ObservableObject {
    static let shared = DinnerNotesService()

    @Published var generatingNotes: [UUID: Set<DinnerNoteType>] = [:]

    private init() {}

    // MARK: - Note Status

    func isGenerating(dinnerID: UUID, type: DinnerNoteType) -> Bool {
        generatingNotes[dinnerID]?.contains(type) ?? false
    }

    func hasNote(dinnerID: UUID, type: DinnerNoteType, in context: ModelContext) -> Bool {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<DinnerNote>(
            predicate: #Predicate { $0.dinnerID == dinnerID && $0.noteType == typeRaw }
        )
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    func getNote(dinnerID: UUID, type: DinnerNoteType, from context: ModelContext) -> DinnerNote? {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<DinnerNote>(
            predicate: #Predicate { $0.dinnerID == dinnerID && $0.noteType == typeRaw }
        )
        return try? context.fetch(descriptor).first
    }

    func getAllNotes(dinnerID: UUID, from context: ModelContext) -> [DinnerNote] {
        let descriptor = FetchDescriptor<DinnerNote>(
            predicate: #Predicate { $0.dinnerID == dinnerID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Note Generation

    func generateNote(
        type: DinnerNoteType,
        dinner: DinnerEvent,
        menu: MenuResponse?,
        settings: AppSettings?,
        context: ModelContext
    ) async throws {
        _ = try await generateAndReturnJSON(type: type, dinner: dinner, menu: menu, settings: settings, context: context)
    }

    /// Generate note and return the JSON string (also saves to database)
    func generateAndReturnJSON(
        type: DinnerNoteType,
        dinner: DinnerEvent,
        menu: MenuResponse?,
        settings: AppSettings?,
        context: ModelContext
    ) async throws -> String {
        let dinnerUUID = dinner.stableUUID

        // Mark as generating
        if generatingNotes[dinnerUUID] == nil {
            generatingNotes[dinnerUUID] = []
        }
        generatingNotes[dinnerUUID]?.insert(type)

        defer {
            generatingNotes[dinnerUUID]?.remove(type)
        }

        // Build locale context
        let locale = LocaleContext.from(settings: settings)

        // Generate based on type
        let contentJSON: String
        switch type {
        case .cucina:
            contentJSON = try await generateNoteRicette(dinner: dinner, menu: menu, locale: locale)
        case .vini:
            contentJSON = try await generateNoteVini(dinner: dinner, menu: menu, locale: locale)
        case .accoglienza:
            contentJSON = try await generateNoteAccoglienza(dinner: dinner, menu: menu, locale: locale)
        }

        // Delete existing note if any
        if let existing = getNote(dinnerID: dinnerUUID, type: type, from: context) {
            context.delete(existing)
        }

        // Save new note
        let note = DinnerNote(dinnerID: dinnerUUID, noteType: type, contentJSON: contentJSON)
        context.insert(note)
        try context.save()
        print("✅ [DinnerNotesService] Saved \(type.rawValue) note for dinner \(dinnerUUID)")
        print("✅ [DinnerNotesService] JSON length: \(contentJSON.count) chars")

        return contentJSON
    }

    func deleteNote(dinnerID: UUID, type: DinnerNoteType, from context: ModelContext) {
        if let note = getNote(dinnerID: dinnerID, type: type, from: context) {
            context.delete(note)
            try? context.save()
        }
    }

    func deleteAllNotes(dinnerID: UUID, from context: ModelContext) {
        let notes = getAllNotes(dinnerID: dinnerID, from: context)
        for note in notes {
            context.delete(note)
        }
        try? context.save()
    }

    // MARK: - Note Parsing

    func parseNoteRicette(_ note: DinnerNote) -> NoteRicetteContent? {
        guard let data = note.contentJSON.data(using: .utf8) else {
            print("❌ [NoteRicette] Failed to convert contentJSON to data")
            return nil
        }
        do {
            let content = try JSONDecoder().decode(NoteRicetteContent.self, from: data)
            print("✅ [NoteRicette] Successfully parsed note with \(content.ricette.count) recipes")
            return content
        } catch {
            print("❌ [NoteRicette] JSON decode error: \(error)")
            print("❌ [NoteRicette] Raw JSON (first 500 chars): \(String(note.contentJSON.prefix(500)))")
            return nil
        }
    }

    func parseNoteVini(_ note: DinnerNote) -> NoteViniContent? {
        guard let data = note.contentJSON.data(using: .utf8) else {
            print("❌ [NoteVini] Failed to convert contentJSON to data")
            return nil
        }
        do {
            let content = try JSONDecoder().decode(NoteViniContent.self, from: data)
            print("✅ [NoteVini] Successfully parsed note with \(content.schedeVino.count) wine cards")
            return content
        } catch {
            print("❌ [NoteVini] JSON decode error: \(error)")
            print("❌ [NoteVini] Raw JSON (first 500 chars): \(String(note.contentJSON.prefix(500)))")
            return nil
        }
    }

    func parseNoteAccoglienza(_ note: DinnerNote) -> NoteAccoglienzaContent? {
        guard let data = note.contentJSON.data(using: .utf8) else {
            print("❌ [NoteAccoglienza] Failed to convert contentJSON to data")
            return nil
        }
        do {
            let content = try JSONDecoder().decode(NoteAccoglienzaContent.self, from: data)
            print("✅ [NoteAccoglienza] Successfully parsed note")
            return content
        } catch {
            print("❌ [NoteAccoglienza] JSON decode error: \(error)")
            print("❌ [NoteAccoglienza] Raw JSON (first 500 chars): \(String(note.contentJSON.prefix(500)))")
            return nil
        }
    }

    // MARK: - Private Generation Methods

    private func generateNoteRicette(dinner: DinnerEvent, menu: MenuResponse?, locale: LocaleContext) async throws -> String {
        let promptService = PromptTemplateService.shared

        // Build menu context
        var menuContext = "Menu non disponibile"
        if let menu = menu {
            var courses: [String] = []
            if !menu.menu.antipasti.isEmpty {
                courses.append("ANTIPASTI:\n" + menu.menu.antipasti.map { "- \($0.nome): \($0.descrizione)" }.joined(separator: "\n"))
            }
            if !menu.menu.primi.isEmpty {
                courses.append("PRIMI:\n" + menu.menu.primi.map { "- \($0.nome): \($0.descrizione)" }.joined(separator: "\n"))
            }
            if !menu.menu.secondi.isEmpty {
                courses.append("SECONDI:\n" + menu.menu.secondi.map { "- \($0.nome): \($0.descrizione)" }.joined(separator: "\n"))
            }
            if !menu.menu.contorni.isEmpty {
                courses.append("CONTORNI:\n" + menu.menu.contorni.map { "- \($0.nome): \($0.descrizione)" }.joined(separator: "\n"))
            }
            if !menu.menu.dolci.isEmpty {
                courses.append("DOLCI:\n" + menu.menu.dolci.map { "- \($0.nome): \($0.descrizione)" }.joined(separator: "\n"))
            }
            menuContext = courses.joined(separator: "\n\n")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: locale.languageCode)

        // Extract dietary restrictions from guests
        let restrictions = dinner.guests.flatMap { $0.dietaryRestrictions }.joined(separator: ", ")

        let placeholders: [String: String] = [
            "dataOra": dateFormatter.string(from: dinner.date),
            "numeroOspiti": "\(dinner.guestCount)",
            "tipoCucina": "Italiana",
            "restrizioni": restrictions.isEmpty ? "nessuna" : restrictions,
            "note": dinner.notes ?? "nessuna",
            "menuCompleto": menuContext
        ]

        let systemPrompt = promptService.buildSystemPrompt(for: .noteRicette, locale: locale, restrictions: restrictions.isEmpty ? nil : restrictions)
        let userPrompt = promptService.buildUserPrompt(for: .noteRicette, locale: locale, placeholders: placeholders)

        let fullPrompt = systemPrompt + "\n\n" + userPrompt + """

        Rispondi SOLO con JSON valido seguendo questo schema:
        {
          "timeline_cucina": [
            {"quando_minuti": -1440, "quando_label": "1 giorno prima", "descrizione": "...", "piatto_correlato": "Nome piatto o null"}
          ],
          "ricette": [
            {
              "nome": "Nome piatto",
              "categoria": "Antipasti/Primi/Secondi/Contorni/Dolci",
              "difficolta": "facile/media/difficile",
              "tempo_preparazione": 30,
              "tempo_cottura": 20,
              "preparabile_anticipo": true,
              "ingredienti": [{"nome": "...", "quantita": "100", "unita": "g"}],
              "procedimento": ["Step 1", "Step 2"],
              "impiattamento": {"descrizione": "...", "consigli": ["..."]},
              "consigli": "..."
            }
          ],
          "lista_spesa": [
            {"categoria": "Verdure", "items": [{"nome": "Pomodori", "quantita": "500g"}]}
          ],
          "consigli_chef": ["Consiglio 1", "Consiglio 2"]
        }
        """

        let response = try await OpenAIService.shared.generateMenuWithGPT(prompt: fullPrompt, model: .gpt4o)
        return cleanJSONResponse(response)
    }

    private func generateNoteVini(dinner: DinnerEvent, menu: MenuResponse?, locale: LocaleContext) async throws -> String {
        let promptService = PromptTemplateService.shared

        // Build menu summary
        var menuRiepilogo = "Menu non disponibile"
        if let menu = menu {
            var courses: [String] = []
            if !menu.menu.antipasti.isEmpty {
                courses.append("Antipasti: " + menu.menu.antipasti.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.primi.isEmpty {
                courses.append("Primi: " + menu.menu.primi.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.secondi.isEmpty {
                courses.append("Secondi: " + menu.menu.secondi.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.dolci.isEmpty {
                courses.append("Dolci: " + menu.menu.dolci.map { $0.nome }.joined(separator: ", "))
            }
            menuRiepilogo = courses.joined(separator: "\n")
        }

        // Build confirmed wines list
        var viniConfermati = "Nessun vino confermato"
        if !dinner.confirmedWines.isEmpty {
            viniConfermati = dinner.confirmedWines.map { wine in
                "\(wine.producer ?? "") \(wine.wineName) - \(wine.course)"
            }.joined(separator: "\n")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: locale.languageCode)

        let placeholders: [String: String] = [
            "dataOra": dateFormatter.string(from: dinner.date),
            "numeroOspiti": "\(dinner.guestCount)",
            "menuRiepilogo": menuRiepilogo,
            "listaViniConfermati": viniConfermati
        ]

        let systemPrompt = promptService.buildSystemPrompt(for: .noteVini, locale: locale, restrictions: nil)
        let userPrompt = promptService.buildUserPrompt(for: .noteVini, locale: locale, placeholders: placeholders)

        let fullPrompt = systemPrompt + "\n\n" + userPrompt + """

        Rispondi SOLO con JSON valido seguendo questo schema:
        {
          "timeline_vini": [
            {"quando_minuti": -120, "quando_label": "2 ore prima", "vino": "Nome vino", "azione": "Mettere in frigo", "icona": "❄️"}
          ],
          "schede_vino": [
            {
              "nome_vino": "Nome",
              "produttore": "Produttore",
              "portata_abbinata": "Antipasti",
              "temperatura_servizio": "8-10°C",
              "bicchiere_consigliato": "Calice da bianco",
              "quantita_persona": "1 bicchiere (150ml)",
              "decantazione": {"necessaria": false, "tempo": null, "motivo": null},
              "come_presentare": "Script per presentare il vino agli ospiti..."
            }
          ],
          "sequenza_servizio": [
            {"ordine": 1, "vino": "Nome", "momento": "Con antipasti", "transizione": "Come passare al prossimo"}
          ],
          "attrezzatura_necessaria": [
            {"nome": "Secchiello ghiaccio", "icona": "🧊", "quantita": 1}
          ],
          "consigli_sommelier": ["Consiglio 1", "Consiglio 2"]
        }
        """

        let response = try await OpenAIService.shared.generateMenuWithGPT(prompt: fullPrompt, model: .gpt4o)
        return cleanJSONResponse(response)
    }

    private func generateNoteAccoglienza(dinner: DinnerEvent, menu: MenuResponse?, locale: LocaleContext) async throws -> String {
        let promptService = PromptTemplateService.shared

        // Build menu summary
        var menuRiepilogo = "Menu non disponibile"
        if let menu = menu {
            var courses: [String] = []
            if !menu.menu.antipasti.isEmpty {
                courses.append("Antipasti: " + menu.menu.antipasti.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.primi.isEmpty {
                courses.append("Primi: " + menu.menu.primi.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.secondi.isEmpty {
                courses.append("Secondi: " + menu.menu.secondi.map { $0.nome }.joined(separator: ", "))
            }
            if !menu.menu.dolci.isEmpty {
                courses.append("Dolci: " + menu.menu.dolci.map { $0.nome }.joined(separator: ", "))
            }
            menuRiepilogo = courses.joined(separator: "\n")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: locale.languageCode)

        // Extract dietary restrictions from guests
        let restrictions = dinner.guests.flatMap { $0.dietaryRestrictions }.joined(separator: ", ")

        let placeholders: [String: String] = [
            "dataOra": dateFormatter.string(from: dinner.date),
            "numeroOspiti": "\(dinner.guestCount)",
            "tipoCucina": "Italiana",
            "dressCode": dinner.occasion ?? "Informale",
            "restrizioni": restrictions.isEmpty ? "nessuna" : restrictions,
            "note": dinner.notes ?? "nessuna",
            "menuRiepilogo": menuRiepilogo
        ]

        let systemPrompt = promptService.buildSystemPrompt(for: .noteAccoglienza, locale: locale, restrictions: nil)
        let userPrompt = promptService.buildUserPrompt(for: .noteAccoglienza, locale: locale, placeholders: placeholders)

        let fullPrompt = systemPrompt + "\n\n" + userPrompt + """

        Rispondi SOLO con JSON valido seguendo questo schema:
        {
          "preparazione_ambiente": {
            "tavola": {
              "descrizione": "Descrizione generale setup tavola",
              "tovaglia": "Tipo tovaglia",
              "tovaglioli": "Tipo e disposizione",
              "bicchieri": "Quali bicchieri",
              "centrotavola": "Suggerimento",
              "segnaposto": "Se appropriato"
            },
            "atmosfera": {
              "illuminazione": "Suggerimento",
              "musica": "Genere consigliato",
              "profumo": "Se appropriato",
              "temperatura": "Ideale"
            },
            "checklist_pre_ospiti": ["Cosa controllare 1", "Cosa controllare 2"]
          },
          "accoglienza": {
            "orario_arrivo": "Quando aspettarsi gli ospiti",
            "dove_ricevere": "Ingresso, salotto, ecc.",
            "aperitivo": {"cosa": "Cosa offrire", "dove": "Dove servirlo", "durata": "Quanto tempo"},
            "come_accomodare": "Come guidare a tavola",
            "rompighiaccio": ["Argomento 1", "Argomento 2"]
          },
          "gestione_serata": {
            "tempi_portate": "Indicazioni sui tempi",
            "quando_sparecchiare": "Quando e come",
            "consigli_conversazione": ["Argomento 1", "Argomento 2"],
            "se_qualcosa_va_storto": ["Soluzione 1", "Soluzione 2"]
          },
          "post_cena": {
            "caffe_te": {"quando": "Quando offrire", "come": "Come servire"},
            "digestivo": {"cosa": "Cosa offrire", "quando": "Quando"},
            "intrattenimento": "Eventuale attività",
            "congedo": {"segnali": "Come capire quando", "saluti": "Come salutare", "omaggio": "Se appropriato"}
          },
          "consigli_host": ["Consiglio finale 1", "Consiglio finale 2"]
        }
        """

        let response = try await OpenAIService.shared.generateMenuWithGPT(prompt: fullPrompt, model: .gpt4o)
        return cleanJSONResponse(response)
    }

    private func cleanJSONResponse(_ text: String) -> String {
        var cleanJson = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        if cleanJson.hasPrefix("```json") {
            cleanJson = String(cleanJson.dropFirst(7))
        } else if cleanJson.hasPrefix("```") {
            cleanJson = String(cleanJson.dropFirst(3))
        }

        if cleanJson.hasSuffix("```") {
            cleanJson = String(cleanJson.dropLast(3))
        }

        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate it starts with { and ends with }
        if !cleanJson.hasPrefix("{") {
            if let startIndex = cleanJson.firstIndex(of: "{") {
                cleanJson = String(cleanJson[startIndex...])
            }
        }
        if !cleanJson.hasSuffix("}") {
            if let endIndex = cleanJson.lastIndex(of: "}") {
                cleanJson = String(cleanJson[...endIndex])
            }
        }

        print("🧹 [cleanJSON] Cleaned JSON length: \(cleanJson.count), starts with '{': \(cleanJson.hasPrefix("{"))")
        return cleanJson
    }
}

// MARK: - Text Export

extension DinnerNotesService {
    func exportNoteRicetteAsText(_ content: NoteRicetteContent, dinner: DinnerEvent) -> String {
        var text = """
        ### NOTE RICETTE
        Cena: \(dinner.title)
        Data: \(formatDate(dinner.date))

        """

        // Timeline
        text += "\n### TIMELINE CUCINA\n"
        for step in content.timelineCucina.sorted(by: { $0.quandoMinuti < $1.quandoMinuti }) {
            text += "- \(step.quandoLabel): \(step.descrizione)"
            if let piatto = step.piattoCorrelato {
                text += " [\(piatto)]"
            }
            text += "\n"
        }

        // Ricette
        text += "\n### RICETTE\n"
        for ricetta in content.ricette {
            text += "\n#### \(ricetta.nome) (\(ricetta.categoria))\n"
            text += "Difficoltà: \(ricetta.difficolta) | Prep: \(ricetta.prepTime)min | Cottura: \(ricetta.cookTime)min\n"
            if ricetta.canPrepareAhead {
                text += "✓ Preparabile in anticipo\n"
            }
            text += "\nIngredienti:\n"
            for ing in ricetta.ingredienti {
                text += "- \(ing.nome): \(ing.quantita)\(ing.unita.map { " \($0)" } ?? "")\n"
            }
            text += "\nProcedimento:\n"
            for (i, step) in ricetta.procedimento.enumerated() {
                text += "\(i + 1). \(step)\n"
            }
            if let impiattamento = ricetta.impiattamento {
                text += "\nImpiattamento: \(impiattamento.descrizione)\n"
            }
        }

        // Lista spesa
        text += "\n### LISTA SPESA\n"
        for categoria in content.listaSpesa {
            text += "\n\(categoria.categoria):\n"
            for item in categoria.items {
                text += "- \(item.nome) (\(item.quantita))\n"
            }
        }

        // Consigli
        if !content.consigliChef.isEmpty {
            text += "\n### CONSIGLI CHEF\n"
            for consiglio in content.consigliChef {
                text += "- \(consiglio)\n"
            }
        }

        text += "\n---\nGenerato da Convivio"
        return text
    }

    func exportNoteViniAsText(_ content: NoteViniContent, dinner: DinnerEvent) -> String {
        var text = """
        ### NOTE VINI
        Cena: \(dinner.title)
        Data: \(formatDate(dinner.date))

        """

        // Timeline
        text += "\n### TIMELINE VINI\n"
        for step in content.timelineVini.sorted(by: { $0.quandoMinuti < $1.quandoMinuti }) {
            text += "- \(step.icona) \(step.quandoLabel): \(step.vino) - \(step.azione)\n"
        }

        // Schede vino
        text += "\n### SCHEDE VINO\n"
        for scheda in content.schedeVino {
            text += "\n#### \(scheda.nomeVino)\n"
            if let produttore = scheda.produttore {
                text += "Produttore: \(produttore)\n"
            }
            text += "Abbinamento: \(scheda.portataAbbinata)\n"
            text += "Temperatura: \(scheda.temperaturaServizio)\n"
            text += "Bicchiere: \(scheda.bicchiereConsigliato)\n"
            text += "Quantità: \(scheda.quantitaPersona)\n"
            if let dec = scheda.decantazione, dec.necessaria {
                text += "Decantazione: \(dec.tempo ?? "sì")"
                if let motivo = dec.motivo {
                    text += " - \(motivo)"
                }
                text += "\n"
            }
            text += "Presentazione: \(scheda.comePresentare)\n"
        }

        // Sequenza
        text += "\n### SEQUENZA SERVIZIO\n"
        for passo in content.sequenzaServizio.sorted(by: { $0.ordine < $1.ordine }) {
            text += "\(passo.ordine). \(passo.vino) - \(passo.momento)\n"
        }

        // Attrezzatura
        text += "\n### ATTREZZATURA\n"
        for item in content.attrezzaturaNecessaria {
            text += "- \(item.icona) \(item.nome)"
            if let q = item.quantita {
                text += " (x\(q))"
            }
            text += "\n"
        }

        // Consigli
        if !content.consigliSommelier.isEmpty {
            text += "\n### CONSIGLI SOMMELIER\n"
            for consiglio in content.consigliSommelier {
                text += "- \(consiglio)\n"
            }
        }

        text += "\n---\nGenerato da Convivio"
        return text
    }

    func exportNoteAccoglienzaAsText(_ content: NoteAccoglienzaContent, dinner: DinnerEvent) -> String {
        var text = """
        ### NOTE ACCOGLIENZA
        Cena: \(dinner.title)
        Data: \(formatDate(dinner.date))

        """

        // Preparazione ambiente
        text += "\n### PREPARAZIONE AMBIENTE\n"
        text += "\nTavola:\n"
        text += content.preparazioneAmbiente.tavola.descrizione + "\n"
        if let tov = content.preparazioneAmbiente.tavola.tovaglia {
            text += "- Tovaglia: \(tov)\n"
        }
        if let bicch = content.preparazioneAmbiente.tavola.bicchieri {
            text += "- Bicchieri: \(bicch)\n"
        }

        text += "\nAtmosfera:\n"
        if let luce = content.preparazioneAmbiente.atmosfera.illuminazione {
            text += "- Illuminazione: \(luce)\n"
        }
        if let musica = content.preparazioneAmbiente.atmosfera.musica {
            text += "- Musica: \(musica)\n"
        }

        text += "\nChecklist pre-ospiti:\n"
        for check in content.preparazioneAmbiente.checklistPreOspiti {
            text += "☐ \(check)\n"
        }

        // Accoglienza
        text += "\n### ACCOGLIENZA\n"
        text += "Orario arrivo: \(content.accoglienza.orarioArrivo)\n"
        text += "Dove ricevere: \(content.accoglienza.doveRicevere)\n"
        text += "Aperitivo: \(content.accoglienza.aperitivo.cosa) - \(content.accoglienza.aperitivo.dove) (\(content.accoglienza.aperitivo.durata))\n"
        text += "Come accomodare: \(content.accoglienza.comeAccomodare)\n"
        text += "\nRompighiaccio:\n"
        for arg in content.accoglienza.rompighiaccio {
            text += "- \(arg)\n"
        }

        // Gestione serata
        text += "\n### GESTIONE SERATA\n"
        text += "Tempi portate: \(content.gestioneSerata.tempiPortate)\n"
        text += "Sparecchiare: \(content.gestioneSerata.quandoSparecchiare)\n"
        text += "\nArgomenti conversazione:\n"
        for arg in content.gestioneSerata.consigliConversazione {
            text += "- \(arg)\n"
        }
        text += "\nSe qualcosa va storto:\n"
        for sol in content.gestioneSerata.seQualcosaVaStorto {
            text += "- \(sol)\n"
        }

        // Post cena
        text += "\n### POST CENA\n"
        text += "Caffè/Tè: \(content.postCena.caffeTe.quando) - \(content.postCena.caffeTe.come)\n"
        if let dig = content.postCena.digestivo {
            text += "Digestivo: \(dig.cosa) - \(dig.quando)\n"
        }
        text += "Congedo: \(content.postCena.congedo.saluti)\n"

        // Consigli
        if !content.consigliHost.isEmpty {
            text += "\n### CONSIGLI HOST\n"
            for consiglio in content.consigliHost {
                text += "- \(consiglio)\n"
            }
        }

        text += "\n---\nGenerato da Convivio"
        return text
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
