import Foundation

// MARK: - Menu Generator Service

actor MenuGeneratorService {
    static let shared = MenuGeneratorService()

    private init() {}

    // MARK: - Menu Generation

    func generateMenu(
        request: MenuRequest,
        wines: [Wine],
        bottles: [Bottle],
        debugEnabled: Bool = false
    ) async throws -> MenuResponse {
        // Filter available bottles (quantity > 0)
        let availableBottles = bottles.filter { $0.quantity > 0 }

        // Build wine inventory string
        let wineInventory = buildWineInventory(bottles: availableBottles)

        // Build taste preferences string
        let tastePrefsString = buildTastePreferences(request.tastePreferences)

        // Build prompts
        let (systemPrompt, userPrompt) = buildMenuPrompts(
            request: request,
            wineInventory: wineInventory,
            tastePreferences: tastePrefsString
        )

        // Intercept prompt if debug mode enabled
        let finalPrompt: String
        if debugEnabled {
            guard let config = await PromptInterceptionService.shared.interceptPrompt(
                identifier: .menuGeneration,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                debugEnabled: true
            ) else {
                throw PromptInterceptionError.cancelled
            }
            finalPrompt = config.combinedPrompt
        } else {
            finalPrompt = systemPrompt + "\n\n" + userPrompt
        }

        // Call OpenAI API with gpt-4o for complex menu generation
        let responseText = try await OpenAIService.shared.generateMenuWithGPT(
            prompt: finalPrompt,
            model: .gpt4o  // Full menu generation requires best model
        )

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

    /// Builds separate system and user prompts for menu generation
    private func buildMenuPrompts(request: MenuRequest, wineInventory: String, tastePreferences: String) -> (systemPrompt: String, userPrompt: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")
        let dataFormattata = dateFormatter.string(from: request.data)

        let systemPrompt = """
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
        """

        let userPrompt = """
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

        return (systemPrompt, userPrompt)
    }

    /// Legacy method for backwards compatibility
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
    /// Derives the season from a date for contextual dish generation
    private func deriveSeason(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return "primavera"
        case 6...8: return "estate"
        case 9...11: return "autunno"
        default: return "inverno"
        }
    }

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
        dietType: DietType = .normale,
        substitutionReason: String? = nil,
        debugEnabled: Bool = false
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

        // Get season for seasonal context
        let season = deriveSeason(from: dinner.date)

        // Build confirmed wines context
        let confirmedWinesContext: String
        if !dinner.confirmedWines.isEmpty {
            confirmedWinesContext = dinner.confirmedWines.map { wine in
                "- \(wine.producer ?? "") \(wine.wineName)"
            }.joined(separator: "\n")
        } else {
            confirmedWinesContext = "Nessun vino ancora confermato"
        }

        // Build system and user prompts separately
        let systemPrompt = """
        Sei un chef italiano esperto e sommelier professionista.
        Il tuo compito è generare UN SOLO piatto alternativo che si integri perfettamente nel menu esistente.
        """

        let userPrompt = """
        CONTESTO CENA:
        - Titolo: \(dinner.title)
        - Data: \(dateFormatter.string(from: dinner.date)) (\(season))
        - Persone: \(dinner.guestCount)
        - Occasione: \(dinner.occasion ?? "Convivio")
        - Tipo di cucina: \(cuisineType)
        - Dieta/restrizioni: \(dietType.rawValue)
        \(preferencesContext.isEmpty ? "" : preferencesContext)
        \(dinner.notes.map { "- Note dell'utente (PRIORITÀ MASSIMA): \($0)" } ?? "")

        ALTRI PIATTI NEL MENU (evita ripetizione ingredienti):
        \(allDishesContext)

        ALTRI PIATTI NELLA STESSA PORTATA:
        \(otherDishes.isEmpty ? "Nessun altro piatto" : otherDishes)

        VINI CONFERMATI (mantieni compatibilità):
        \(confirmedWinesContext)

        VINI ABBINATI ALLA PORTATA:
        \(getWinePairingsForCourse(courseName, from: currentMenu))

        CANTINA DISPONIBILE:
        \(wineInventory)

        RICHIESTA:
        Sostituisci il piatto "\(dishToReplace.nome)" per la portata \(courseName).
        \(substitutionReason.map { "Motivo sostituzione: \($0)" } ?? "")

        Genera un piatto alternativo che:
        1. Si integri armonicamente con gli altri piatti
        2. Sia appropriato per la stagione (\(season))
        3. Si abbini ai vini già selezionati
        4. Non ripeta ingredienti principali già usati
        5. Sia DIVERSO da "\(dishToReplace.nome)"
        6. Sia coerente con lo stile del menu (\(cuisineType))
        7. Rispetti le restrizioni dietetiche (\(dietType.rawValue))

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

        // Intercept prompt if debug mode enabled
        let finalPrompt: String
        if debugEnabled {
            guard let config = await PromptInterceptionService.shared.interceptPrompt(
                identifier: .dishRegeneration,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                debugEnabled: true
            ) else {
                throw PromptInterceptionError.cancelled
            }
            finalPrompt = config.combinedPrompt
        } else {
            finalPrompt = systemPrompt + "\n\n" + userPrompt
        }

        // Use gpt-4o-mini for single dish regeneration - faster and cheaper
        let responseText = try await OpenAIService.shared.generateMenuWithGPT(
            prompt: finalPrompt,
            model: .gpt4oMini  // Simple task: single dish replacement
        )
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

// MARK: - Wine Editing Methods

extension MenuGeneratorService {
    /// Regenerate a single wine pairing while maintaining menu coherence
    func regenerateWine(
        wineType: String, // "cellar" or "purchase"
        wineIndex: Int,
        currentMenu: MenuResponse,
        dinner: DinnerEvent,
        wines: [Wine],
        bottles: [Bottle],
        tastePreferences: TastePreferences?
    ) async throws -> MenuResponse {
        let wineInventory = buildWineInventory(bottles: bottles.filter { $0.quantity > 0 })
        let tastePrefsString = buildTastePreferences(tastePreferences)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")

        // Get current wine info for context
        var currentWineName = ""
        var portata = ""

        if wineType == "cellar" {
            let cellarWines = currentMenu.abbinamenti.filter { $0.vino.provenienza == .cantina }
            if wineIndex < cellarWines.count {
                currentWineName = "\(cellarWines[wineIndex].vino.produttore) \(cellarWines[wineIndex].vino.nome)"
                portata = cellarWines[wineIndex].portata
            }
        } else {
            if wineIndex < currentMenu.suggerimentiAcquisto.count {
                let suggestion = currentMenu.suggerimentiAcquisto[wineIndex]
                currentWineName = "\(suggestion.produttore) \(suggestion.vino)"
                portata = suggestion.abbinamentoIdeale
            }
        }

        // Build menu context
        let menuContext = currentMenu.menu.allCourses.map { course in
            "\(course.name): \(course.dishes.map { $0.nome }.joined(separator: ", "))"
        }.joined(separator: "\n")

        // Build existing wines context (exclude the one being replaced)
        var existingWines: [String] = []
        for pairing in currentMenu.abbinamenti {
            if wineType == "cellar" && pairing.vino.provenienza == .cantina {
                let cellarIdx = currentMenu.abbinamenti.filter { $0.vino.provenienza == .cantina }.firstIndex { $0.id == pairing.id } ?? -1
                if cellarIdx == wineIndex { continue }
            }
            existingWines.append("\(pairing.vino.produttore) \(pairing.vino.nome) - \(pairing.portata)")
        }
        for (idx, suggestion) in currentMenu.suggerimentiAcquisto.enumerated() {
            if wineType == "purchase" && idx == wineIndex { continue }
            existingWines.append("\(suggestion.produttore) \(suggestion.vino) (da acquistare) - \(suggestion.abbinamentoIdeale)")
        }

        let isCellar = wineType == "cellar"
        let prompt = """
        Sei un sommelier professionista italiano.
        Devi suggerire UN SOLO vino alternativo per sostituire "\(currentWineName)".

        TIPO DI SUGGERIMENTO RICHIESTO: \(isCellar ? "VINO DALLA CANTINA" : "VINO DA ACQUISTARE")

        CONTESTO DELLA CENA:
        - Titolo: \(dinner.title)
        - Data: \(dateFormatter.string(from: dinner.date))
        - Persone: \(dinner.guestCount)
        - Occasione: \(dinner.occasion ?? "Convivio")
        \(dinner.notes.map { "- Note: \($0)" } ?? "")

        MENU DELLA CENA:
        \(menuContext)

        VINI GIÀ SELEZIONATI (evita duplicati):
        \(existingWines.isEmpty ? "Nessun altro vino" : existingWines.joined(separator: "\n"))

        PREFERENZE GUSTO:
        \(tastePrefsString)

        \(isCellar ? """
        CANTINA DISPONIBILE (SCEGLI SOLO DA QUI):
        \(wineInventory)
        """ : """
        Suggerisci un vino di qualità da acquistare, indicando produttore specifico e annata consigliata.
        """)

        IMPORTANTE:
        - Il vino deve essere DIVERSO da "\(currentWineName)"
        - Deve abbinarsi bene con \(portata.isEmpty ? "il menu" : portata)
        - Valuta la compatibilità con le preferenze gusto

        Rispondi SOLO con JSON valido:
        \(isCellar ? """
        {
          "portata": "\(portata.isEmpty ? "primi" : portata)",
          "vino": {
            "nome": "string",
            "produttore": "string",
            "annata": "string o null",
            "provenienza": "cantina",
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
        """ : """
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
        """)
        """

        // Use gpt-4o-mini for single wine regeneration - faster and cheaper
        let responseText = try await OpenAIService.shared.generateMenuWithGPT(
            prompt: prompt,
            model: .gpt4oMini  // Simple task: single wine suggestion
        )

        if isCellar {
            let newPairing = try parseSingleWinePairing(responseText)
            return replaceWinePairingInMenu(currentMenu, wineIndex: wineIndex, newPairing: newPairing)
        } else {
            let newSuggestion = try parseSingleWineSuggestion(responseText)
            return replaceWineSuggestionInMenu(currentMenu, suggestionIndex: wineIndex, newSuggestion: newSuggestion)
        }
    }

    /// Delete a wine from the menu
    nonisolated func deleteWine(
        wineType: String, // "cellar" or "purchase"
        wineIndex: Int,
        from currentMenu: MenuResponse
    ) -> MenuResponse {
        if wineType == "cellar" {
            let cellarWines = currentMenu.abbinamenti.filter { $0.vino.provenienza == .cantina }
            guard wineIndex < cellarWines.count else { return currentMenu }

            let wineToRemove = cellarWines[wineIndex]
            let updatedAbbinamenti = currentMenu.abbinamenti.filter { $0.id != wineToRemove.id }

            return MenuResponse(
                menu: currentMenu.menu,
                abbinamenti: updatedAbbinamenti,
                suggerimentiAcquisto: currentMenu.suggerimentiAcquisto,
                noteServizio: currentMenu.noteServizio,
                galateo: currentMenu.galateo
            )
        } else {
            var updatedSuggestions = currentMenu.suggerimentiAcquisto
            guard wineIndex < updatedSuggestions.count else { return currentMenu }

            updatedSuggestions.remove(at: wineIndex)

            return MenuResponse(
                menu: currentMenu.menu,
                abbinamenti: currentMenu.abbinamenti,
                suggerimentiAcquisto: updatedSuggestions,
                noteServizio: currentMenu.noteServizio,
                galateo: currentMenu.galateo
            )
        }
    }

    // MARK: - Wine Parsing Helpers

    private func parseSingleWinePairing(_ text: String) throws -> MenuWinePairing {
        var cleanJson = text.trimmingCharacters(in: .whitespacesAndNewlines)

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

        return try JSONDecoder().decode(MenuWinePairing.self, from: data)
    }

    private func parseSingleWineSuggestion(_ text: String) throws -> WineSuggestion {
        var cleanJson = text.trimmingCharacters(in: .whitespacesAndNewlines)

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

        return try JSONDecoder().decode(WineSuggestion.self, from: data)
    }

    private func replaceWinePairingInMenu(_ menu: MenuResponse, wineIndex: Int, newPairing: MenuWinePairing) -> MenuResponse {
        let cellarWines = menu.abbinamenti.filter { $0.vino.provenienza == .cantina }
        guard wineIndex < cellarWines.count else { return menu }

        let wineToReplace = cellarWines[wineIndex]
        var updatedAbbinamenti = menu.abbinamenti

        if let idx = updatedAbbinamenti.firstIndex(where: { $0.id == wineToReplace.id }) {
            updatedAbbinamenti[idx] = newPairing
        }

        return MenuResponse(
            menu: menu.menu,
            abbinamenti: updatedAbbinamenti,
            suggerimentiAcquisto: menu.suggerimentiAcquisto,
            noteServizio: menu.noteServizio,
            galateo: menu.galateo
        )
    }

    private func replaceWineSuggestionInMenu(_ menu: MenuResponse, suggestionIndex: Int, newSuggestion: WineSuggestion) -> MenuResponse {
        var updatedSuggestions = menu.suggerimentiAcquisto
        guard suggestionIndex < updatedSuggestions.count else { return menu }

        updatedSuggestions[suggestionIndex] = newSuggestion

        return MenuResponse(
            menu: menu.menu,
            abbinamenti: menu.abbinamenti,
            suggerimentiAcquisto: updatedSuggestions,
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

        // Use gpt-4o-mini for invite generation - simple text task
        let response = try await OpenAIService.shared.generateMenuWithGPT(
            prompt: prompt,
            model: .gpt4oMini  // Simple task: text generation
        )
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

// MARK: - Detailed Menu Generation

extension MenuGeneratorService {
    /// Generate a detailed menu with recipes, timeline, shopping list, and service advice
    func generateDetailedMenu(
        for dinner: DinnerEvent,
        menu: MenuResponse,
        debugEnabled: Bool = false
    ) async throws -> DettaglioMenuCompleto {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "it_IT")

        // Build menu context
        let menuContext = menu.menu.allCourses.map { course in
            course.dishes.map { dish in
                """
                PORTATA: \(course.name)
                PIATTO: \(dish.nome)
                DESCRIZIONE: \(dish.descrizione)
                INGREDIENTI: \(dish.ricetta.ingredienti.map { $0.displayText }.joined(separator: ", "))
                TEMPO PREP: \(dish.ricetta.tempoPreparazione) min
                TEMPO COTTURA: \(dish.ricetta.tempoCottura) min
                PROCEDIMENTO: \(dish.ricetta.procedimento.joined(separator: " | "))
                """
            }.joined(separator: "\n\n")
        }.joined(separator: "\n\n---\n\n")

        // Build wines context
        let winesContext = menu.abbinamenti.map { pairing in
            "\(pairing.vino.produttore) \(pairing.vino.nome) - \(pairing.portata)"
        }.joined(separator: "\n")

        let systemPrompt = """
        Sei un executive chef e sommelier italiano con esperienza in eventi di alto livello.
        Devi generare un documento completo e dettagliato per la gestione di una cena.
        """

        let userPrompt = """
        DATI CENA:
        - Titolo: \(dinner.title)
        - Data: \(dateFormatter.string(from: dinner.date))
        - Ospiti: \(dinner.guestCount) persone
        - Occasione: \(dinner.occasion ?? "Cena")
        \(dinner.notes.map { "- Note: \($0)" } ?? "")

        MENU COMPLETO:
        \(menuContext)

        VINI ABBINATI:
        \(winesContext.isEmpty ? "Nessun vino selezionato" : winesContext)

        Genera un documento JSON completo con:

        1. PORTATE DETTAGLIATE: Per ogni piatto, ricetta completa con:
           - Ingredienti categorizzati (verdure, carni, latticini, ecc.)
           - Quantità calibrate per \(dinner.guestCount) persone
           - Procedimento dettagliato passo-passo
           - Consigli dello chef

        2. TIMELINE: Cronoprogramma delle preparazioni in minuti prima della cena:
           - Cosa preparare il giorno prima
           - Preparazioni mattutine
           - Ultime ore prima del servizio
           - Momenti di servizio

        3. SHOPPING LIST: Lista spesa organizzata per categoria:
           - Verdure/Ortaggi
           - Carni
           - Pesce (se presente)
           - Latticini
           - Pane e prodotti da forno
           - Spezie e aromi
           - Vini
           - Altro

        4. SERVIZIO VINI: Per ogni vino:
           - Temperatura di servizio
           - Tempo di decantazione (se necessario)
           - Tipo di bicchiere
           - Ordine di servizio
           - Abbinamento specifico

        5. MISE EN PLACE:
           - Disposizione tavola
           - Ordine di servizio delle portate
           - Consigli generali

        6. ETIQUETTE: 3-5 consigli di galateo per l'occasione

        Rispondi SOLO con JSON valido seguendo questo schema:
        {
          "dinner_title": "\(dinner.title)",
          "dinner_date": "\(ISO8601DateFormatter().string(from: dinner.date))",
          "guest_count": \(dinner.guestCount),
          "portate": [
            {
              "course_name": "Antipasti",
              "dish_name": "Nome piatto",
              "recipe": {
                "ingredients": [
                  {"name": "ingrediente", "quantity": "100", "unit": "g", "category": "verdure"}
                ],
                "servings": \(dinner.guestCount),
                "prep_time": 30,
                "cook_time": 15,
                "procedure": ["Passo 1", "Passo 2"],
                "chef_tips": ["Consiglio 1"]
              },
              "wine_note": "Abbinamento consigliato..."
            }
          ],
          "timeline": [
            {"time_offset": -1440, "description": "Preparare X", "related_dish": "Nome piatto"},
            {"time_offset": -60, "description": "Iniziare Y", "related_dish": null},
            {"time_offset": 0, "description": "Servire antipasti", "related_dish": "Antipasti"}
          ],
          "shopping_list": [
            {
              "category": "Verdure",
              "items": [
                {"name": "Pomodori", "quantity": "500g", "search_query": "pomodori san marzano"}
              ]
            }
          ],
          "wine_service": [
            {
              "wine_name": "Nome Vino",
              "serving_temp": "16-18",
              "decant_time": "30 minuti",
              "glass_type": "Bordeaux",
              "serving_order": 1,
              "paired_with": "Primi piatti"
            }
          ],
          "mise_en_place": {
            "table_settings": ["Consiglio disposizione 1"],
            "serving_order": ["Prima si serve...", "Poi..."],
            "general_tips": ["Tip 1"]
          },
          "etiquette": ["Consiglio galateo 1", "Consiglio galateo 2"]
        }
        """

        // Intercept prompt if debug mode enabled
        let finalPrompt: String
        if debugEnabled {
            guard let config = await PromptInterceptionService.shared.interceptPrompt(
                identifier: .detailedMenu,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                debugEnabled: true
            ) else {
                throw PromptInterceptionError.cancelled
            }
            finalPrompt = config.combinedPrompt
        } else {
            finalPrompt = systemPrompt + "\n\n" + userPrompt
        }

        // Use gpt-4o for detailed menu - complex task with recipes and timeline
        let responseText = try await OpenAIService.shared.generateMenuWithGPT(
            prompt: finalPrompt,
            model: .gpt4o  // Complex task: detailed recipes and timeline
        )
        return try parseDetailedMenu(responseText)
    }

    /// Parse the detailed menu response
    private func parseDetailedMenu(_ text: String) throws -> DettaglioMenuCompleto {
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

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DettaglioMenuCompleto.self, from: data)
        } catch {
            print("❌ Detailed Menu Parsing Error: \(error)")
            throw OpenAIError.parseError
        }
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
