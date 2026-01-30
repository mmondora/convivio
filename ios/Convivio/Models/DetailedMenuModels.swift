import Foundation

// MARK: - Detailed Menu Complete

/// Complete detailed menu with recipes, timeline, shopping list, and service advice
struct DettaglioMenuCompleto: Codable, Identifiable {
    var id: String { dinnerTitle + "-" + String(dinnerDate.timeIntervalSince1970) }

    let dinnerTitle: String
    let dinnerDate: Date
    let guestCount: Int

    let portate: [PortataDettagliata]
    let timeline: [TimelineStep]
    let shoppingList: [ShoppingCategory]
    let wineService: [WineServiceAdvice]
    let miseEnPlace: MiseEnPlace
    let etiquette: [String]

    enum CodingKeys: String, CodingKey {
        case dinnerTitle = "dinner_title"
        case dinnerDate = "dinner_date"
        case guestCount = "guest_count"
        case portate
        case timeline
        case shoppingList = "shopping_list"
        case wineService = "wine_service"
        case miseEnPlace = "mise_en_place"
        case etiquette
    }
}

// MARK: - Detailed Course

/// A detailed course with complete recipe information
struct PortataDettagliata: Codable, Identifiable {
    var id: String { courseName + "-" + dishName }

    let courseName: String
    let dishName: String
    let recipe: RecipeDetail
    let wineNote: String?

    enum CodingKeys: String, CodingKey {
        case courseName = "course_name"
        case dishName = "dish_name"
        case recipe
        case wineNote = "wine_note"
    }
}

// MARK: - Recipe Detail

/// Detailed recipe with ingredients and procedure
struct RecipeDetail: Codable {
    let ingredients: [DetailedIngredient]
    let servings: Int
    let prepTime: Int  // minutes
    let cookTime: Int  // minutes
    let procedure: [String]
    let chefTips: [String]?

    enum CodingKeys: String, CodingKey {
        case ingredients
        case servings
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case procedure
        case chefTips = "chef_tips"
    }

    var totalTime: Int {
        prepTime + cookTime
    }
}

// MARK: - Detailed Ingredient

/// Ingredient with category for shopping list organization
struct DetailedIngredient: Codable, Identifiable {
    var id: String { name + "-" + quantity }

    let name: String
    let quantity: String
    let unit: String?
    let category: String  // verdure, carni, latticini, etc.

    var displayText: String {
        if let unit = unit, !unit.isEmpty {
            return "\(quantity) \(unit) \(name)"
        }
        return "\(quantity) \(name)"
    }
}

// MARK: - Timeline Step

/// A step in the preparation timeline
struct TimelineStep: Codable, Identifiable {
    var id: String { "\(timeOffset)-\(description.prefix(20))" }

    let timeOffset: Int  // minutes before dinner (negative values)
    let description: String
    let relatedDish: String?

    enum CodingKeys: String, CodingKey {
        case timeOffset = "time_offset"
        case description
        case relatedDish = "related_dish"
    }

    var formattedTime: String {
        if timeOffset == 0 {
            return "Servizio"
        } else if timeOffset > 0 {
            return "+\(timeOffset) min dopo"
        } else {
            let absTime = abs(timeOffset)
            if absTime >= 1440 {
                let days = absTime / 1440
                return "\(days) giorn\(days == 1 ? "o" : "i") prima"
            } else if absTime >= 60 {
                let hours = absTime / 60
                let mins = absTime % 60
                if mins == 0 {
                    return "\(hours) or\(hours == 1 ? "a" : "e") prima"
                }
                return "\(hours)h \(mins)min prima"
            } else {
                return "\(absTime) min prima"
            }
        }
    }
}

// MARK: - Shopping Category

/// A category of items in the shopping list
struct ShoppingCategory: Codable, Identifiable {
    var id: String { category }

    let category: String
    let items: [ShoppingItem]

    var icon: String {
        switch category.lowercased() {
        case "verdure", "ortaggi": return "leaf.fill"
        case "frutta": return "apple.logo"
        case "carni": return "flame.fill"
        case "pesce": return "fish.fill"
        case "latticini", "formaggi": return "drop.fill"
        case "pane", "panetteria": return "birthday.cake.fill"
        case "uova": return "oval.fill"
        case "pasta", "riso": return "fork.knife"
        case "spezie", "erbe": return "leaf.arrow.triangle.circlepath"
        case "vini": return "wineglass.fill"
        case "altro", "varie": return "bag.fill"
        default: return "cart.fill"
        }
    }
}

// MARK: - Shopping Item

/// A single item in the shopping list
struct ShoppingItem: Codable, Identifiable {
    var id: String { name + "-" + quantity }

    let name: String
    let quantity: String
    let searchQuery: String?  // For external search link

    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case searchQuery = "search_query"
    }
}

// MARK: - Wine Service Advice

/// Advice for serving a specific wine
struct WineServiceAdvice: Codable, Identifiable {
    var id: String { wineName + "-" + String(servingOrder) }

    let wineName: String
    let servingTemp: String
    let decantTime: String?
    let glassType: String
    let servingOrder: Int
    let pairedWith: String

    enum CodingKeys: String, CodingKey {
        case wineName = "wine_name"
        case servingTemp = "serving_temp"
        case decantTime = "decant_time"
        case glassType = "glass_type"
        case servingOrder = "serving_order"
        case pairedWith = "paired_with"
    }

    var formattedTemp: String {
        if servingTemp.contains("°") {
            return servingTemp
        }
        return "\(servingTemp)°C"
    }
}

// MARK: - Mise en Place

/// Table setting and service guidance
struct MiseEnPlace: Codable {
    let tableSettings: [String]
    let servingOrder: [String]
    let generalTips: [String]

    enum CodingKeys: String, CodingKey {
        case tableSettings = "table_settings"
        case servingOrder = "serving_order"
        case generalTips = "general_tips"
    }
}
