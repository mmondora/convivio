//
//  Models.swift
//  Convivio
//
//  Data models che rispecchiano lo schema Firestore
//

import Foundation
import FirebaseFirestore

// MARK: - Wine Type

enum WineType: String, Codable, CaseIterable, Identifiable {
    case red
    case white
    case rosé
    case sparkling
    case dessert
    case fortified
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .red: return "Rosso"
        case .white: return "Bianco"
        case .rosé: return "Rosé"
        case .sparkling: return "Spumante"
        case .dessert: return "Passito"
        case .fortified: return "Fortificato"
        }
    }
    
    var icon: String {
        switch self {
        case .red: return "🍷"
        case .white: return "🥂"
        case .rosé: return "🌸"
        case .sparkling: return "🍾"
        case .dessert: return "🍯"
        case .fortified: return "🥃"
        }
    }
    
    var color: String {
        switch self {
        case .red: return "WineRed"
        case .white: return "WineWhite"
        case .rosé: return "WineRose"
        case .sparkling: return "WineSparkling"
        case .dessert: return "WineDessert"
        case .fortified: return "WineFortified"
        }
    }
}

// MARK: - Bottle Status

enum BottleStatus: String, Codable, CaseIterable {
    case available
    case consumed
    case gifted
    case broken
    
    var displayName: String {
        switch self {
        case .available: return "Disponibile"
        case .consumed: return "Consumato"
        case .gifted: return "Regalato"
        case .broken: return "Rotto"
        }
    }
}

// MARK: - User Role

enum UserRole: String, Codable {
    case owner
    case family
}

// MARK: - Wine

struct Wine: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var producer: String?
    var vintage: Int?
    var type: WineType
    var region: String?
    var country: String?
    var grapes: [String]?
    var alcoholContent: Double?
    var description: String?
    @ServerTimestamp var createdAt: Timestamp?
    var createdBy: String
    
    var displayName: String {
        var parts = [name]
        if let vintage = vintage {
            parts.append(String(vintage))
        }
        return parts.joined(separator: " ")
    }
    
    var subtitle: String {
        var parts: [String] = []
        if let producer = producer {
            parts.append(producer)
        }
        if let region = region {
            parts.append(region)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Bottle

struct Bottle: Identifiable, Codable {
    @DocumentID var id: String?
    var wineId: String
    var locationId: String
    var status: BottleStatus
    var acquiredAt: Timestamp?
    var acquiredPrice: Double?
    var consumedAt: Timestamp?
    var notes: String?
    @ServerTimestamp var createdAt: Timestamp?
    var createdBy: String
}

// MARK: - Cellar

struct Cellar: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var members: [String: UserRole]
    @ServerTimestamp var createdAt: Timestamp?
    var createdBy: String
    
    func role(for userId: String) -> UserRole? {
        members[userId]
    }
}

// MARK: - Location

struct Location: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var cellarId: String?
    var shelf: String
    var row: Int?
    var slot: Int?
    var description: String?
    var capacity: Int?
    
    var displayPath: String {
        var parts = ["Scaffale \(shelf)"]
        if let row = row {
            parts.append("Riga \(row)")
        }
        if let slot = slot {
            parts.append("Slot \(slot)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Rating

struct Rating: Identifiable, Codable {
    @DocumentID var id: String?
    var wineId: String
    var rating: Int // 1-5
    var isFavorite: Bool
    var notes: String?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
}

// MARK: - Taste Profile

struct TasteProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var wineId: String
    var acidity: Int      // 1-5
    var tannin: Int       // 1-5
    var body: Int         // 1-5
    var sweetness: Int    // 1-5
    var effervescence: Int // 0-5
    var notes: String?
    var tags: [String]?
    @ServerTimestamp var createdAt: Timestamp?
}

// MARK: - Friend

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String?
    var phone: String?
    var foodieLevel: FoodieLevel
    var notes: String?
    @ServerTimestamp var createdAt: Timestamp?
}

enum FoodieLevel: String, Codable, CaseIterable {
    case simple
    case curious
    case demanding
    
    var displayName: String {
        switch self {
        case .simple: return "Semplice"
        case .curious: return "Curioso"
        case .demanding: return "Esigente"
        }
    }
}

// MARK: - Food Preference

struct FoodPreference: Identifiable, Codable {
    @DocumentID var id: String?
    var friendId: String?
    var type: FoodPrefType
    var category: String
    var description: String?
    var severity: FoodPrefSeverity?
}

enum FoodPrefType: String, Codable, CaseIterable {
    case allergy
    case intolerance
    case dislike
    case preference
    case diet
    
    var displayName: String {
        switch self {
        case .allergy: return "Allergia"
        case .intolerance: return "Intolleranza"
        case .dislike: return "Non gradisce"
        case .preference: return "Preferenza"
        case .diet: return "Dieta"
        }
    }
    
    var icon: String {
        switch self {
        case .allergy: return "exclamationmark.triangle.fill"
        case .intolerance: return "exclamationmark.circle.fill"
        case .dislike: return "hand.thumbsdown.fill"
        case .preference: return "heart.fill"
        case .diet: return "leaf.fill"
        }
    }
}

enum FoodPrefSeverity: String, Codable {
    case mild
    case moderate
    case severe
}

// MARK: - Dinner Event

struct DinnerEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var date: Timestamp
    var time: String?
    var style: DinnerStyle
    var cookingTime: CookingTime
    var budgetLevel: BudgetLevel
    var notes: String?
    var status: DinnerStatus
    var menuProposal: MenuProposal?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
}

enum DinnerStyle: String, Codable, CaseIterable {
    case informal
    case convivial
    case elegant
    
    var displayName: String {
        switch self {
        case .informal: return "Informale"
        case .convivial: return "Conviviale"
        case .elegant: return "Elegante"
        }
    }
}

enum CookingTime: String, Codable, CaseIterable {
    case thirtyMin = "30min"
    case oneHour = "1h"
    case twoHours = "2h"
    case threeHoursPlus = "3h+"
    
    var displayName: String {
        switch self {
        case .thirtyMin: return "30 min"
        case .oneHour: return "1 ora"
        case .twoHours: return "2 ore"
        case .threeHoursPlus: return "3+ ore"
        }
    }
}

enum BudgetLevel: String, Codable, CaseIterable {
    case economy
    case standard
    case premium
    
    var displayName: String {
        switch self {
        case .economy: return "Economico"
        case .standard: return "Standard"
        case .premium: return "Premium"
        }
    }
}

enum DinnerStatus: String, Codable {
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

// MARK: - Menu Proposal

struct MenuProposal: Codable {
    var courses: [MenuCourse]
    var reasoning: String
    var seasonContext: String
    var guestConsiderations: [String]
    var totalPrepTime: Int
    var generatedAt: Timestamp?
}

struct MenuCourse: Codable, Identifiable {
    var id: String { course.rawValue }
    var course: CourseType
    var name: String
    var description: String
    var dietaryFlags: [String]
    var prepTime: Int
    var notes: String?
}

enum CourseType: String, Codable, CaseIterable {
    case aperitif
    case starter
    case first
    case main
    case dessert
    case pairing
    
    var displayName: String {
        switch self {
        case .aperitif: return "Aperitivo"
        case .starter: return "Antipasto"
        case .first: return "Primo"
        case .main: return "Secondo"
        case .dessert: return "Dolce"
        case .pairing: return "Abbinamento"
        }
    }
}

// MARK: - Wine Proposal

struct WineProposal: Identifiable, Codable {
    @DocumentID var id: String?
    var dinnerId: String?
    var type: ProposalType
    var wineId: String?
    var suggestedWineName: String?
    var suggestedWineDetails: String?
    var course: CourseType
    var reasoning: String
    var isSelected: Bool
    @ServerTimestamp var createdAt: Timestamp?
}

enum ProposalType: String, Codable {
    case available
    case suggestedPurchase = "suggested_purchase"
}

// MARK: - Chat

struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
}

struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var role: MessageRole
    var content: String
    @ServerTimestamp var createdAt: Timestamp?
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Extraction

struct ExtractionResult: Identifiable, Codable {
    @DocumentID var id: String?
    var photoAssetId: String
    var rawOcrText: String
    var extractedFields: ExtractedFields
    var overallConfidence: Double
    var wasManuallyEdited: Bool
    var finalWineId: String?
    @ServerTimestamp var createdAt: Timestamp?
}

struct ExtractedFields: Codable {
    var name: ExtractedField?
    var producer: ExtractedField?
    var vintage: ExtractedField?
    var type: ExtractedField?
    var region: ExtractedField?
    var country: ExtractedField?
    var alcoholContent: ExtractedField?
    var grapes: ExtractedField?
}

struct ExtractedField: Codable {
    var value: String
    var confidence: Double
}

// MARK: - Aggregated Types

struct WineInventoryItem: Identifiable {
    var id: String { wine.id ?? UUID().uuidString }
    var wine: Wine
    var availableBottles: Int
    var locations: [Location]
    var rating: Rating?
    var tasteProfile: TasteProfile?
    
    var primaryLocation: Location? {
        locations.first
    }
}

struct CellarStats {
    var totalBottles: Int
    var availableBottles: Int
    var byType: [WineType: Int]
    var vintageRange: ClosedRange<Int>?
    var avgRating: Double?
}
