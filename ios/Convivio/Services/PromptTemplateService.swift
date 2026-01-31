import Foundation

// MARK: - Prompt Template Service

/// Service for managing and building localized prompt templates
@MainActor
class PromptTemplateService: ObservableObject {
    static let shared = PromptTemplateService()

    private init() {
        loadCustomTemplates()
    }

    // MARK: - Template Storage

    /// Custom user overrides for templates
    @Published private(set) var customTemplates: [String: PromptTemplateData] = [:]

    // MARK: - Template IDs

    enum TemplateID: String, CaseIterable {
        case menuCompleto = "menu_completo"
        case rigeneraPiatto = "rigenera_piatto"
        case suggerimentoSommelier = "suggerimento_sommelier"
        case generaInvito = "genera_invito"
        case noteRicette = "note_ricette"
        case noteVini = "note_vini"
        case noteAccoglienza = "note_accoglienza"

        var displayName: String {
            switch self {
            case .menuCompleto: return "Generazione Menu"
            case .rigeneraPiatto: return "Rigenerazione Piatto"
            case .suggerimentoSommelier: return "Sommelier AI"
            case .generaInvito: return "Generazione Invito"
            case .noteRicette: return "Note Ricette"
            case .noteVini: return "Note Vini"
            case .noteAccoglienza: return "Note Accoglienza"
            }
        }

        var description: String {
            switch self {
            case .menuCompleto: return "Genera un menu completo con abbinamenti vino"
            case .rigeneraPiatto: return "Sostituisce un singolo piatto nel menu"
            case .suggerimentoSommelier: return "Suggerisce vini dalla cantina"
            case .generaInvito: return "Crea messaggi di invito per gli ospiti"
            case .noteRicette: return "Genera ricette dettagliate e timeline"
            case .noteVini: return "Prepara note di servizio vini"
            case .noteAccoglienza: return "Consigli per accoglienza e gestione serata"
            }
        }

        var recommendedModel: String {
            switch self {
            case .menuCompleto, .noteRicette, .noteVini, .noteAccoglienza:
                return "gpt-4o"
            case .rigeneraPiatto, .suggerimentoSommelier, .generaInvito:
                return "gpt-4o-mini"
            }
        }
    }

    // MARK: - Template Data Structure

    struct PromptTemplateData: Codable, Equatable {
        var systemPrompt: String
        var userPromptTemplate: String

        static func == (lhs: PromptTemplateData, rhs: PromptTemplateData) -> Bool {
            lhs.systemPrompt == rhs.systemPrompt && lhs.userPromptTemplate == rhs.userPromptTemplate
        }
    }

    // MARK: - Localization Header

    /// Standard localization header for all system prompts
    private func localizationHeader(locale: LocaleContext) -> String {
        """
        Rispondi SEMPRE in \(locale.language).
        Adatta riferimenti culturali, ingredienti tipici, tradizioni e consigli al contesto di \(locale.locationForPrompts).
        Privilegia ingredienti locali, stagionali e facilmente reperibili in \(locale.country ?? "questo paese").
        Rispetta le tradizioni gastronomiche e di ospitalità tipiche di \(locale.country ?? "questo paese").
        """
    }

    /// Dietary restrictions warning
    private func restrictionsWarning(_ restrictions: String?) -> String {
        guard let restrictions = restrictions, !restrictions.isEmpty else {
            return ""
        }
        return """

        IMPORTANTE - RESTRIZIONI ALIMENTARI: \(restrictions)
        Tutti i piatti, suggerimenti e ricette DEVONO rispettare queste restrizioni. Non suggerire MAI ingredienti o preparazioni incompatibili.
        """
    }

    // MARK: - Get Template

    /// Get a template (custom if available, otherwise default)
    func getTemplate(for id: TemplateID) -> PromptTemplateData {
        if let custom = customTemplates[id.rawValue] {
            return custom
        }
        return getDefaultTemplate(for: id)
    }

    /// Check if a template has custom overrides
    func hasCustomTemplate(for id: TemplateID) -> Bool {
        customTemplates[id.rawValue] != nil
    }

    /// Reset a template to default
    func resetTemplate(for id: TemplateID) {
        customTemplates.removeValue(forKey: id.rawValue)
        saveCustomTemplates()
    }

    /// Reset all templates to default
    func resetAllTemplates() {
        customTemplates.removeAll()
        saveCustomTemplates()
    }

    /// Save a custom template
    func saveCustomTemplate(_ template: PromptTemplateData, for id: TemplateID) {
        customTemplates[id.rawValue] = template
        saveCustomTemplates()
    }

    // MARK: - Build Prompts

    /// Build the final system prompt with locale context
    func buildSystemPrompt(
        for id: TemplateID,
        locale: LocaleContext,
        restrictions: String? = nil
    ) -> String {
        let template = getTemplate(for: id)
        var prompt = localizationHeader(locale: locale)
        prompt += "\n\n"
        prompt += template.systemPrompt
        prompt += restrictionsWarning(restrictions)
        return prompt
    }

    /// Build the user prompt with placeholders replaced
    func buildUserPrompt(
        for id: TemplateID,
        locale: LocaleContext,
        placeholders: [String: String]
    ) -> String {
        let template = getTemplate(for: id)
        var prompt = template.userPromptTemplate

        // Standard locale placeholders
        prompt = prompt.replacingOccurrences(of: "{lingua}", with: locale.language)
        prompt = prompt.replacingOccurrences(of: "{citta}", with: locale.city ?? "non specificata")
        prompt = prompt.replacingOccurrences(of: "{paese}", with: locale.country ?? "non specificato")

        // Custom placeholders
        for (key, value) in placeholders {
            prompt = prompt.replacingOccurrences(of: "{\(key)}", with: value)
        }

        return prompt
    }

    // MARK: - Persistence

    private var customTemplatesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_prompts.json")
    }

    private func loadCustomTemplates() {
        do {
            let data = try Data(contentsOf: customTemplatesURL)
            customTemplates = try JSONDecoder().decode([String: PromptTemplateData].self, from: data)
        } catch {
            // No custom templates yet
            customTemplates = [:]
        }
    }

    private func saveCustomTemplates() {
        do {
            let data = try JSONEncoder().encode(customTemplates)
            try data.write(to: customTemplatesURL, options: .atomic)
        } catch {
            print("Failed to save custom templates: \(error)")
        }
    }

    // MARK: - Default Templates

    func getDefaultTemplate(for id: TemplateID) -> PromptTemplateData {
        switch id {
        case .menuCompleto:
            return defaultMenuCompletoTemplate
        case .rigeneraPiatto:
            return defaultRigeneraPiattoTemplate
        case .suggerimentoSommelier:
            return defaultSuggerimentoSommelierTemplate
        case .generaInvito:
            return defaultGeneraInvitoTemplate
        case .noteRicette:
            return defaultNoteRicetteTemplate
        case .noteVini:
            return defaultNoteViniTemplate
        case .noteAccoglienza:
            return defaultNoteAccoglienzaTemplate
        }
    }

    // MARK: - Default Template Definitions

    private var defaultMenuCompletoTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei un chef consulente che crea menu per cene casalinghe. Genera menu equilibrati, realizzabili, con abbinamenti vino appropriati.

            Regole:
            - Menu coerente con tipo cucina richiesto
            - Porzioni calibrate sul numero di ospiti
            - Difficoltà adatta a cucina casalinga
            - Ingredienti reperibili nel paese dell'utente
            - Abbinamenti vino dalla cantina quando possibile
            - Rispetta SEMPRE le restrizioni alimentari indicate

            Output: JSON strutturato, nessun markdown.
            """,
            userPromptTemplate: """
            Genera un menu completo per questa cena.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Ospiti: {numeroOspiti}
            - Tipo cucina: {tipoCucina}
            - Restrizioni alimentari: {restrizioni}
            - Note: {note}

            CANTINA DISPONIBILE
            {listaVini}

            OUTPUT JSON (rispetta esattamente questa struttura)
            """
        )
    }

    private var defaultRigeneraPiattoTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei un chef consulente. Genera un piatto alternativo coerente con il contesto della cena.

            Regole:
            - Rispetta SEMPRE le restrizioni alimentari
            - Considera stagionalità
            - Evita ripetizioni con altri piatti nel menu
            - Mantieni coerenza con tipo cucina
            - Usa ingredienti facilmente reperibili

            Output: JSON singolo piatto, nessun markdown.
            """,
            userPromptTemplate: """
            Genera un piatto alternativo.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Ospiti: {numeroOspiti}
            - Tipo cucina: {tipoCucina}
            - Restrizioni alimentari: {restrizioni}
            - Note: {note}
            - Stagione: {stagione}

            PIATTO DA SOSTITUIRE
            - Categoria: {categoria}
            - Nome attuale: {nomePiatto}

            ALTRI PIATTI NEL MENU
            {listaAltriPiatti}

            VINI ABBINATI
            {listaVini}

            OUTPUT JSON
            """
        )
    }

    private var defaultSuggerimentoSommelierTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei un sommelier professionista. Suggerisci vini appropriati privilegiando la cantina dell'utente.

            Regole:
            - Prima cerca nella cantina disponibile
            - Suggerisci alternative esterne solo se necessario
            - Spiega il perché dell'abbinamento
            - Considera occasione e preferenze

            Output: JSON strutturato, nessun markdown.
            """,
            userPromptTemplate: """
            Suggerisci un vino per questo abbinamento.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            RICHIESTA
            - Piatto/occasione: {richiesta}
            - Preferenze: {preferenze}
            - Restrizioni: {restrizioni}

            CANTINA DISPONIBILE
            {listaVini}

            OUTPUT JSON
            """
        )
    }

    private var defaultGeneraInvitoTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Scrivi inviti per cene. Messaggi eleganti, caldi, adatti a WhatsApp o email.

            Regole:
            - Mai elencare menu completo, solo anticipazioni vaghe se richiesto
            - Tono appropriato allo stile richiesto
            - Formule di cortesia appropriate alla cultura del paese
            - Lunghezza: 3-5 frasi

            Output: solo testo messaggio, niente JSON.
            """,
            userPromptTemplate: """
            Genera un invito per una cena.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Luogo: {luogo}
            - Dress code: {dressCode}
            - Stile invito: {stile}
            - Anticipazioni menu: {anticipazioni}
            - Restrizioni alimentari previste: {restrizioni}

            Scrivi il messaggio di invito.
            """
        )
    }

    private var defaultNoteRicetteTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei uno chef che prepara note operative per cuochi casalinghi.

            Regole:
            - Dosi esatte per numero ospiti indicato
            - Tempi precisi per ogni fase
            - Ingredienti facilmente reperibili
            - Suggerisci sostituzioni locali se ingrediente difficile da trovare
            - Consigli impiattamento con descrizione visiva

            Output: JSON strutturato, nessun markdown.
            """,
            userPromptTemplate: """
            Genera note ricette operative.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Ospiti: {numeroOspiti}
            - Tipo cucina: {tipoCucina}
            - Restrizioni alimentari: {restrizioni}
            - Note: {note}

            MENU
            {menuCompleto}

            OUTPUT JSON con timeline_cucina, ricette dettagliate, lista_spesa, consigli_chef
            """
        )
    }

    private var defaultNoteViniTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei un sommelier che prepara note di servizio.

            Regole:
            - Temperature servizio precise
            - Tempistiche gestione (frigo, apertura, decantazione)
            - Bicchieri appropriati
            - Sequenza servizio ottimale
            - Presenta il vino secondo etichetta locale

            Output: JSON strutturato, nessun markdown.
            """,
            userPromptTemplate: """
            Genera note servizio vini.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Ospiti: {numeroOspiti}

            MENU RIEPILOGO
            {menuRiepilogo}

            VINI CONFERMATI
            {listaViniConfermati}

            OUTPUT JSON con timeline_vini, schede_vino, sequenza_servizio, attrezzatura_necessaria, consigli_sommelier
            """
        )
    }

    private var defaultNoteAccoglienzaTemplate: PromptTemplateData {
        PromptTemplateData(
            systemPrompt: """
            Sei un esperto di hospitality. Prepari note per gestire una cena memorabile.

            Regole:
            - Apparecchiatura secondo tradizione locale
            - Accoglienza appropriata alla cultura
            - Gestione tempi e conversazione
            - Post-cena con usanze locali (caffè, digestivo, tè, ecc.)

            Output: JSON strutturato, nessun markdown.
            """,
            userPromptTemplate: """
            Genera note accoglienza e gestione serata.

            CONTESTO UTENTE
            - Lingua: {lingua}
            - Città: {citta}
            - Paese: {paese}

            CENA
            - Data e ora: {dataOra}
            - Ospiti: {numeroOspiti}
            - Tipo cucina: {tipoCucina}
            - Dress code: {dressCode}
            - Restrizioni: {restrizioni}
            - Note: {note}

            MENU RIEPILOGO
            {menuRiepilogo}

            OUTPUT JSON con preparazione_ambiente, accoglienza, gestione_serata, post_cena, consigli_host
            """
        )
    }
}
