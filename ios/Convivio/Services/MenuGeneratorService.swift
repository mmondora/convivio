import Foundation

// MARK: - Menu Generator Service

actor MenuGeneratorService {
    static let shared = MenuGeneratorService()

    private init() {}

    // MARK: - Menu Generation

    func generateMenu(request: MenuRequest, wines: [Wine], bottles: [Bottle]) async throws -> MenuResponse {
        // Filter available bottles (quantity > 0)
        let availableBottles = bottles.filter { $0.quantity > 0 }

        // Build wine inventory string
        let wineInventory = buildWineInventory(bottles: availableBottles)

        // Build taste preferences string
        let tastePrefsString = buildTastePreferences(request.tastePreferences)

        // Build prompt
        let prompt = buildPrompt(request: request, wineInventory: wineInventory, tastePreferences: tastePrefsString)

        // Call OpenAI API
        let responseText = try await OpenAIService.shared.generateMenuWithGPT(prompt: prompt)

        // Parse response
        return try parseMenuResponse(responseText)
    }

    // MARK: - Wine Inventory Builder

    private func buildWineInventory(bottles: [Bottle]) -> String {
        if bottles.isEmpty {
            return "CANTINA VUOTA - Nessun vino disponibile"
        }

        return bottles.compactMap { bottle -> String? in
            guard let wine = bottle.wine else { return nil }

            var parts: [String] = []

            if let producer = wine.producer {
                parts.append(producer)
            }
            parts.append(wine.name)

            var details: [String] = []
            details.append(wine.type.displayName)

            if let region = wine.region {
                details.append(region)
            }

            if let vintage = wine.vintage {
                details.append(vintage)
            }

            if !details.isEmpty {
                parts.append("(\(details.joined(separator: ", ")))")
            }

            parts.append("- \(bottle.quantity) bottigli\(bottle.quantity == 1 ? "a" : "e")")

            return "- " + parts.joined(separator: " ")
        }.joined(separator: "\n")
    }

    // MARK: - Taste Preferences Builder

    private func buildTastePreferences(_ prefs: TastePreferences?) -> String {
        guard let prefs = prefs else {
            return "Nessuna preferenza specifica indicata"
        }

        var parts: [String] = []

        if !prefs.preferredWineTypes.isEmpty {
            parts.append("Tipi preferiti: \(prefs.preferredWineTypes.joined(separator: ", "))")
        }

        if !prefs.preferredRegions.isEmpty {
            parts.append("Regioni preferite: \(prefs.preferredRegions.joined(separator: ", "))")
        }

        if !prefs.preferredGrapes.isEmpty {
            parts.append("Vitigni preferiti: \(prefs.preferredGrapes.joined(separator: ", "))")
        }

        parts.append("Corpo: \(prefs.bodyPreference.displayName)")
        parts.append("Dolcezza: \(prefs.sweetnessPreference.displayName)")
        parts.append("Tannini: \(prefs.tanninPreference.displayName)")
        parts.append("Acidità: \(prefs.acidityPreference.displayName)")

        if let notes = prefs.notes, !notes.isEmpty {
            parts.append("Note: \(notes)")
        }

        return parts.isEmpty ? "Nessuna preferenza specifica" : parts.joined(separator: "\n")
    }

    // MARK: - Prompt Builder

    private func buildPrompt(request: MenuRequest, wineInventory: String, tastePreferences: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")
        let dataFormattata = dateFormatter.string(from: request.data)

        return """
        Sei un sommelier professionista, chef consulente e maestro di cerimonie italiano. Genera un menu completo con ricette dettagliate, abbinamenti vino e consigli di galateo per inviti e ricevimento.

        ⚠️ REGOLA PRIORITARIA - LEGGERE ATTENTAMENTE:
        Le "Note specifiche dell'utente" hanno MASSIMA PRIORITÀ ASSOLUTA.
        - Se l'utente specifica il NUMERO di piatti per portata (es. "10 antipasti", "1 primo", "5 dolci"), DEVI generare ESATTAMENTE quel numero di piatti
        - Se l'utente specifica ingredienti, tema, stile, o qualsiasi altra indicazione, DEVI seguirla alla lettera
        - NON ignorare MAI le richieste dell'utente
        - Se le note specificano una struttura del menu diversa da quella standard, segui le note

        REGOLE ABBINAMENTO VINI:
        - Privilegia SEMPRE i vini presenti nella cantina fornita
        - Suggerisci vini esterni solo se la cantina non copre adeguatamente
        - Progressione coerente: bollicine → bianchi → rossi leggeri → rossi strutturati → dolci
        - Per ogni vino da cantina, verifica che la quantità sia sufficiente (1 bottiglia ogni 3-4 persone)
        - Per i suggerimenti di acquisto, indica SEMPRE produttore e annata consigliata
        - Valuta la compatibilità di ogni vino con le preferenze gusto dell'utente

        REGOLE RICETTE:
        - Ogni piatto deve avere una ricetta completa con ingredienti, quantità, tempi e procedimento
        - Le quantità degli ingredienti devono essere calibrate per il numero di persone
        - Indica tempo di preparazione e cottura separatamente
        - Il procedimento deve essere chiaro, passo per passo

        REGOLE GALATEO:
        - Fornisci consigli su tempistica e formulazione degli inviti
        - Descrivi il protocollo di accoglienza e ricevimento
        - Indica la corretta disposizione della tavola
        - Suggerisci argomenti di conversazione appropriati all'occasione

        DETTAGLI CONVIVIO:
        - Titolo: \(request.titolo)
        - Data: \(dataFormattata)
        - Persone: \(request.persone)
        - Occasione: \(request.occasione ?? "Convivio informale")
        - Vincoli dietetici: \(request.tipoDieta.rawValue)
        - Tipo cucina: \(request.tipoCucina)

        📋 NOTE SPECIFICHE DELL'UTENTE (PRIORITÀ MASSIMA):
        \(request.descrizione ?? "nessuna")

        PREFERENZE GUSTO OSPITE:
        \(tastePreferences)

        CANTINA DISPONIBILE:
        \(wineInventory)

        Rispondi SOLO con JSON valido (nessun markdown, nessun testo prima o dopo), seguendo ESATTAMENTE questo schema:
        {
          "menu": {
            "antipasti": [{
              "nome": "string",
              "descrizione": "string",
              "porzioni": number,
              "ricetta": {
                "ingredienti": [{"nome": "string", "quantita": "string", "unita": "string o null"}],
                "tempo_preparazione": number,
                "tempo_cottura": number,
                "difficolta": "facile|media|difficile",
                "procedimento": ["step 1", "step 2", ...],
                "consigli": "string o null"
              }
            }],
            "primi": [...],
            "secondi": [...],
            "contorni": [...],
            "dolci": [...]
          },
          "abbinamenti": [
            {
              "portata": "antipasti|primi|secondi|dolci",
              "vino": {
                "nome": "string",
                "produttore": "string",
                "annata": "string o null",
                "provenienza": "cantina" oppure "suggerimento",
                "quantita_necessaria": number,
                "motivazione": "string",
                "compatibilita": {
                  "punteggio": number (1-100),
                  "motivazione": "string",
                  "punti_forza": ["string"],
                  "punti_deboli": ["string"]
                }
              }
            }
          ],
          "suggerimenti_acquisto": [
            {
              "vino": "string",
              "produttore": "string",
              "annata": "string o null",
              "perche": "string",
              "abbinamento_ideale": "string",
              "compatibilita": {
                "punteggio": number (1-100),
                "motivazione": "string",
                "punti_forza": ["string"],
                "punti_deboli": ["string"]
              }
            }
          ],
          "note_servizio": "string con consigli su temperatura vini, decantazione, ordine di servizio",
          "galateo": {
            "inviti": {
              "tempistica": "quando inviare gli inviti",
              "formulazione": "come formulare l'invito",
              "conferma": "come gestire le conferme",
              "consigli": ["consiglio 1", "consiglio 2"]
            },
            "ricevimento": {
              "accoglienza": "come accogliere gli ospiti",
              "aperitivo": "gestione momento aperitivo",
              "passaggio_tavola": "come invitare a tavola",
              "congedo": "come congedare gli ospiti",
              "consigli": ["consiglio 1", "consiglio 2"]
            },
            "tavola": {
              "disposizione": "come disporre tavola e posti",
              "servizio": "ordine e modalità di servizio",
              "conversazione": "argomenti consigliati per l'occasione",
              "consigli": ["consiglio 1", "consiglio 2"]
            }
          }
        }
        """
    }

    // MARK: - Response Parser

    private func parseMenuResponse(_ text: String) throws -> MenuResponse {
        // Clean response from potential markdown
        var cleanJson = text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if cleanJson.hasPrefix("```json") {
            cleanJson = String(cleanJson.dropFirst(7))
        } else if cleanJson.hasPrefix("```") {
            cleanJson = String(cleanJson.dropFirst(3))
        }

        if cleanJson.hasSuffix("```") {
            cleanJson = String(cleanJson.dropLast(3))
        }

        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanJson.data(using: .utf8) else {
            throw OpenAIError.parseError
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(MenuResponse.self, from: data)
        } catch let decodingError as DecodingError {
            print("❌ JSON Parsing Error:")
            print("Raw JSON: \(cleanJson.prefix(2000))")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                print("codingPath: \(context.codingPath.map { $0.stringValue })")
            case .typeMismatch(let type, let context):
                print("Type mismatch for \(type): \(context.debugDescription)")
                print("codingPath: \(context.codingPath.map { $0.stringValue })")
            case .valueNotFound(let type, let context):
                print("Value not found for \(type): \(context.debugDescription)")
                print("codingPath: \(context.codingPath.map { $0.stringValue })")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
                print("codingPath: \(context.codingPath.map { $0.stringValue })")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            throw OpenAIError.parseError
        } catch {
            print("❌ Unexpected Error: \(error)")
            throw OpenAIError.parseError
        }
    }
}

// MARK: - Dish Editing Methods

extension MenuGeneratorService {
    /// Regenerate a single dish while maintaining menu coherence
    func regenerateDish(
        courseName: String,
        dishIndex: Int,
        currentMenu: MenuResponse,
        dinner: DinnerEvent,
        wines: [Wine],
        bottles: [Bottle],
        tastePreferences: TastePreferences?,
        cuisineType: String = "Italiana",
        dietType: DietType = .normale
    ) async throws -> MenuResponse {
        // Get current dishes for context
        let currentDishes = getDishesForCourse(courseName, from: currentMenu)
        guard dishIndex < currentDishes.count else {
            throw OpenAIError.parseError
        }

        let dishToReplace = currentDishes[dishIndex]
        let otherDishes = currentDishes.enumerated()
            .filter { $0.offset != dishIndex }
            .map { $0.element.nome }
            .joined(separator: ", ")

        // Build all dishes context for style consistency
        let allDishesContext = currentMenu.menu.allCourses.map { course in
            "\(course.name): \(course.dishes.map { $0.nome }.joined(separator: ", "))"
        }.joined(separator: "\n")

        // Build context about the dinner
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")

        let wineInventory = buildWineInventory(bottles: bottles.filter { $0.quantity > 0 })

        // Build taste preferences context
        var preferencesContext = ""
        if let prefs = tastePreferences {
            var prefList: [String] = []
            if !prefs.preferredWineTypes.isEmpty {
                prefList.append("vini preferiti: \(prefs.preferredWineTypes.joined(separator: ", "))")
            }
            if !prefs.preferredRegions.isEmpty {
                prefList.append("regioni preferite: \(prefs.preferredRegions.joined(separator: ", "))")
            }
            prefList.append("corpo: \(prefs.bodyPreference.rawValue)")
            prefList.append("dolcezza: \(prefs.sweetnessPreference.rawValue)")
            if let notes = prefs.notes, !notes.isEmpty {
                prefList.append("note: \(notes)")
            }
            if !prefList.isEmpty {
                preferencesContext = "- Preferenze gusto: \(prefList.joined(separator: "; "))"
            }
        }

        let prompt = """
        Sei un sommelier professionista e chef consulente italiano.
        Devi generare UN SOLO piatto alternativo per sostituire "\(dishToReplace.nome)" nella portata \(courseName).

        CONTESTO DELLA CENA:
        - Titolo: \(dinner.title)
        - Data: \(dateFormatter.string(from: dinner.date))
        - Persone: \(dinner.guestCount)
        - Occasione: \(dinner.occasion ?? "Convivio")
        - Tipo di cucina: \(cuisineType)
        - Dieta/restrizioni: \(dietType.rawValue)
        \(preferencesContext.isEmpty ? "" : preferencesContext)
        \(dinner.notes.map { "- Note dell'utente (PRIORITÀ MASSIMA): \($0)" } ?? "")

        MENU ATTUALE COMPLETO (per coerenza di stile):
        \(allDishesContext)

        ALTRI PIATTI NELLA STESSA PORTATA:
        \(otherDishes.isEmpty ? "Nessun altro piatto" : otherDishes)

        VINI ABBINATI ALLA PORTATA:
        \(getWinePairingsForCourse(courseName, from: currentMenu))

        CANTINA DISPONIBILE:
        \(wineInventory)

        IMPORTANTE:
        - Il nuovo piatto deve essere DIVERSO da "\(dishToReplace.nome)"
        - Deve essere coerente con il tipo di cucina (\(cuisineType)) e lo stile del menu esistente
        - Deve rispettare le restrizioni dietetiche (\(dietType.rawValue))
        - Deve abbinarsi bene con i vini già selezionati
        - Mantieni lo stesso livello di raffinatezza del menu esistente

        Rispondi SOLO con JSON valido per UN singolo piatto:
        {
          "nome": "string",
          "descrizione": "string",
          "porzioni": number,
          "ricetta": {
            "ingredienti": [{"nome": "string", "quantita": "string", "unita": "string o null"}],
            "tempo_preparazione": number,
            "tempo_cottura": number,
            "difficolta": "facile|media|difficile",
            "procedimento": ["step 1", "step 2", ...],
            "consigli": "string o null"
          }
        }
        """

        let responseText = try await OpenAIService.shared.generateMenuWithGPT(prompt: prompt)
        let newDish = try parseSingleDish(responseText)

        // Create updated menu with the new dish
        return replaceDishInMenu(currentMenu, courseName: courseName, dishIndex: dishIndex, newDish: newDish)
    }

    /// Delete a dish from a course
    nonisolated func deleteDish(
        courseName: String,
        dishIndex: Int,
        from currentMenu: MenuResponse
    ) -> MenuResponse {
        var updatedMenu = currentMenu.menu

        switch courseName.lowercased() {
        case "antipasti":
            var dishes = updatedMenu.antipasti
            if dishIndex < dishes.count {
                dishes.remove(at: dishIndex)
                updatedMenu = MenuSections(
                    antipasti: dishes,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "primi":
            var dishes = updatedMenu.primi
            if dishIndex < dishes.count {
                dishes.remove(at: dishIndex)
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: dishes,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "secondi":
            var dishes = updatedMenu.secondi
            if dishIndex < dishes.count {
                dishes.remove(at: dishIndex)
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: dishes,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "contorni":
            var dishes = updatedMenu.contorni
            if dishIndex < dishes.count {
                dishes.remove(at: dishIndex)
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: dishes,
                    dolci: updatedMenu.dolci
                )
            }
        case "dolci":
            var dishes = updatedMenu.dolci
            if dishIndex < dishes.count {
                dishes.remove(at: dishIndex)
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: dishes
                )
            }
        default:
            break
        }

        return MenuResponse(
            menu: updatedMenu,
            abbinamenti: currentMenu.abbinamenti,
            suggerimentiAcquisto: currentMenu.suggerimentiAcquisto,
            noteServizio: currentMenu.noteServizio,
            galateo: currentMenu.galateo
        )
    }

    // MARK: - Private Helpers

    private func getDishesForCourse(_ courseName: String, from menu: MenuResponse) -> [Dish] {
        switch courseName.lowercased() {
        case "antipasti": return menu.menu.antipasti
        case "primi": return menu.menu.primi
        case "secondi": return menu.menu.secondi
        case "contorni": return menu.menu.contorni
        case "dolci": return menu.menu.dolci
        default: return []
        }
    }

    private func getWinePairingsForCourse(_ courseName: String, from menu: MenuResponse) -> String {
        let pairings = menu.abbinamenti.filter { $0.portata.lowercased() == courseName.lowercased() }
        if pairings.isEmpty { return "Nessun vino abbinato" }
        return pairings.map { "\($0.vino.produttore) \($0.vino.nome)" }.joined(separator: ", ")
    }

    private func parseSingleDish(_ text: String) throws -> Dish {
        var cleanJson = text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanJson.hasPrefix("```json") {
            cleanJson = String(cleanJson.dropFirst(7))
        } else if cleanJson.hasPrefix("```") {
            cleanJson = String(cleanJson.dropFirst(3))
        }

        if cleanJson.hasSuffix("```") {
            cleanJson = String(cleanJson.dropLast(3))
        }

        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanJson.data(using: .utf8) else {
            throw OpenAIError.parseError
        }

        return try JSONDecoder().decode(Dish.self, from: data)
    }

    private func replaceDishInMenu(_ menu: MenuResponse, courseName: String, dishIndex: Int, newDish: Dish) -> MenuResponse {
        var updatedMenu = menu.menu

        switch courseName.lowercased() {
        case "antipasti":
            var dishes = updatedMenu.antipasti
            if dishIndex < dishes.count {
                dishes[dishIndex] = newDish
                updatedMenu = MenuSections(
                    antipasti: dishes,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "primi":
            var dishes = updatedMenu.primi
            if dishIndex < dishes.count {
                dishes[dishIndex] = newDish
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: dishes,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "secondi":
            var dishes = updatedMenu.secondi
            if dishIndex < dishes.count {
                dishes[dishIndex] = newDish
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: dishes,
                    contorni: updatedMenu.contorni,
                    dolci: updatedMenu.dolci
                )
            }
        case "contorni":
            var dishes = updatedMenu.contorni
            if dishIndex < dishes.count {
                dishes[dishIndex] = newDish
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: dishes,
                    dolci: updatedMenu.dolci
                )
            }
        case "dolci":
            var dishes = updatedMenu.dolci
            if dishIndex < dishes.count {
                dishes[dishIndex] = newDish
                updatedMenu = MenuSections(
                    antipasti: updatedMenu.antipasti,
                    primi: updatedMenu.primi,
                    secondi: updatedMenu.secondi,
                    contorni: updatedMenu.contorni,
                    dolci: dishes
                )
            }
        default:
            break
        }

        return MenuResponse(
            menu: updatedMenu,
            abbinamenti: menu.abbinamenti,
            suggerimentiAcquisto: menu.suggerimentiAcquisto,
            noteServizio: menu.noteServizio,
            galateo: menu.galateo
        )
    }
}

// MARK: - Invite Generation

extension MenuGeneratorService {
    /// Generate an elegant invite message for the dinner
    func generateInviteMessage(for dinner: DinnerEvent, menu: MenuResponse?) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "it_IT")

        var menuPreview = ""
        if let menu = menu {
            var courses: [String] = []
            if !menu.menu.antipasti.isEmpty {
                courses.append("Antipasti: \(menu.menu.antipasti.map { $0.nome }.joined(separator: ", "))")
            }
            if !menu.menu.primi.isEmpty {
                courses.append("Primi: \(menu.menu.primi.map { $0.nome }.joined(separator: ", "))")
            }
            if !menu.menu.secondi.isEmpty {
                courses.append("Secondi: \(menu.menu.secondi.map { $0.nome }.joined(separator: ", "))")
            }
            if !menu.menu.dolci.isEmpty {
                courses.append("Dolci: \(menu.menu.dolci.map { $0.nome }.joined(separator: ", "))")
            }
            menuPreview = courses.joined(separator: "\n")
        }

        let occasion = dinner.occasion ?? "Cena informale"
        let toneDescription = getInviteTone(for: occasion)

        let prompt = """
        Genera un messaggio di invito per questa cena.

        DETTAGLI CENA:
        - Data: \(dateFormatter.string(from: dinner.date))
        - Ora: \(timeFormatter.string(from: dinner.date))
        - Occasione: \(occasion)
        \(dinner.notes.map { "- Note: \($0)" } ?? "")

        \(menuPreview.isEmpty ? "" : "ANTEPRIMA MENU (solo per contesto, NON elencare i piatti):\n\(menuPreview)")

        STILE RICHIESTO: \(toneDescription)

        REQUISITI OBBLIGATORI:
        - NON includere nomi di persone (né mittente né destinatario)
        - NON includere firma finale
        - NON elencare i nomi dei piatti del menu
        - Se c'è un menu, puoi solo accennare genericamente al tipo di cucina
        - Includi data e ora
        - Chiedi conferma di partecipazione
        - Lunghezza: 2-4 frasi
        - NON usare emoji o formattazione markdown
        - Scrivi SOLO il testo del messaggio, nient'altro

        Rispondi SOLO con il testo del messaggio.
        """

        let response = try await OpenAIService.shared.generateMenuWithGPT(prompt: prompt)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Determines the appropriate tone for the invite based on the occasion
    private func getInviteTone(for occasion: String) -> String {
        let occasionLower = occasion.lowercased()

        // Formal occasions
        if occasionLower.contains("matrimonio") ||
           occasionLower.contains("anniversario") ||
           occasionLower.contains("laurea") ||
           occasionLower.contains("battesimo") ||
           occasionLower.contains("comunione") ||
           occasionLower.contains("cresima") ||
           occasionLower.contains("gala") ||
           occasionLower.contains("formale") {
            return "Tono formale ed elegante, linguaggio ricercato"
        }

        // Semi-formal occasions
        if occasionLower.contains("compleanno") ||
           occasionLower.contains("promozione") ||
           occasionLower.contains("pensionamento") ||
           occasionLower.contains("fidanzamento") {
            return "Tono semi-formale, cordiale ma curato"
        }

        // Business occasions
        if occasionLower.contains("lavoro") ||
           occasionLower.contains("business") ||
           occasionLower.contains("colleghi") ||
           occasionLower.contains("aziendale") {
            return "Tono professionale ma cordiale"
        }

        // Default: informal
        return "Tono informale e amichevole, come tra amici"
    }
}

// MARK: - Wine Quantity Helper

extension MenuGeneratorService {
    /// Checks if cellar has sufficient quantity for a wine pairing
    static func checkWineAvailability(pairing: MenuWinePairing, bottles: [Bottle]) -> WineAvailabilityStatus {
        guard pairing.vino.provenienza == .cantina else {
            return .external
        }

        // Find matching bottle
        let matchingBottle = bottles.first { bottle in
            guard let wine = bottle.wine else { return false }
            let nameMatch = wine.name.lowercased().contains(pairing.vino.nome.lowercased()) ||
                           pairing.vino.nome.lowercased().contains(wine.name.lowercased())
            return nameMatch
        }

        guard let bottle = matchingBottle else {
            return .notFound
        }

        if bottle.quantity >= pairing.vino.quantitaNecessaria {
            return .sufficient(available: bottle.quantity, needed: pairing.vino.quantitaNecessaria)
        } else {
            return .insufficient(available: bottle.quantity, needed: pairing.vino.quantitaNecessaria)
        }
    }
}

enum WineAvailabilityStatus {
    case sufficient(available: Int, needed: Int)
    case insufficient(available: Int, needed: Int)
    case notFound
    case external

    var isWarning: Bool {
        switch self {
        case .insufficient, .notFound:
            return true
        default:
            return false
        }
    }

    var message: String? {
        switch self {
        case .sufficient(let available, let needed):
            return "✓ \(available) disponibili, \(needed) necessarie"
        case .insufficient(let available, let needed):
            return "⚠️ Solo \(available) disponibili, servono \(needed)"
        case .notFound:
            return "⚠️ Vino non trovato in cantina"
        case .external:
            return nil
        }
    }
}
