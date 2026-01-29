import Foundation
import FirebaseFirestore

// MARK: - User

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var createdAt: Timestamp
    var updatedAt: Timestamp
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var language: String
    var notifications: Bool
    var dietaryRestrictions: [String]?
    var favoriteRegions: [String]?
}

// MARK: - Cellar

struct Cellar: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var ownerId: String
    var members: [String: CellarMember]
    var stats: CellarStats
    var createdAt: Timestamp
    var updatedAt: Timestamp
}

struct CellarMember: Codable {
    var role: String
    var joinedAt: Timestamp
}

struct CellarStats: Codable {
    var totalBottles: Int
    var totalValue: Double
    var wineTypes: [String: Int]
}

// MARK: - Wine

struct Wine: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var producer: String?
    var vintage: String?
    var type: WineType
    var region: String?
    var country: String
    var grapes: [String]?
    var alcohol: Double?
    var description: String?
    var tastingNotes: TastingNotes?
    var pairings: [String]?
    var averagePrice: Double?
    var createdAt: Timestamp
    var updatedAt: Timestamp
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
}

struct TastingNotes: Codable {
    var appearance: String?
    var nose: [String]?
    var palate: [String]?
    var finish: String?
    var rating: Int?
}

// MARK: - Bottle

struct Bottle: Codable, Identifiable {
    @DocumentID var id: String?
    var wineId: String
    var cellarId: String
    var location: BottleLocation?
    var purchaseDate: Timestamp?
    var purchasePrice: Double?
    var purchaseLocation: String?
    var quantity: Int
    var drinkWindow: DrinkWindow?
    var notes: String?
    var status: BottleStatus
    var createdAt: Timestamp
    var updatedAt: Timestamp

    // Joined data
    var wine: Wine?
}

struct BottleLocation: Codable {
    var zone: String?
    var rack: Int?
    var shelf: Int?
    var position: Int?
}

struct DrinkWindow: Codable {
    var from: String?
    var to: String?
    var peak: String?
}

enum BottleStatus: String, Codable {
    case available
    case reserved
    case consumed
    case gifted
}

// MARK: - Dinner Event

struct DinnerEvent: Codable, Identifiable {
    @DocumentID var id: String?
    var hostId: String
    var cellarId: String
    var title: String
    var date: Timestamp
    var guestCount: Int
    var guests: [Guest]?
    var occasion: String?
    var notes: String?
    var menu: MenuProposal?
    var status: DinnerStatus
    var createdAt: Timestamp
    var updatedAt: Timestamp
}

struct Guest: Codable, Identifiable {
    var id: String { oderId ?? UUID().uuidString }
    var oderId: String?
    var name: String
    var dietaryRestrictions: [String]?
    var preferences: String?
}

enum DinnerStatus: String, Codable {
    case planning
    case confirmed
    case completed
    case cancelled
}

// MARK: - Menu

struct MenuProposal: Codable {
    var courses: [MenuCourse]
    var wineStrategy: String?
    var generatedAt: Timestamp?
    var aiNotes: String?
}

struct MenuCourse: Codable, Identifiable {
    var id: String { "\(course.rawValue)-\(name)" }
    var course: CourseType
    var name: String
    var description: String
    var dietaryFlags: [String]?
    var prepTime: Int?
    var notes: String?
    var cellarWine: WinePairing?
    var marketWine: WinePairing?
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

// MARK: - Chat

struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var cellarId: String
    var role: MessageRole
    var content: String
    var metadata: MessageMetadata?
    var createdAt: Timestamp
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct MessageMetadata: Codable {
    var wineIds: [String]?
    var bottleIds: [String]?
    var toolCalls: [String]?
}

// MARK: - Extraction Result

struct ExtractionResult: Codable {
    var ocrText: String
    var extractedFields: ExtractedFields
    var overallConfidence: Double
}

struct ExtractedFields: Codable {
    var name: ExtractedValue<String>?
    var producer: ExtractedValue<String>?
    var vintage: ExtractedValue<String>?
    var type: ExtractedValue<String>?
    var region: ExtractedValue<String>?
    var country: ExtractedValue<String>?
    var grapes: ExtractedValue<[String]>?
    var alcohol: ExtractedValue<Double>?
}

struct ExtractedValue<T: Codable>: Codable {
    var value: T
    var confidence: Double
}

// MARK: - API Responses

struct ExtractWineResponse: Codable {
    var success: Bool
    var error: String?
    var extraction: ExtractionResult?
    var suggestedMatches: [Wine]?
}

struct ProposeDinnerResponse: Codable {
    var success: Bool
    var error: String?
    var menu: MenuProposal?
}

struct ChatResponse: Codable {
    var success: Bool
    var error: String?
    var message: ChatMessage?
}

struct HealthResponse: Codable {
    var status: String
    var timestamp: String
    var version: String
}
