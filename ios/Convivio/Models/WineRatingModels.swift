import Foundation
import SwiftData

// MARK: - Quick Rating (Vivino Style)

@Model
final class QuickRating {
    var id: UUID
    var wineId: UUID
    var dataAssaggio: Date
    var rating: Double // 1.0 - 5.0, step 0.5
    var note: String?
    var occasione: String?
    var luogoDegustazione: String? // Dove è stato bevuto (ristorante, casa, enoteca, etc.)
    var loRicomprerei: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        wineId: UUID,
        dataAssaggio: Date = Date(),
        rating: Double,
        note: String? = nil,
        occasione: String? = nil,
        luogoDegustazione: String? = nil,
        loRicomprerei: Bool? = nil
    ) {
        self.id = id
        self.wineId = wineId
        self.dataAssaggio = dataAssaggio
        self.rating = rating
        self.note = note
        self.occasione = occasione
        self.luogoDegustazione = luogoDegustazione
        self.loRicomprerei = loRicomprerei
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Scheda AIS

@Model
final class SchedaAIS {
    var id: UUID
    var wineId: UUID
    var dataAssaggio: Date
    var createdAt: Date
    var updatedAt: Date

    // ESAME VISIVO
    var limpidezzaRaw: String?
    var coloreRaw: String?
    var intensitaColoreRaw: String?
    var consistenzaRaw: String?

    // Effervescenza (solo spumanti)
    var effervescenzaGranaRaw: String?
    var effervescenzaNumeroRaw: String?
    var effervescenzaPersistenzaRaw: String?

    // ESAME OLFATTIVO
    var intensitaOlfattivaRaw: String?
    var complessitaRaw: String?
    var qualitaOlfattivaRaw: String?
    var descrittoriOlfattivi: [String]

    // ESAME GUSTATIVO
    var zuccheriRaw: String?
    var alcolRaw: String?
    var polialcoliRaw: String?
    var aciditaRaw: String?
    var tanniniRaw: String? // solo rossi
    var sapiditaRaw: String?
    var corpoRaw: String?
    var equilibrioRaw: String?
    var intensitaGustativaRaw: String?
    var qualitaGustativaRaw: String?

    // VALUTAZIONE FINALE
    var statoEvolutivoRaw: String?
    var armoniaRaw: String?
    var noteLibere: String?

    init(
        id: UUID = UUID(),
        wineId: UUID,
        dataAssaggio: Date = Date()
    ) {
        self.id = id
        self.wineId = wineId
        self.dataAssaggio = dataAssaggio
        self.createdAt = Date()
        self.updatedAt = Date()
        self.descrittoriOlfattivi = []
    }

    // MARK: - Computed Enum Properties

    var limpidezza: LimpidezzaAIS? {
        get { limpidezzaRaw.flatMap { LimpidezzaAIS(rawValue: $0) } }
        set { limpidezzaRaw = newValue?.rawValue }
    }

    var colore: ColoreAIS? {
        get { coloreRaw.flatMap { ColoreAIS(rawValue: $0) } }
        set { coloreRaw = newValue?.rawValue }
    }

    var intensitaColore: IntensitaColoreAIS? {
        get { intensitaColoreRaw.flatMap { IntensitaColoreAIS(rawValue: $0) } }
        set { intensitaColoreRaw = newValue?.rawValue }
    }

    var consistenza: ConsistenzaAIS? {
        get { consistenzaRaw.flatMap { ConsistenzaAIS(rawValue: $0) } }
        set { consistenzaRaw = newValue?.rawValue }
    }

    var effervescenzaGrana: EffervescenzaGranaAIS? {
        get { effervescenzaGranaRaw.flatMap { EffervescenzaGranaAIS(rawValue: $0) } }
        set { effervescenzaGranaRaw = newValue?.rawValue }
    }

    var effervescenzaNumero: EffervescenzaNumeroAIS? {
        get { effervescenzaNumeroRaw.flatMap { EffervescenzaNumeroAIS(rawValue: $0) } }
        set { effervescenzaNumeroRaw = newValue?.rawValue }
    }

    var effervescenzaPersistenza: EffervescenzaPersistenzaAIS? {
        get { effervescenzaPersistenzaRaw.flatMap { EffervescenzaPersistenzaAIS(rawValue: $0) } }
        set { effervescenzaPersistenzaRaw = newValue?.rawValue }
    }

    var intensitaOlfattiva: IntensitaOlfattivaAIS? {
        get { intensitaOlfattivaRaw.flatMap { IntensitaOlfattivaAIS(rawValue: $0) } }
        set { intensitaOlfattivaRaw = newValue?.rawValue }
    }

    var complessita: ComplessitaOlfattivaAIS? {
        get { complessitaRaw.flatMap { ComplessitaOlfattivaAIS(rawValue: $0) } }
        set { complessitaRaw = newValue?.rawValue }
    }

    var qualitaOlfattiva: QualitaOlfattivaAIS? {
        get { qualitaOlfattivaRaw.flatMap { QualitaOlfattivaAIS(rawValue: $0) } }
        set { qualitaOlfattivaRaw = newValue?.rawValue }
    }

    var zuccheri: ZuccheriAIS? {
        get { zuccheriRaw.flatMap { ZuccheriAIS(rawValue: $0) } }
        set { zuccheriRaw = newValue?.rawValue }
    }

    var alcol: AlcolAIS? {
        get { alcolRaw.flatMap { AlcolAIS(rawValue: $0) } }
        set { alcolRaw = newValue?.rawValue }
    }

    var polialcoli: PolialcoliAIS? {
        get { polialcoliRaw.flatMap { PolialcoliAIS(rawValue: $0) } }
        set { polialcoliRaw = newValue?.rawValue }
    }

    var acidita: AciditaAIS? {
        get { aciditaRaw.flatMap { AciditaAIS(rawValue: $0) } }
        set { aciditaRaw = newValue?.rawValue }
    }

    var tannini: TanniniAIS? {
        get { tanniniRaw.flatMap { TanniniAIS(rawValue: $0) } }
        set { tanniniRaw = newValue?.rawValue }
    }

    var sapidita: SapiditaAIS? {
        get { sapiditaRaw.flatMap { SapiditaAIS(rawValue: $0) } }
        set { sapiditaRaw = newValue?.rawValue }
    }

    var corpo: CorpoAIS? {
        get { corpoRaw.flatMap { CorpoAIS(rawValue: $0) } }
        set { corpoRaw = newValue?.rawValue }
    }

    var equilibrio: EquilibrioAIS? {
        get { equilibrioRaw.flatMap { EquilibrioAIS(rawValue: $0) } }
        set { equilibrioRaw = newValue?.rawValue }
    }

    var intensitaGustativa: IntensitaGustativaAIS? {
        get { intensitaGustativaRaw.flatMap { IntensitaGustativaAIS(rawValue: $0) } }
        set { intensitaGustativaRaw = newValue?.rawValue }
    }

    var qualitaGustativa: QualitaGustativaAIS? {
        get { qualitaGustativaRaw.flatMap { QualitaGustativaAIS(rawValue: $0) } }
        set { qualitaGustativaRaw = newValue?.rawValue }
    }

    var statoEvolutivo: StatoEvolutivoAIS? {
        get { statoEvolutivoRaw.flatMap { StatoEvolutivoAIS(rawValue: $0) } }
        set { statoEvolutivoRaw = newValue?.rawValue }
    }

    var armonia: ArmoniaAIS? {
        get { armoniaRaw.flatMap { ArmoniaAIS(rawValue: $0) } }
        set { armoniaRaw = newValue?.rawValue }
    }

    // MARK: - Punteggio Calculation

    var punteggioVisivo: Int {
        var score = 0
        score += limpidezza?.punteggio ?? 0
        score += intensitaColore?.punteggio ?? 0
        score += consistenza?.punteggio ?? 0
        return score
    }

    var punteggioOlfattivo: Int {
        var score = 0
        score += intensitaOlfattiva?.punteggio ?? 0
        score += complessita?.punteggio ?? 0
        score += qualitaOlfattiva?.punteggio ?? 0
        return score
    }

    var punteggioGustativo: Int {
        var score = 0
        score += zuccheri?.punteggio ?? 0
        score += alcol?.punteggio ?? 0
        score += polialcoli?.punteggio ?? 0
        score += acidita?.punteggio ?? 0
        score += tannini?.punteggio ?? 0
        score += sapidita?.punteggio ?? 0
        score += corpo?.punteggio ?? 0
        score += equilibrio?.punteggio ?? 0
        score += intensitaGustativa?.punteggio ?? 0
        score += qualitaGustativa?.punteggio ?? 0
        return score
    }

    var punteggioFinale: Int {
        var score = 0
        score += statoEvolutivo?.punteggio ?? 0
        score += armonia?.punteggio ?? 0
        return score
    }

    var punteggioTotale: Int {
        // Base score 60 + calculated points
        // AIS scale typically goes from 60 to 100
        let rawScore = punteggioVisivo + punteggioOlfattivo + punteggioGustativo + punteggioFinale
        // Normalize to 60-100 scale (max raw score ~85-90 points)
        let normalized = 60 + Int(Double(rawScore) * 40.0 / 90.0)
        return min(100, max(60, normalized))
    }

    var completionPercentage: Double {
        var filled = 0
        var total = 14 // Base fields without tannins/effervescence

        if limpidezza != nil { filled += 1 }
        if intensitaColore != nil { filled += 1 }
        if consistenza != nil { filled += 1 }
        if intensitaOlfattiva != nil { filled += 1 }
        if complessita != nil { filled += 1 }
        if qualitaOlfattiva != nil { filled += 1 }
        if zuccheri != nil { filled += 1 }
        if alcol != nil { filled += 1 }
        if polialcoli != nil { filled += 1 }
        if acidita != nil { filled += 1 }
        if sapidita != nil { filled += 1 }
        if corpo != nil { filled += 1 }
        if equilibrio != nil { filled += 1 }
        if intensitaGustativa != nil { filled += 1 }
        if qualitaGustativa != nil { filled += 1 }
        if statoEvolutivo != nil { filled += 1 }
        if armonia != nil { filled += 1 }

        total = 17 // All base fields

        return Double(filled) / Double(total)
    }

    var isComplete: Bool {
        completionPercentage >= 0.8 // At least 80% filled
    }
}

// MARK: - AIS Enums - Esame Visivo

enum LimpidezzaAIS: String, Codable, CaseIterable, Identifiable {
    case velato = "Velato"
    case abbastanzaLimpido = "Abb. limpido"
    case limpido = "Limpido"
    case cristallino = "Cristallino"
    case brillante = "Brillante"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .velato: return 1
        case .abbastanzaLimpido: return 2
        case .limpido: return 3
        case .cristallino: return 4
        case .brillante: return 5
        }
    }
}

enum ColoreAIS: String, Codable, CaseIterable, Identifiable {
    // Bianchi
    case verdolino = "Verdolino"
    case paglierino = "Paglierino"
    case dorato = "Dorato"
    case ambrato = "Ambrato"
    // Rosati
    case rosaTenue = "Rosa tenue"
    case rosaCerasuolo = "Cerasuolo"
    case rosaChiaretto = "Chiaretto"
    // Rossi
    case rubinoChiaro = "Rubino chiaro"
    case rubino = "Rubino"
    case rubinoScuro = "Rubino scuro"
    case granato = "Granato"
    case aranciato = "Aranciato"

    var id: String { rawValue }

    var punteggio: Int { 3 } // Colore non ha punteggio, solo descrittivo

    static var bianchi: [ColoreAIS] { [.verdolino, .paglierino, .dorato, .ambrato] }
    static var rosati: [ColoreAIS] { [.rosaTenue, .rosaCerasuolo, .rosaChiaretto] }
    static var rossi: [ColoreAIS] { [.rubinoChiaro, .rubino, .rubinoScuro, .granato, .aranciato] }
}

enum IntensitaColoreAIS: String, Codable, CaseIterable, Identifiable {
    case tenue = "Tenue"
    case leggero = "Leggero"
    case abbastanzaCarico = "Abb. carico"
    case carico = "Carico"
    case moltoCarico = "Molto carico"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .tenue: return 1
        case .leggero: return 2
        case .abbastanzaCarico: return 3
        case .carico: return 4
        case .moltoCarico: return 5
        }
    }
}

enum ConsistenzaAIS: String, Codable, CaseIterable, Identifiable {
    case fluido = "Fluido"
    case pocoConsistente = "Poco consist."
    case abbastanzaConsistente = "Abb. consist."
    case consistente = "Consistente"
    case viscoso = "Viscoso"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .fluido: return 1
        case .pocoConsistente: return 2
        case .abbastanzaConsistente: return 3
        case .consistente: return 4
        case .viscoso: return 5
        }
    }
}

// Effervescenza (solo spumanti)
enum EffervescenzaGranaAIS: String, Codable, CaseIterable, Identifiable {
    case grossolana = "Grossolana"
    case abbastanzaFine = "Abb. fine"
    case fine = "Fine"
    case moltoFine = "Molto fine"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .grossolana: return 1
        case .abbastanzaFine: return 2
        case .fine: return 3
        case .moltoFine: return 4
        }
    }
}

enum EffervescenzaNumeroAIS: String, Codable, CaseIterable, Identifiable {
    case scarse = "Scarse"
    case abbastanzaNumerose = "Abb. numerose"
    case numerose = "Numerose"
    case moltoNumerose = "Molto numerose"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .scarse: return 1
        case .abbastanzaNumerose: return 2
        case .numerose: return 3
        case .moltoNumerose: return 4
        }
    }
}

enum EffervescenzaPersistenzaAIS: String, Codable, CaseIterable, Identifiable {
    case evanescente = "Evanescente"
    case abbastanzaPersistente = "Abb. persist."
    case persistente = "Persistente"
    case moltoPersistente = "Molto persist."

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .evanescente: return 1
        case .abbastanzaPersistente: return 2
        case .persistente: return 3
        case .moltoPersistente: return 4
        }
    }
}

// MARK: - AIS Enums - Esame Olfattivo

enum IntensitaOlfattivaAIS: String, Codable, CaseIterable, Identifiable {
    case carente = "Carente"
    case pocoIntenso = "Poco intenso"
    case abbastanzaIntenso = "Abb. intenso"
    case intenso = "Intenso"
    case moltoIntenso = "Molto intenso"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .carente: return 1
        case .pocoIntenso: return 2
        case .abbastanzaIntenso: return 3
        case .intenso: return 4
        case .moltoIntenso: return 5
        }
    }
}

enum ComplessitaOlfattivaAIS: String, Codable, CaseIterable, Identifiable {
    case carente = "Carente"
    case pocoComplesso = "Poco complesso"
    case abbastanzaComplesso = "Abb. complesso"
    case complesso = "Complesso"
    case ampio = "Ampio"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .carente: return 1
        case .pocoComplesso: return 2
        case .abbastanzaComplesso: return 3
        case .complesso: return 4
        case .ampio: return 5
        }
    }
}

enum QualitaOlfattivaAIS: String, Codable, CaseIterable, Identifiable {
    case comune = "Comune"
    case pocoFine = "Poco fine"
    case abbastanzaFine = "Abb. fine"
    case fine = "Fine"
    case eccellente = "Eccellente"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .comune: return 1
        case .pocoFine: return 2
        case .abbastanzaFine: return 3
        case .fine: return 4
        case .eccellente: return 5
        }
    }
}

// MARK: - AIS Enums - Esame Gustativo

enum ZuccheriAIS: String, Codable, CaseIterable, Identifiable {
    case secco = "Secco"
    case abboccato = "Abboccato"
    case amabile = "Amabile"
    case dolce = "Dolce"
    case stucchevole = "Stucchevole"

    var id: String { rawValue }

    var punteggio: Int {
        // Per vini secchi, secco = 5, per dolci invertito
        switch self {
        case .secco: return 3
        case .abboccato: return 3
        case .amabile: return 3
        case .dolce: return 3
        case .stucchevole: return 1
        }
    }
}

enum AlcolAIS: String, Codable, CaseIterable, Identifiable {
    case leggero = "Leggero"
    case pocoCaldo = "Poco caldo"
    case abbastanzaCaldo = "Abb. caldo"
    case caldo = "Caldo"
    case alcolico = "Alcolico"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .leggero: return 2
        case .pocoCaldo: return 3
        case .abbastanzaCaldo: return 4
        case .caldo: return 5
        case .alcolico: return 3
        }
    }
}

enum PolialcoliAIS: String, Codable, CaseIterable, Identifiable {
    case spigoloso = "Spigoloso"
    case pocoMorbido = "Poco morbido"
    case abbastanzaMorbido = "Abb. morbido"
    case morbido = "Morbido"
    case pastoso = "Pastoso"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .spigoloso: return 1
        case .pocoMorbido: return 2
        case .abbastanzaMorbido: return 3
        case .morbido: return 4
        case .pastoso: return 5
        }
    }
}

enum AciditaAIS: String, Codable, CaseIterable, Identifiable {
    case piatto = "Piatto"
    case pocoFresco = "Poco fresco"
    case abbastanzaFresco = "Abb. fresco"
    case fresco = "Fresco"
    case acidulo = "Acidulo"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .piatto: return 1
        case .pocoFresco: return 2
        case .abbastanzaFresco: return 3
        case .fresco: return 4
        case .acidulo: return 3
        }
    }
}

enum TanniniAIS: String, Codable, CaseIterable, Identifiable {
    case molle = "Molle"
    case pocoTannico = "Poco tannico"
    case abbastanzaTannico = "Abb. tannico"
    case tannico = "Tannico"
    case astringente = "Astringente"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .molle: return 1
        case .pocoTannico: return 2
        case .abbastanzaTannico: return 3
        case .tannico: return 4
        case .astringente: return 3
        }
    }
}

enum SapiditaAIS: String, Codable, CaseIterable, Identifiable {
    case sciapito = "Sciapito"
    case pocoSapido = "Poco sapido"
    case abbastanzaSapido = "Abb. sapido"
    case sapido = "Sapido"
    case salato = "Salato"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .sciapito: return 1
        case .pocoSapido: return 2
        case .abbastanzaSapido: return 3
        case .sapido: return 4
        case .salato: return 3
        }
    }
}

enum CorpoAIS: String, Codable, CaseIterable, Identifiable {
    case magro = "Magro"
    case leggero = "Leggero"
    case diCorpo = "Di corpo"
    case robusto = "Robusto"
    case pesante = "Pesante"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .magro: return 1
        case .leggero: return 2
        case .diCorpo: return 3
        case .robusto: return 4
        case .pesante: return 3
        }
    }
}

enum EquilibrioAIS: String, Codable, CaseIterable, Identifiable {
    case pocoEquilibrato = "Poco equilibrato"
    case abbastanzaEquilibrato = "Abb. equilibrato"
    case equilibrato = "Equilibrato"
    case armonico = "Armonico"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .pocoEquilibrato: return 2
        case .abbastanzaEquilibrato: return 3
        case .equilibrato: return 4
        case .armonico: return 5
        }
    }
}

enum IntensitaGustativaAIS: String, Codable, CaseIterable, Identifiable {
    case corto = "Corto"
    case pocoPersistente = "Poco persist."
    case abbastanzaPersistente = "Abb. persist."
    case persistente = "Persistente"
    case moltoPersistente = "Molto persist."

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .corto: return 1
        case .pocoPersistente: return 2
        case .abbastanzaPersistente: return 3
        case .persistente: return 4
        case .moltoPersistente: return 5
        }
    }
}

enum QualitaGustativaAIS: String, Codable, CaseIterable, Identifiable {
    case comune = "Comune"
    case pocoFine = "Poco fine"
    case abbastanzaFine = "Abb. fine"
    case fine = "Fine"
    case eccellente = "Eccellente"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .comune: return 1
        case .pocoFine: return 2
        case .abbastanzaFine: return 3
        case .fine: return 4
        case .eccellente: return 5
        }
    }
}

// MARK: - AIS Enums - Valutazione Finale

enum StatoEvolutivoAIS: String, Codable, CaseIterable, Identifiable {
    case immaturo = "Immaturo"
    case giovane = "Giovane"
    case pronto = "Pronto"
    case maturo = "Maturo"
    case vecchio = "Vecchio"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .immaturo: return 2
        case .giovane: return 3
        case .pronto: return 5
        case .maturo: return 4
        case .vecchio: return 2
        }
    }
}

enum ArmoniaAIS: String, Codable, CaseIterable, Identifiable {
    case pocoArmonico = "Poco armonico"
    case abbastanzaArmonico = "Abb. armonico"
    case armonico = "Armonico"
    case moltoArmonico = "Molto armonico"

    var id: String { rawValue }

    var punteggio: Int {
        switch self {
        case .pocoArmonico: return 2
        case .abbastanzaArmonico: return 3
        case .armonico: return 4
        case .moltoArmonico: return 5
        }
    }
}

// MARK: - Occasione

enum OccasioneAssaggio: String, Codable, CaseIterable, Identifiable {
    case cena = "Cena"
    case pranzo = "Pranzo"
    case aperitivo = "Aperitivo"
    case degustazione = "Degustazione"
    case festa = "Festa"
    case regalo = "Regalo ricevuto"
    case acquisto = "Acquisto"
    case altro = "Altro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cena: return "moon.stars"
        case .pranzo: return "sun.max"
        case .aperitivo: return "wineglass"
        case .degustazione: return "eyes"
        case .festa: return "party.popper"
        case .regalo: return "gift"
        case .acquisto: return "cart"
        case .altro: return "ellipsis"
        }
    }
}

// MARK: - Descrittori Olfattivi AIS

struct DescrizioniOlfattiveAIS {
    static let categorie: [String: [String]] = [
        "Fruttato": [
            "Mela", "Pera", "Pesca", "Albicocca", "Agrumi", "Limone",
            "Arancia", "Pompelmo", "Frutti tropicali", "Banana", "Ananas",
            "Frutti rossi", "Ciliegia", "Fragola", "Lampone", "Ribes",
            "Frutti neri", "Mora", "Mirtillo", "Prugna", "Frutta secca"
        ],
        "Floreale": [
            "Rosa", "Violetta", "Gelsomino", "Fiori bianchi", "Acacia",
            "Tiglio", "Lavanda", "Camomilla", "Fiori d'arancio", "Iris"
        ],
        "Erbaceo": [
            "Erba tagliata", "Fieno", "Foglia di pomodoro", "Peperone",
            "Menta", "Timo", "Rosmarino", "Salvia", "Basilico", "Eucalipto"
        ],
        "Speziato": [
            "Pepe nero", "Pepe bianco", "Cannella", "Chiodi di garofano",
            "Noce moscata", "Vaniglia", "Liquirizia", "Anice", "Zenzero"
        ],
        "Tostato": [
            "Caffè", "Cacao", "Cioccolato", "Tabacco", "Cuoio",
            "Legno", "Rovere", "Affumicato", "Caramello", "Pane tostato"
        ],
        "Minerale": [
            "Pietra focaia", "Gesso", "Grafite", "Salmastro",
            "Iodio", "Idrocarburi", "Petrolio"
        ],
        "Animale": [
            "Selvaggina", "Cuoio", "Pelliccia", "Tartufo"
        ],
        "Altro": [
            "Miele", "Cera d'api", "Burro", "Lievito", "Crosta di pane"
        ]
    ]

    static var tuttiDescrittori: [String] {
        categorie.values.flatMap { $0 }.sorted()
    }
}
