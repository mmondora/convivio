import Foundation
import SwiftData

// MARK: - Dinner Note Type

enum DinnerNoteType: String, Codable, CaseIterable {
    case cucina = "cucina"  // Renamed from "ricette" for UI consistency
    case vini = "vini"
    case accoglienza = "accoglienza"

    var displayName: String {
        switch self {
        case .cucina: return "Note Cucina"
        case .vini: return "Note Vini"
        case .accoglienza: return "Note Accoglienza"
        }
    }

    var icon: String {
        switch self {
        case .cucina: return "book"
        case .vini: return "wineglass"
        case .accoglienza: return "person.2"
        }
    }

    var buttonIcon: String {
        switch self {
        case .cucina: return "📝"
        case .vini: return "🍷"
        case .accoglienza: return "🎩"
        }
    }

    var buttonLabel: String {
        switch self {
        case .cucina: return "Cucina"
        case .vini: return "Vini"
        case .accoglienza: return "Accoglienza"
        }
    }
}

// MARK: - Persisted Note Model

@Model
final class DinnerNote {
    var id: UUID
    var dinnerID: UUID
    var noteType: String  // DinnerNoteType.rawValue
    var contentJSON: String
    var generatedAt: Date

    init(dinnerID: UUID, noteType: DinnerNoteType, contentJSON: String) {
        self.id = UUID()
        self.dinnerID = dinnerID
        self.noteType = noteType.rawValue
        self.contentJSON = contentJSON
        self.generatedAt = Date()
    }

    var type: DinnerNoteType {
        DinnerNoteType(rawValue: noteType) ?? .cucina
    }
}

// MARK: - Note Ricette Models

struct NoteRicetteContent: Codable {
    let timelineCucina: [CucinaTimelineStep]
    let ricette: [RicettaDettagliata]
    let listaSpesa: [CategoriaSpesa]
    let consigliChef: [String]

    enum CodingKeys: String, CodingKey {
        case timelineCucina = "timeline_cucina"
        case ricette
        case listaSpesa = "lista_spesa"
        case consigliChef = "consigli_chef"
    }
}

struct CucinaTimelineStep: Codable, Identifiable {
    var id: String { "\(quandoMinuti)-\(descrizione.prefix(20))" }
    let quandoMinuti: Int  // minuti prima della cena (negativo)
    let quandoLabel: String
    let descrizione: String
    let piattoCorrelato: String?

    enum CodingKeys: String, CodingKey {
        case quandoMinuti = "quando_minuti"
        case quandoLabel = "quando_label"
        case descrizione
        case piattoCorrelato = "piatto_correlato"
    }
}

struct RicettaDettagliata: Codable, Identifiable {
    var id: String { nome }
    let nome: String
    let categoria: String
    let difficolta: String
    let tempoPreparazione: Int
    let tempoCottura: Int
    let preparabileAnticipo: Bool
    let ingredienti: [IngredienteRicetta]
    let procedimento: [String]
    let impiattamento: ImpiattamentoInfo?
    let consigli: String?

    enum CodingKeys: String, CodingKey {
        case nome, categoria, difficolta
        case tempoPreparazione = "tempo_preparazione"
        case tempoCottura = "tempo_cottura"
        case preparabileAnticipo = "preparabile_anticipo"
        case ingredienti, procedimento, impiattamento, consigli
    }
}

struct IngredienteRicetta: Codable, Identifiable {
    var id: String { nome }
    let nome: String
    let quantita: String
    let unita: String?
}

struct ImpiattamentoInfo: Codable {
    let descrizione: String
    let consigli: [String]?
}

struct CategoriaSpesa: Codable, Identifiable {
    var id: String { categoria }
    let categoria: String
    let items: [ItemSpesa]
}

struct ItemSpesa: Codable, Identifiable {
    var id: String { nome }
    let nome: String
    let quantita: String
}

// MARK: - Note Vini Models

struct NoteViniContent: Codable {
    let timelineVini: [TimelineVino]
    let schedeVino: [SchedaVino]
    let sequenzaServizio: [PassaggioServizio]
    let attrezzaturaNecessaria: [AttrezzaturaItem]
    let consigliSommelier: [String]

    enum CodingKeys: String, CodingKey {
        case timelineVini = "timeline_vini"
        case schedeVino = "schede_vino"
        case sequenzaServizio = "sequenza_servizio"
        case attrezzaturaNecessaria = "attrezzatura_necessaria"
        case consigliSommelier = "consigli_sommelier"
    }
}

struct TimelineVino: Codable, Identifiable {
    var id: String { "\(quandoMinuti)-\(vino)" }
    let quandoMinuti: Int
    let quandoLabel: String
    let vino: String
    let azione: String
    let icona: String  // ❄️, 🌡️, 🍾

    enum CodingKeys: String, CodingKey {
        case quandoMinuti = "quando_minuti"
        case quandoLabel = "quando_label"
        case vino, azione, icona
    }
}

struct SchedaVino: Codable, Identifiable {
    var id: String { nomeVino }
    let nomeVino: String
    let produttore: String?
    let portataAbbinata: String
    let temperaturaServizio: String
    let bicchiereConsigliato: String
    let quantitaPersona: String
    let decantazione: DecantazioneInfo?
    let comePresentare: String

    enum CodingKeys: String, CodingKey {
        case nomeVino = "nome_vino"
        case produttore
        case portataAbbinata = "portata_abbinata"
        case temperaturaServizio = "temperatura_servizio"
        case bicchiereConsigliato = "bicchiere_consigliato"
        case quantitaPersona = "quantita_persona"
        case decantazione
        case comePresentare = "come_presentare"
    }
}

struct DecantazioneInfo: Codable {
    let necessaria: Bool
    let tempo: String?
    let motivo: String?
}

struct PassaggioServizio: Codable, Identifiable {
    var id: String { "\(ordine)-\(vino)" }
    let ordine: Int
    let vino: String
    let momento: String
    let transizione: String?
}

struct AttrezzaturaItem: Codable, Identifiable {
    var id: String { nome }
    let nome: String
    let icona: String
    let quantita: Int?
}

// MARK: - Note Accoglienza Models

struct NoteAccoglienzaContent: Codable {
    let preparazioneAmbiente: PreparazioneAmbiente
    let accoglienza: AccoglienzaInfo
    let gestioneSerata: GestioneSerata
    let postCena: PostCenaInfo
    let consigliHost: [String]

    enum CodingKeys: String, CodingKey {
        case preparazioneAmbiente = "preparazione_ambiente"
        case accoglienza
        case gestioneSerata = "gestione_serata"
        case postCena = "post_cena"
        case consigliHost = "consigli_host"
    }
}

struct PreparazioneAmbiente: Codable {
    let tavola: TavolaSetup
    let atmosfera: AtmosferaSetup
    let checklistPreOspiti: [String]

    enum CodingKeys: String, CodingKey {
        case tavola, atmosfera
        case checklistPreOspiti = "checklist_pre_ospiti"
    }
}

struct TavolaSetup: Codable {
    let descrizione: String
    let tovaglia: String?
    let tovaglioli: String?
    let bicchieri: String?
    let centrotavola: String?
    let segnaposto: String?
}

struct AtmosferaSetup: Codable {
    let illuminazione: String?
    let musica: String?
    let profumo: String?
    let temperatura: String?
}

struct AccoglienzaInfo: Codable {
    let orarioArrivo: String
    let doveRicevere: String
    let aperitivo: AperitivoInfo
    let comeAccomodare: String
    let rompighiaccio: [String]

    enum CodingKeys: String, CodingKey {
        case orarioArrivo = "orario_arrivo"
        case doveRicevere = "dove_ricevere"
        case aperitivo
        case comeAccomodare = "come_accomodare"
        case rompighiaccio
    }
}

struct AperitivoInfo: Codable {
    let cosa: String
    let dove: String
    let durata: String
}

struct GestioneSerata: Codable {
    let tempiPortate: String
    let quandoSparecchiare: String
    let consigliConversazione: [String]
    let seQualcosaVaStorto: [String]

    enum CodingKeys: String, CodingKey {
        case tempiPortate = "tempi_portate"
        case quandoSparecchiare = "quando_sparecchiare"
        case consigliConversazione = "consigli_conversazione"
        case seQualcosaVaStorto = "se_qualcosa_va_storto"
    }
}

struct PostCenaInfo: Codable {
    let caffeTe: CaffTeInfo
    let digestivo: DigestivoInfo?
    let intrattenimento: String?
    let congedo: CongedoInfo

    enum CodingKeys: String, CodingKey {
        case caffeTe = "caffe_te"
        case digestivo, intrattenimento, congedo
    }
}

struct CaffTeInfo: Codable {
    let quando: String
    let come: String
}

struct DigestivoInfo: Codable {
    let cosa: String
    let quando: String
}

struct CongedoInfo: Codable {
    let segnali: String
    let saluti: String
    let omaggio: String?
}
