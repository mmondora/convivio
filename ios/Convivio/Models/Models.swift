import Foundation
import SwiftData

// MARK: - AI Log Entry (shared between OpenAI and Claude services)

struct AILogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let endpoint: String
    let prompt: String
    let response: String
    let duration: TimeInterval
    let success: Bool
    let error: String?

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Wine

@Model
final class Wine {
    var wineUUID: UUID?
    var name: String
    var producer: String?
    var vintage: String?
    var typeRaw: String
    var region: String?
    var country: String
    var grapes: [String]
    var alcohol: Double?
    var wineDescription: String?
    var pairings: [String]
    var averagePrice: Double?
    var createdAt: Date
    var updatedAt: Date

    // CloudKit relationships
    var cellar: Cellar?

    @Relationship(deleteRule: .cascade, inverse: \Bottle.wine)
    var bottles: [Bottle]?

    var type: WineType {
        get { WineType(rawValue: typeRaw) ?? .red }
        set { typeRaw = newValue.rawValue }
    }

    /// Returns or generates a stable UUID for this wine
    var stableUUID: UUID {
        if let existing = wineUUID {
            return existing
        }
        let newUUID = UUID()
        wineUUID = newUUID
        return newUUID
    }

    init(
        name: String,
        producer: String? = nil,
        vintage: String? = nil,
        type: WineType = .red,
        region: String? = nil,
        country: String = "Italia",
        grapes: [String] = [],
        alcohol: Double? = nil,
        wineDescription: String? = nil,
        pairings: [String] = [],
        averagePrice: Double? = nil
    ) {
        self.wineUUID = UUID()
        self.name = name
        self.producer = producer
        self.vintage = vintage
        self.typeRaw = type.rawValue
        self.region = region
        self.country = country
        self.grapes = grapes
        self.alcohol = alcohol
        self.wineDescription = wineDescription
        self.pairings = pairings
        self.averagePrice = averagePrice
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var displayName: String {
        var parts: [String] = []
        if let producer = producer { parts.append(producer) }
        parts.append(name)
        if let vintage = vintage { parts.append(vintage) }
        return parts.joined(separator: " ")
    }
}

enum WineType: String, Codable, CaseIterable {
    case red
    case white
    case rose = "rosé"
    case sparkling
    case dessert
    case fortified

    var displayName: String {
        switch self {
        case .red: return "Rosso"
        case .white: return "Bianco"
        case .rose: return "Rosato"
        case .sparkling: return "Spumante"
        case .dessert: return "Dolce"
        case .fortified: return "Fortificato"
        }
    }

    var icon: String {
        switch self {
        case .red: return "🍷"
        case .white: return "🥂"
        case .rose: return "🌸"
        case .sparkling: return "🍾"
        case .dessert: return "🍯"
        case .fortified: return "🥃"
        }
    }

    var color: String {
        switch self {
        case .red: return "WineRed"
        case .white: return "WineWhite"
        case .rose: return "WineRose"
        case .sparkling: return "WineSparkling"
        case .dessert: return "WineDessert"
        case .fortified: return "WineFortified"
        }
    }
}

// MARK: - Bottle

@Model
final class Bottle {
    var wine: Wine?
    var locationZone: String?
    var locationRack: Int?
    var locationShelf: Int?
    var locationPosition: Int?
    // New storage system
    var storageContainer: StorageContainer?
    var positionInContainer: String?  // Free text: "scaffale 3", "ripiano alto", "slot 12"
    var purchaseDate: Date?
    var purchasePrice: Double?
    var purchaseLocation: String?
    var quantity: Int
    var drinkFrom: String?
    var drinkTo: String?
    var drinkPeak: String?
    var notes: String?
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    // Wine Review/Tasting data
    var reviewData: Data?

    var review: WineReview? {
        get {
            guard let data = reviewData else { return nil }
            return try? JSONDecoder().decode(WineReview.self, from: data)
        }
        set {
            reviewData = try? JSONEncoder().encode(newValue)
        }
    }

    var status: BottleStatus {
        get { BottleStatus(rawValue: statusRaw) ?? .available }
        set { statusRaw = newValue.rawValue }
    }

    var location: String? {
        var parts: [String] = []
        if let zone = locationZone { parts.append(zone) }
        if let rack = locationRack { parts.append("R\(rack)") }
        if let shelf = locationShelf { parts.append("S\(shelf)") }
        if let pos = locationPosition { parts.append("P\(pos)") }
        return parts.isEmpty ? nil : parts.joined(separator: "-")
    }

    init(
        wine: Wine? = nil,
        quantity: Int = 1,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseLocation: String? = nil,
        status: BottleStatus = .available,
        notes: String? = nil,
        locationZone: String? = nil,
        locationRack: Int? = nil,
        locationShelf: Int? = nil,
        locationPosition: Int? = nil
    ) {
        self.wine = wine
        self.quantity = quantity
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.purchaseLocation = purchaseLocation
        self.statusRaw = status.rawValue
        self.notes = notes
        self.locationZone = locationZone
        self.locationRack = locationRack
        self.locationShelf = locationShelf
        self.locationPosition = locationPosition
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum BottleStatus: String, Codable, CaseIterable {
    case available
    case reserved
    case consumed
    case gifted

    var displayName: String {
        switch self {
        case .available: return "Disponibile"
        case .reserved: return "Riservata"
        case .consumed: return "Consumata"
        case .gifted: return "Regalata"
        }
    }
}

// MARK: - Dinner Event

@Model
final class DinnerEvent {
    var title: String
    var date: Date
    var guestCount: Int
    var guestsData: Data?
    var occasion: String?
    var notes: String?
    var menuData: Data?
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    // CloudKit relationships
    var cellar: Cellar?

    // Wine confirmation data
    var confirmedWinesData: Data?
    var notificationsScheduled: Bool = false
    var postDinnerNotificationId: String?  // Notification for bottle unloading reminder

    // Collaboration data
    var collaborationStateRaw: String = "draft"
    @Relationship(deleteRule: .cascade, inverse: \DishProposal.dinner)
    var proposals: [DishProposal] = []

    var collaborationState: CollaborationState {
        get { CollaborationState(rawValue: collaborationStateRaw) ?? .draft }
        set { collaborationStateRaw = newValue.rawValue }
    }

    /// Check if collaboration is enabled (shared cellar)
    var isCollaborative: Bool {
        cellar?.isShared == true
    }

    /// Get collaboration summary
    var collaborationSummary: CollaborationSummary {
        CollaborationSummary(proposals: proposals, state: collaborationState)
    }

    var status: DinnerStatus {
        get { DinnerStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var guests: [Guest] {
        get {
            guard let data = guestsData else { return [] }
            return (try? JSONDecoder().decode([Guest].self, from: data)) ?? []
        }
        set {
            guestsData = try? JSONEncoder().encode(newValue)
        }
    }

    var menu: MenuProposal? {
        get {
            guard let data = menuData else { return nil }
            return try? JSONDecoder().decode(MenuProposal.self, from: data)
        }
        set {
            menuData = try? JSONEncoder().encode(newValue)
        }
    }

    var menuResponse: MenuResponse? {
        get {
            guard let data = menuData else { return nil }
            return try? JSONDecoder().decode(MenuResponse.self, from: data)
        }
    }

    var confirmedWines: [ConfirmedWine] {
        get {
            guard let data = confirmedWinesData else { return [] }
            return (try? JSONDecoder().decode([ConfirmedWine].self, from: data)) ?? []
        }
        set {
            confirmedWinesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Returns true if dinner is past and has confirmed wines but not yet completed
    var needsBottleUnload: Bool {
        date < Date() &&
        status != .completed &&
        status != .cancelled &&
        !confirmedWines.isEmpty
    }

    /// Returns true if dinner is past (for display purposes)
    var isPast: Bool {
        date < Date()
    }

    init(
        title: String,
        date: Date,
        guestCount: Int = 2,
        occasion: String? = nil,
        notes: String? = nil,
        status: DinnerStatus = .planning
    ) {
        self.title = title
        self.date = date
        self.guestCount = guestCount
        self.occasion = occasion
        self.notes = notes
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum DinnerStatus: String, Codable, CaseIterable {
    case planning
    case confirmed
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .planning: return "In pianificazione"
        case .confirmed: return "Confermata"
        case .completed: return "Completata"
        case .cancelled: return "Annullata"
        }
    }
}

// MARK: - Guest (Codable, stored as JSON in DinnerEvent)

struct Guest: Codable, Identifiable {
    var id: String
    var name: String
    var dietaryRestrictions: [String]
    var preferences: String?

    init(name: String, dietaryRestrictions: [String] = [], preferences: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.dietaryRestrictions = dietaryRestrictions
        self.preferences = preferences
    }
}

// MARK: - Menu (Codable, stored as JSON in DinnerEvent)

struct MenuProposal: Codable {
    var courses: [MenuCourse]
    var wineStrategy: String?
    var generatedAt: Date?
    var aiNotes: String?
}

struct MenuCourse: Codable, Identifiable {
    var id: String { "\(course.rawValue)-\(name)" }
    var course: CourseType
    var name: String
    var description: String
    var dietaryFlags: [String]
    var prepTime: Int?
    var notes: String?
    var cellarWine: WinePairing?
    var marketWine: WinePairing?

    init(
        course: CourseType,
        name: String,
        description: String,
        dietaryFlags: [String] = [],
        prepTime: Int? = nil,
        notes: String? = nil,
        cellarWine: WinePairing? = nil,
        marketWine: WinePairing? = nil
    ) {
        self.course = course
        self.name = name
        self.description = description
        self.dietaryFlags = dietaryFlags
        self.prepTime = prepTime
        self.notes = notes
        self.cellarWine = cellarWine
        self.marketWine = marketWine
    }
}

struct WinePairing: Codable {
    var name: String
    var reasoning: String
    var details: String?
}

enum CourseType: String, Codable, CaseIterable {
    case aperitivo
    case antipasto
    case primo
    case secondo
    case contorno
    case dolce
    case digestivo

    var displayName: String {
        switch self {
        case .aperitivo: return "Aperitivo"
        case .antipasto: return "Antipasto"
        case .primo: return "Primo"
        case .secondo: return "Secondo"
        case .contorno: return "Contorno"
        case .dolce: return "Dolce"
        case .digestivo: return "Digestivo"
        }
    }

    var icon: String {
        switch self {
        case .aperitivo: return "🥂"
        case .antipasto: return "🥗"
        case .primo: return "🍝"
        case .secondo: return "🥩"
        case .contorno: return "🥬"
        case .dolce: return "🍰"
        case .digestivo: return "☕️"
        }
    }
}

// MARK: - Chat Message

@Model
final class ChatMessage {
    var roleRaw: String
    var content: String
    var createdAt: Date

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: MessageRole, content: String) {
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Settings

@Model
final class AppSettings {
    var openAIApiKey: String?
    var preferredLanguage: String
    var createdAt: Date
    var updatedAt: Date

    // Taste preferences (stored as JSON)
    var tastePreferencesData: Data?

    var tastePreferences: TastePreferences {
        get {
            guard let data = tastePreferencesData else { return TastePreferences() }
            return (try? JSONDecoder().decode(TastePreferences.self, from: data)) ?? TastePreferences()
        }
        set {
            tastePreferencesData = try? JSONEncoder().encode(newValue)
        }
    }

    init() {
        // Default to device language if supported, otherwise English
        let deviceLanguage = String(Locale.preferredLanguages.first?.prefix(2) ?? "en")
        let supportedLanguages = ["it", "en", "de", "fr"]
        self.preferredLanguage = supportedLanguages.contains(deviceLanguage) ? deviceLanguage : "en"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Taste Preferences

struct TastePreferences: Codable {
    var preferredWineTypes: [String] // rosso, bianco, bollicine, etc.
    var preferredRegions: [String]
    var preferredGrapes: [String]
    var bodyPreference: BodyPreference // leggero, medio, corposo
    var sweetnessPreference: SweetnessPreference // secco, abboccato, dolce
    var tanninPreference: TanninPreference // basso, medio, alto
    var acidityPreference: AcidityPreference // bassa, media, alta
    var notes: String?

    init(
        preferredWineTypes: [String] = [],
        preferredRegions: [String] = [],
        preferredGrapes: [String] = [],
        bodyPreference: BodyPreference = .medio,
        sweetnessPreference: SweetnessPreference = .secco,
        tanninPreference: TanninPreference = .medio,
        acidityPreference: AcidityPreference = .media,
        notes: String? = nil
    ) {
        self.preferredWineTypes = preferredWineTypes
        self.preferredRegions = preferredRegions
        self.preferredGrapes = preferredGrapes
        self.bodyPreference = bodyPreference
        self.sweetnessPreference = sweetnessPreference
        self.tanninPreference = tanninPreference
        self.acidityPreference = acidityPreference
        self.notes = notes
    }
}

enum BodyPreference: String, Codable, CaseIterable {
    case leggero, medio, corposo

    var displayName: String {
        switch self {
        case .leggero: return "Leggero"
        case .medio: return "Medio"
        case .corposo: return "Corposo"
        }
    }
}

enum SweetnessPreference: String, Codable, CaseIterable {
    case secco, abboccato, dolce

    var displayName: String {
        switch self {
        case .secco: return "Secco"
        case .abboccato: return "Abboccato"
        case .dolce: return "Dolce"
        }
    }
}

enum TanninPreference: String, Codable, CaseIterable {
    case basso, medio, alto

    var displayName: String {
        switch self {
        case .basso: return "Basso"
        case .medio: return "Medio"
        case .alto: return "Alto"
        }
    }
}

enum AcidityPreference: String, Codable, CaseIterable {
    case bassa, media, alta

    var displayName: String {
        switch self {
        case .bassa: return "Bassa"
        case .media: return "Media"
        case .alta: return "Alta"
        }
    }
}

// MARK: - Wine Review (Tasting Notes)

struct WineReview: Codable {
    var rating: Double // 1.0 - 5.0 stars
    var tastingDate: Date?

    // Visual
    var colorIntensity: ColorIntensity?
    var colorNotes: String?

    // Nose (Aroma)
    var aromaIntensity: AromaIntensity?
    var aromas: [String] // frutti rossi, spezie, vaniglia, etc.
    var aromaComplexity: Complexity?
    var aromaNotes: String?

    // Palate (Taste)
    var body: BodyLevel?
    var tannins: TanninLevel?
    var acidity: AcidityLevel?
    var sweetness: SweetnessLevel?
    var alcohol: AlcoholLevel?
    var finish: FinishLength?
    var tasteNotes: String?

    // Overall
    var overallNotes: String?
    var foodPairings: [String]
    var wouldBuyAgain: Bool?
    var priceQualityRating: Int? // 1-5

    init(
        rating: Double = 3.0,
        tastingDate: Date? = nil,
        colorIntensity: ColorIntensity? = nil,
        colorNotes: String? = nil,
        aromaIntensity: AromaIntensity? = nil,
        aromas: [String] = [],
        aromaComplexity: Complexity? = nil,
        aromaNotes: String? = nil,
        body: BodyLevel? = nil,
        tannins: TanninLevel? = nil,
        acidity: AcidityLevel? = nil,
        sweetness: SweetnessLevel? = nil,
        alcohol: AlcoholLevel? = nil,
        finish: FinishLength? = nil,
        tasteNotes: String? = nil,
        overallNotes: String? = nil,
        foodPairings: [String] = [],
        wouldBuyAgain: Bool? = nil,
        priceQualityRating: Int? = nil
    ) {
        self.rating = rating
        self.tastingDate = tastingDate
        self.colorIntensity = colorIntensity
        self.colorNotes = colorNotes
        self.aromaIntensity = aromaIntensity
        self.aromas = aromas
        self.aromaComplexity = aromaComplexity
        self.aromaNotes = aromaNotes
        self.body = body
        self.tannins = tannins
        self.acidity = acidity
        self.sweetness = sweetness
        self.alcohol = alcohol
        self.finish = finish
        self.tasteNotes = tasteNotes
        self.overallNotes = overallNotes
        self.foodPairings = foodPairings
        self.wouldBuyAgain = wouldBuyAgain
        self.priceQualityRating = priceQualityRating
    }
}

// MARK: - Wine Review Enums

enum ColorIntensity: String, Codable, CaseIterable {
    case pallido = "Pallido"
    case medio = "Medio"
    case intenso = "Intenso"
    case profondo = "Profondo"
}

enum AromaIntensity: String, Codable, CaseIterable {
    case delicato = "Delicato"
    case medio = "Medio"
    case pronunciato = "Pronunciato"
    case intenso = "Intenso"
}

enum Complexity: String, Codable, CaseIterable {
    case semplice = "Semplice"
    case moderata = "Moderata"
    case complessa = "Complessa"
}

enum BodyLevel: String, Codable, CaseIterable {
    case leggero = "Leggero"
    case medioLeggero = "Medio-leggero"
    case medio = "Medio"
    case medioPieno = "Medio-pieno"
    case pieno = "Pieno"
}

enum TanninLevel: String, Codable, CaseIterable {
    case morbidi = "Morbidi"
    case setosi = "Setosi"
    case moderati = "Moderati"
    case decisi = "Decisi"
    case astringenti = "Astringenti"
}

enum AcidityLevel: String, Codable, CaseIterable {
    case piatta = "Piatta"
    case fresca = "Fresca"
    case vivace = "Vivace"
    case tagliente = "Tagliente"
}

enum SweetnessLevel: String, Codable, CaseIterable {
    case secco = "Secco"
    case abboccato = "Abboccato"
    case amabile = "Amabile"
    case dolce = "Dolce"
}

enum AlcoholLevel: String, Codable, CaseIterable {
    case basso = "Basso"
    case medio = "Medio"
    case caldo = "Caldo"
    case bruciante = "Bruciante"
}

enum FinishLength: String, Codable, CaseIterable {
    case corto = "Corto"
    case medio = "Medio"
    case lungo = "Lungo"
    case persistente = "Persistente"
}

// Common aromas for picker
struct WineAromas {
    static let fruttaRossa = ["Ciliegia", "Fragola", "Lampone", "Ribes", "Amarena", "Prugna"]
    static let fruttaNera = ["Mora", "Mirtillo", "Ribes nero", "Cassis"]
    static let fruttaTropicale = ["Ananas", "Mango", "Frutto della passione", "Banana"]
    static let agrumi = ["Limone", "Arancia", "Pompelmo", "Bergamotto"]
    static let fiori = ["Rosa", "Violetta", "Gelsomino", "Fiori bianchi", "Acacia"]
    static let spezie = ["Pepe nero", "Chiodi di garofano", "Cannella", "Vaniglia", "Liquirizia"]
    static let tostati = ["Caffè", "Cioccolato", "Tabacco", "Cuoio", "Legno"]
    static let vegetali = ["Erba", "Fieno", "Peperone verde", "Menta", "Eucalipto"]
    static let minerali = ["Pietra focaia", "Gesso", "Salsedine", "Grafite"]

    static var all: [String: [String]] {
        [
            "Frutta rossa": fruttaRossa,
            "Frutta nera": fruttaNera,
            "Frutta tropicale": fruttaTropicale,
            "Agrumi": agrumi,
            "Fiori": fiori,
            "Spezie": spezie,
            "Tostati": tostati,
            "Vegetali": vegetali,
            "Minerali": minerali
        ]
    }
}

// MARK: - Extraction Result (for OCR)

struct ExtractionResult: Codable {
    var name: String?
    var producer: String?
    var vintage: String?
    var type: String?
    var region: String?
    var country: String?
    var grapes: [String]?
    var alcohol: Double?
    var confidence: Double
}
