import Foundation

// MARK: - Request Models

struct MenuRequest {
    let titolo: String
    let data: Date
    let persone: Int
    let occasione: String?
    let tipoDieta: DietType
    let tipoCucina: String
    let descrizione: String?
    let tastePreferences: TastePreferences?
}

enum DietType: String, CaseIterable, Identifiable {
    case normale = "nessuna restrizione"
    case vegetariano = "vegetariano (no carne, no pesce)"
    case vegano = "vegano (no prodotti animali)"
    case pesce = "solo pesce, no carne"
    case carne = "solo carne, no pesce"
    case senzaFormaggio = "senza latticini"
    case senzaGlutine = "senza glutine"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normale: return "Nessuna restrizione"
        case .vegetariano: return "Vegetariano"
        case .vegano: return "Vegano"
        case .pesce: return "Solo pesce"
        case .carne: return "Solo carne"
        case .senzaFormaggio: return "Senza latticini"
        case .senzaGlutine: return "Senza glutine"
        }
    }

    var icon: String {
        switch self {
        case .normale: return "fork.knife"
        case .vegetariano: return "leaf"
        case .vegano: return "leaf.circle"
        case .pesce: return "fish"
        case .carne: return "flame"
        case .senzaFormaggio: return "drop.triangle"
        case .senzaGlutine: return "wheat.slash"
        }
    }
}

// MARK: - Response Models

struct MenuResponse: Codable {
    let menu: MenuSections
    let abbinamenti: [MenuWinePairing]
    let suggerimentiAcquisto: [WineSuggestion]
    let noteServizio: String
    let galateo: GalateoSection

    enum CodingKeys: String, CodingKey {
        case menu
        case abbinamenti
        case suggerimentiAcquisto = "suggerimenti_acquisto"
        case noteServizio = "note_servizio"
        case galateo
    }
}

struct GalateoSection: Codable {
    let inviti: InvitiGalateo
    let ricevimento: RicevimentoGalateo
    let tavola: TavolaGalateo
}

struct InvitiGalateo: Codable {
    let tempistica: String
    let formulazione: String
    let conferma: String
    let consigli: [String]
}

struct RicevimentoGalateo: Codable {
    let accoglienza: String
    let aperitivo: String
    let passaggioTavola: String
    let congedo: String
    let consigli: [String]

    enum CodingKeys: String, CodingKey {
        case accoglienza
        case aperitivo
        case passaggioTavola = "passaggio_tavola"
        case congedo
        case consigli
    }
}

struct TavolaGalateo: Codable {
    let disposizione: String
    let servizio: String
    let conversazione: String
    let consigli: [String]
}

struct MenuSections: Codable {
    let antipasti: [Dish]
    let primi: [Dish]
    let secondi: [Dish]
    let contorni: [Dish]
    let dolci: [Dish]

    var allCourses: [(name: String, dishes: [Dish])] {
        [
            ("Antipasti", antipasti),
            ("Primi", primi),
            ("Secondi", secondi),
            ("Contorni", contorni),
            ("Dolci", dolci)
        ].filter { !$0.1.isEmpty }
    }
}

struct Dish: Codable, Identifiable {
    let nome: String
    let descrizione: String
    let porzioni: Int
    let ricetta: Recipe

    var id: String { nome }
}

struct Recipe: Codable {
    let ingredienti: [Ingredient]
    let tempoPreparazione: Int // minuti
    let tempoCottura: Int // minuti
    let difficolta: String // facile, media, difficile
    let procedimento: [String] // steps
    let consigli: String?

    enum CodingKeys: String, CodingKey {
        case ingredienti
        case tempoPreparazione = "tempo_preparazione"
        case tempoCottura = "tempo_cottura"
        case difficolta
        case procedimento
        case consigli
    }

    var tempoTotale: Int {
        tempoPreparazione + tempoCottura
    }
}

struct Ingredient: Codable, Identifiable {
    let nome: String
    let quantita: String
    let unita: String?

    var id: String { nome }

    var displayText: String {
        if let unita = unita, !unita.isEmpty {
            return "\(quantita) \(unita) \(nome)"
        }
        return "\(quantita) \(nome)"
    }
}

struct MenuWinePairing: Codable, Identifiable {
    let portata: String
    let vino: PairedWine

    var id: String { "\(portata)-\(vino.nome)" }
}

struct PairedWine: Codable {
    let nome: String
    let produttore: String
    let annata: String?
    let provenienza: WineSource
    let quantitaNecessaria: Int
    let motivazione: String
    let compatibilita: WineCompatibility?

    enum CodingKeys: String, CodingKey {
        case nome
        case produttore
        case annata
        case provenienza
        case quantitaNecessaria = "quantita_necessaria"
        case motivazione
        case compatibilita
    }
}

struct WineCompatibility: Codable {
    let punteggio: Int // 1-100
    let motivazione: String
    let puntiForza: [String]
    let puntiDeboli: [String]

    enum CodingKeys: String, CodingKey {
        case punteggio
        case motivazione
        case puntiForza = "punti_forza"
        case puntiDeboli = "punti_deboli"
    }

    var scoreColor: String {
        switch punteggio {
        case 80...100: return "green"
        case 60..<80: return "yellow"
        default: return "orange"
        }
    }
}

enum WineSource: String, Codable {
    case cantina
    case suggerimento

    var displayName: String {
        switch self {
        case .cantina: return "Cantina"
        case .suggerimento: return "Acquisto"
        }
    }

    var icon: String {
        switch self {
        case .cantina: return "house.fill"
        case .suggerimento: return "cart.fill"
        }
    }
}

struct WineSuggestion: Codable, Identifiable {
    let vino: String
    let produttore: String
    let annata: String?
    let perche: String
    let abbinamentoIdeale: String
    let compatibilita: WineCompatibility?

    var id: String { "\(produttore)-\(vino)" }

    enum CodingKeys: String, CodingKey {
        case vino
        case produttore
        case annata
        case perche
        case abbinamentoIdeale = "abbinamento_ideale"
        case compatibilita
    }

    var displayName: String {
        var name = "\(produttore) \(vino)"
        if let annata = annata {
            name += " \(annata)"
        }
        return name
    }
}

// MARK: - Cuisine Types

enum CuisineType: String, CaseIterable, Identifiable {
    case italiana = "Italiana tradizionale"
    case mediterranea = "Mediterranea"
    case pesce = "Di mare"
    case carne = "A base di carne"
    case vegetariana = "Vegetariana gourmet"
    case fusion = "Fusion"
    case regionale = "Regionale italiana"
    case internazionale = "Internazionale"

    var id: String { rawValue }
}
